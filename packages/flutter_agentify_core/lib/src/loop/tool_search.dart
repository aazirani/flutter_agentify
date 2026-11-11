import '../actions/agent_action.dart';

/// The name of the loop's own tool that finds more tools. It is not an app
/// action, so chats may hide it.
const toolSearchName = 'tool_search';

final _wordSplit = RegExp(r'[^a-z0-9]+');

/// Words that say nothing about which tool is wanted.
const _stopWords = {
  'the', 'and', 'for', 'with', 'that', 'this', 'what', 'who', 'how', 'why',
  'are', 'was', 'does', 'did', 'can', 'could', 'would', 'should', 'please',
  'from', 'into', 'about', 'its', 'you', 'your', 'not', 'but', 'any', 'all',
  'now', 'again', 'then', //
};

Iterable<String> _words(String text) =>
    text.toLowerCase().split(_wordSplit).where((w) => w.isNotEmpty);

/// Best matches for [query] over name, description and searchHints; at most
/// [limit]. A query word of four letters or more matches a word that starts
/// with it; a shorter one must match a whole word. Stop words and words
/// shorter than three letters are ignored.
List<AgentAction<Object?, Object?>> searchTools(
  Iterable<AgentAction<Object?, Object?>> tools,
  String query, {
  int limit = 8,
}) {
  final wanted = _words(query)
      .where((w) => w.length >= 3 && !_stopWords.contains(w))
      .toSet();
  if (wanted.isEmpty) return const [];

  bool matches(String word, String w) =>
      w.length <= 3 ? word == w : word.startsWith(w);
  int hits(Iterable<String> words) =>
      wanted.where((w) => words.any((word) => matches(word, w))).length;

  final scored =
      [
        for (final tool in tools)
          (
            tool: tool,
            score:
                3 * hits(_words(tool.name)) +
                2 * hits(tool.searchHints.expand(_words)) +
                hits(_words(tool.description)),
          ),
      ].where((s) => s.score > 0).toList()..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.tool.name.compareTo(b.tool.name);
      });
  return [for (final s in scored.take(limit)) s.tool];
}
