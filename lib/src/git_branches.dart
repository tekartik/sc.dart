import 'dart:convert';

/// Parsed result of `git branch -vv` style output.
class GitBranchesResult {
  /// Parsed branch entries.
  final List<GitBranchResult> branches;

  /// Creates a parsed branches result.
  GitBranchesResult({required this.branches});

  @override
  String toString() => 'GitBranchesResult(branches: ${branches.length})';

  /// Parses multiple branch lines from command stdout.
  factory GitBranchesResult.fromStdout(String out) {
    var branches = <GitBranchResult>[];
    for (var line in LineSplitter.split(out)) {
      line = line.trim();
      if (line.trim().isEmpty) continue;
      var branch = GitBranchResult.fromLine(line);
      // Skip `* (HEAD detached at 8f84608)`, not a branch
      if (branch.name.startsWith('(')) continue;
      branches.add(branch);
    }
    return GitBranchesResult(branches: branches);
  }
}

/// Parsed branch entry with its local name and upstream state.
class GitBranchResult {
  /// Local branch name.
  final String name;

  /// Whether the upstream branch is marked as gone.
  final bool gone;

  /// Creates a parsed branch entry.
  GitBranchResult({required this.name, required this.gone});

  @override
  String toString() => 'GitBranchResult(name: $name, gone: $gone)';

  /// Parses a single branch line from `git branch -vv` output.
  factory GitBranchResult.fromLine(String line) {
    // Parse something like   dashboard_app_session         8f846082 [origin/dashboard_app_session: gone] revert pubspec.lock change
    // the current branch is prefixed by `* `, a branch checked out in another
    // worktree by `+ `.
    line = line.trim();
    if (line.startsWith('* ') || line.startsWith('+ ')) {
      line = line.substring(2);
    }
    var parts = line.trim().split(RegExp(r'\s+'));
    var name = parts[0];
    var gone = line.contains(': gone]');
    return GitBranchResult(name: name, gone: gone);
  }
}
