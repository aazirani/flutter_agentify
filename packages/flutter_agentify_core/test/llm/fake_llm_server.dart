import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Answers one request.
typedef Reply = Future<void> Function(HttpRequest request);

/// A local HTTP server that answers each request with the next queued reply.
class FakeLlmServer {
  HttpServer? _server;
  final _replies = <Reply>[];
  final _hanging = <HttpResponse>[];

  Map<String, Object?> lastBody = const {};
  Map<String, String> lastHeaders = const {};
  String lastPath = '';

  // One address on both sides: `localhost` may mean IPv4 to one and IPv6 to
  // the other, where another program can hold the same port.
  Uri get url => Uri.parse('http://127.0.0.1:${_server?.port}');

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((request) async {
      final text = await utf8.decodeStream(request);
      lastBody = text.isEmpty
          ? const {}
          : jsonDecode(text) as Map<String, Object?>;
      final headers = <String, String>{};
      request.headers.forEach(
        (name, values) => headers[name] = values.join(','),
      );
      lastHeaders = headers;
      lastPath = request.uri.path;
      // One request per connection: a reused keep-alive socket the server
      // already closed would turn a scripted reply into a connection error.
      request.response.persistentConnection = false;
      if (_replies.isEmpty) {
        request.response.statusCode = 500;
        await request.response.close();
        return;
      }
      await _replies.removeAt(0)(request);
    });
  }

  Future<void> stop() async {
    for (final response in _hanging) {
      unawaited(response.close().catchError((_) {}));
    }
    await _server?.close(force: true);
  }

  void enqueue(Reply reply) => _replies.add(reply);

  void json(
    int status,
    Object? body, {
    Map<String, String> headers = const {},
  }) => enqueue(jsonReply(status, body, headers: headers));

  /// Server-sent events: each item is written as one `data:` event.
  void sse(List<String> data) => enqueue(sseReply(data));

  static Reply jsonReply(
    int status,
    Object? body, {
    Map<String, String> headers = const {},
  }) => (request) async {
    final response = request.response..statusCode = status;
    headers.forEach(response.headers.set);
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  };

  static Reply sseReply(List<String> data) => (request) async {
    final response = request.response..headers.contentType = _eventStream;
    for (final item in data) {
      response.write('data: $item\n\n');
      await response.flush();
    }
    await response.close();
  };

  /// Writes [data] as events, then cuts the connection mid-body.
  void sseThenDrop(List<String> data) => enqueue((request) async {
    final response = request.response
      ..headers.contentType = _eventStream
      ..contentLength = 1 << 20;
    final socket = await response.detachSocket();
    for (final item in data) {
      socket.add(utf8.encode('data: $item\n\n'));
    }
    await socket.flush();
    socket.destroy();
  });

  /// Closes the connection before any response.
  void drop() => enqueue((request) async {
    final socket = await request.response.detachSocket(writeHeaders: false);
    socket.destroy();
  });

  /// Writes [data] as events, then keeps the connection open until [stop].
  void sseThenHang(List<String> data) => enqueue((request) async {
    final response = request.response
      ..headers.contentType = _eventStream
      ..bufferOutput = false;
    for (final item in data) {
      response.write('data: $item\n\n');
      await response.flush();
    }
    _hanging.add(response);
  });

  static final _eventStream = ContentType(
    'text',
    'event-stream',
    charset: 'utf-8',
  );
}

/// [text] cut into [parts] pieces of roughly equal length.
List<String> splitInto(String text, int parts) {
  if (parts <= 1 || text.length <= 1) return [text];
  final size = (text.length / parts).ceil();
  return [
    for (var i = 0; i < text.length; i += size)
      text.substring(i, i + size > text.length ? text.length : i + size),
  ];
}
