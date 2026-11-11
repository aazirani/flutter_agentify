/// Limits and thresholds of the agent loop. The defaults are starting
/// values; tune them per app.
class AgentConfig {
  const AgentConfig({
    this.maxSteps = 12,
    this.tokenBudget = 100000,
    this.repeatLimit = 3,
    this.maxRetries = 2,
    this.toolSearchShare = 0.25,
    this.smallContextWindow = 16000,
    this.forceToolSearch = false,
    this.currentScreenMaxChars = 2000,
    this.keepRecentMessages = 8,
  });

  /// Most model requests in one run.
  final int maxSteps;

  /// Most tokens one run may use.
  final int tokenBudget;

  /// The same call with the same arguments this many times stops the run.
  final int repeatLimit;

  /// Retries of a failed model request that may succeed later.
  final int maxRetries;

  /// With a small context window, tool search turns on when the tool
  /// definitions would take more than this share of it (estimated, so the
  /// choice does not depend on how many tools an app happens to have).
  final double toolSearchShare;

  /// Context windows below this count as small.
  final int smallContextWindow;

  /// Use tool search whatever the tool count.
  final bool forceToolSearch;

  /// Longest `<current-screen>` block.
  final int currentScreenMaxChars;

  /// Messages always kept verbatim when older history is summarized.
  final int keepRecentMessages;
}
