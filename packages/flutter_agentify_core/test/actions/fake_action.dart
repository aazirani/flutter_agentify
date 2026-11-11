import 'package:flutter_agentify_core/flutter_agentify_core.dart';

/// A configurable action for tests. Input: `{"text": <string>}`.
class FakeAction extends AgentAction<String, Object?> {
  FakeAction(
    this.name, {
    Future<Object?> Function(String text, ActionContext context)? run,
    this.description = 'A test action.',
    this.readOnly = false,
    this.resources = const ['notes'],
    bool approval = false,
    this.agentTool = true,
    this.timeout = const Duration(seconds: 5),
    this.maxResultChars = 4000,
    this.fieldDescription = 'Some text.',
    this.allowAlways = true,
    Future<String?> Function(String text)? summary,
  }) : _summary = summary,
       _run = run ?? ((text, _) async => text),
       _approval = approval;

  @override
  final String name;
  @override
  final String description;
  @override
  final bool readOnly;
  @override
  final List<String> resources;
  @override
  final bool agentTool;
  @override
  final Duration timeout;
  @override
  final int maxResultChars;
  @override
  final bool allowAlways;
  final String fieldDescription;
  final Future<String?> Function(String)? _summary;
  final Future<Object?> Function(String, ActionContext) _run;
  final bool _approval;

  @override
  late final ObjectSchema<String> input = S.object(
    fields: {'text': S.string(description: fieldDescription)},
    build: (v) => v['text'] as String,
  );

  @override
  Future<Object?> run(String input, ActionContext context) =>
      _run(input, context);

  @override
  Object? encode(Object? output) => output;

  @override
  bool needsApproval(String input) => _approval;

  @override
  Future<String?> approvalSummary(String input) async => _summary?.call(input);
}

FakeAction echo() => FakeAction('echo', readOnly: true, resources: const []);

FakeAction addNote() => FakeAction(
  'add_note',
  run: (text, context) async {
    context.receipt(resource: 'notes', ids: ['n1'], summary: 'Added "$text"');
    return {'id': 'n1'};
  },
);

FakeAction wipe() =>
    FakeAction('wipe', approval: true, run: (_, _) async => 'wiped');

/// Needs approval; its input build throws a [FormatException], not a
/// [SchemaError], for a date like "soon". Input: `{"date": <string>}`.
class BookAction extends AgentAction<DateTime, String> {
  @override
  String get name => 'book';
  @override
  String get description => 'Books a date.';
  @override
  List<String> get resources => const ['bookings'];
  @override
  late final ObjectSchema<DateTime> input = S.object(
    fields: {'date': S.string(description: 'An ISO date.')},
    build: (v) => DateTime.parse(v['date'] as String),
  );
  @override
  Future<String> run(DateTime input, ActionContext context) async => 'booked';
  @override
  Object? encode(String output) => output;
  @override
  bool needsApproval(DateTime input) => true;
}
