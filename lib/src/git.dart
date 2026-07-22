import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:process_run/process_run.dart';
import 'package:tekartik_io_utils/io_utils_import.dart';
import 'package:tekartik_io_utils/path_utils.dart';
import 'package:tekartik_sc/git.dart';

import 'scpath.dart';

/// Proper git environment.
Map<String, String> gitEnvironment = {'LC_ALL': 'C'};

/// recursive git run pool size.
int get recursiveGitRunPoolSize => recursiveHandleScPathPoolSize;

/// recursive git run pool size.
set recursiveGitRunPoolSize(int value) {
  recursiveHandleScPathPoolSize = value;
}

/// Git command with proper environment.
extension GitPathExt on GitPath {
  /// Gets the list of branches.
  Future<List<String>> getBranches({bool? verbose, bool? remote}) async {
    return (await runGit(
      "branch${(remote ?? false) ? ' -r' : ''} --format='%(refname:short)'",
      verbose: verbose,
    )).outLines.toList();
  }

  /// Gets the current branch name.
  Future<String> getCurrentBranch({bool? verbose}) async {
    return (await runGit(
      'branch --show-current',
      verbose: verbose,
    )).outLines.first;
  }

  /// Gets the remote origin URL.
  Future<String> getRemoteOriginUrl({bool? verbose}) async {
    return (await runGit(
      'config --get remote.origin.url',
      verbose: verbose,
    )).outLines.first.trim();
  }

  /// Returns true if the GitHub repository is private using the `gh` CLI.
  /// Check if github cli is installed first
  Future<bool> githubIsPrivate({bool? verbose}) async {
    var shell = Shell(workingDirectory: path, verbose: verbose ?? false);
    var result = await shell.run(
      'gh repo view --json isPrivate --jq \'.isPrivate\'',
    );
    return bool.tryParse(result.outText.trim()) ?? false;
  }

  /// Returns true if the GitHub repository is private using the `git` CLI.
  Future<bool> isGithubRepo({bool? verbose}) async {
    var remoteOriginUrl = await getRemoteOriginUrl(verbose: verbose);
    return gitUrlGetHostname(remoteOriginUrl).toLowerCase() == 'github.com';
  }
}

/// Check if github cli is installed
Future<bool> isGithubCliInstalled() async {
  return (await which('gh')) != null;
}

/// Get the host name from a git url
/// git@github.com:xxxxx/xx.dart.git => github.com
/// git@gitlab.com:xxxxx/xx.dart.git => gitlab.com
/// https://gitlab.com/xxxxx/exp.dart => gitlab.com
/// Do not use Uri as it does not support git@ style urls
String gitUrlGetHostname(String url) {
  var uri = gitUrlToHttpsUri(url);
  return uri.host;
  /*
  var prefix = 'git@';
  if (url.startsWith(prefix)) {
    return url.substring(prefix.length).split(':').first.split('@').first;
  }

  var uri = Uri.parse(url);
  return uri.host;
   */
}

/// Converts a git URL to an HTTPS URI.
Uri gitUrlToHttpsUri(String url) {
  var prefix = 'git@';
  if (url.startsWith(prefix)) {
    var colonIndex = url.indexOf(':');
    var slashIndex = url.indexOf('/');
    if (colonIndex != -1 && (slashIndex == -1 || colonIndex < slashIndex)) {
      url = url.replaceFirst(':', '/');
    }
    url = 'https://${url.substring(prefix.length)}';
  }

  var uri = Uri.parse(url);
  if (uri.scheme.isEmpty) {
    // Assume https
    return uri.replace(scheme: 'https');
  }
  return uri;
}

/// Each path is tested
///
/// [poolSize] default to 4
Future<void> recursiveGitRun(
  List<String> paths, {
  required FutureOr<dynamic> Function(String package) action,
}) async {
  for (var path in paths) {
    await handleScPath(path, (dir) async {
      if (isGitTopLevelPathSync(dir)) {
        await action(dir);
      }
    }, recursive: true);
  }
}

/// Result of a git status command.
class GitStatusResult {
  /// The command that was run.
  final ProcessCmd cmd;

  /// The result of the command.
  final ProcessResult runResult;

  /// Creates a new GitStatusResult.
  GitStatusResult(this.cmd, this.runResult);

  /// Indicates if there is nothing to commit.
  bool nothingToCommit = false;

  /// Indicates if the branch is ahead of the remote.
  bool branchIsAhead = false;

  @override
  String toString() =>
      'Status(nothingToCommit: $nothingToCommit, branchIsAhead: $branchIsAhead)';
}

/// Represents a git repository path.
class GitPath {
  @override
  String toString() => path;

  final String _path;

  /// The path to the git repository.
  String get path => _path;

  /// Creates a new GitPath instance.
  GitPath(String path) : _path = path;

  ProcessCmd _gitCmd(List<String> args) {
    final cmd = gitCmd(args)..workingDirectory = path;
    return cmd;
  }

  /// Creates a generic git command for this path.
  ProcessCmd cmd(List<String> args) {
    return _gitCmd(args);
  }

  /// Creates a git push command.
  ProcessCmd pushCmd() {
    final args = <String>['push'];
    return _gitCmd(args);
  }

  /// Creates a git pull command.
  ProcessCmd pullCmd() {
    return _gitCmd(['pull']);
  }

  /// Creates a git status command.
  ProcessCmd statusCmd({bool? short}) {
    final args = <String>['status'];
    if (short == true) {
      args.add('--short');
    }
    return _gitCmd(args);
  }

  /// Creates a git branches command.
  ProcessCmd branchesCmd() {
    final args = <String>['branch', '-vv'];
    return _gitCmd(args);
  }

  /// Get the branches
  Future<GitBranchesResult> branches({bool? verbose}) async {
    final cmd = branchesCmd();
    final result = await runCmd(cmd, verbose: verbose);
    final branchesResult = GitBranchesResult.fromStdout(result.outText);
    return branchesResult;
  }

  /// printResultIfChanges: show result if different than 'nothing to commit'
  Future<GitStatusResult> status({bool? verbose}) async {
    final cmd = statusCmd();
    if (verbose == true) {
      stdout.writeln('working dir: ${cmd.workingDirectory}');
    }
    final result = await runCmd(cmd, verbose: verbose);
    final statusResult = GitStatusResult(cmd, result);

    if (result.exitCode == 0) {
      final lines = LineSplitter.split(result.stdout.toString());

      for (var line in lines) {
        // Linux /Win?/Mac?
        if (line.startsWith('nothing to commit')) {
          statusResult.nothingToCommit = true;
        }
        if (line.startsWith('Your branch is ahead of') ||
            line.startsWith('# Your branch is ahead of') // output of drone io
            ) {
          statusResult.branchIsAhead = true;
        }
      }
    }

    return statusResult;
  }

  /// Run a git command
  Future<ProcessResult> runGit(
    String command, {
    bool? verbose,
    bool? dryRun,
  }) async {
    if (dryRun == true) {
      stdout.writeln('[dry-run] git $command (in $path)');
      return ProcessResult(0, 0, '', '');
    }
    final cmd = gitCmd(stringToArguments(command))..workingDirectory = path;
    return runCmd(cmd, verbose: verbose);
  }

  /*
  not usable does not mention if ahead

  Future<GitStatusResult> statusShort() async {
    ProcessResult result = await runCmd(statusCmd(short :true));
    GitStatusResult statusResult = new GitStatusResult(result);

    if (result.exitCode == 0) {
      if ((result.stdout as String).isEmpty) {
        statusResult.nothingToCommit = true;
      }
    }

    return statusResult;
  }
     */

  /// Creates a git add command.
  ProcessCmd addCmd({required String pathspec}) {
    final args = <String>['add', pathspec];
    return _gitCmd(args);
  }

  /// Creates a git commit command.
  ProcessCmd commitCmd(String message, {bool? all}) {
    final args = <String>['commit'];
    if (all == true) {
      args.add('--all');
    }
    args.addAll(['-m', message]);
    return _gitCmd(args);
  }

  /// Creates a git checkout command.
  /// branch can be a commit/revision number
  ProcessCmd checkoutCmd({String? path, String? commit}) {
    if (path != null) {
      return _gitCmd(['checkout', path]);
    } else {
      return _gitCmd(['checkout', commit!]);
    }
  }

  /// Resets the current local branch to its `origin/<branch>` counterpart.
  ///
  /// If [branch] is omitted, the current branch is detected first.
  /// Set [dryRun] to true to print the command without executing it.
  Future<void> resetToOrigin({
    bool? verbose,
    String? branch,
    bool? dryRun,
  }) async {
    branch ??= await getCurrentBranch(verbose: false);
    var script = 'switch --force-create $branch origin/$branch';
    await runGit(script, verbose: verbose, dryRun: dryRun);
  }
}

/// Represents a git project for cloning.
class GitProject extends GitPath {
  /// The source URL of the git project.
  String src;

  /// Creates a new GitProject instance.
  GitProject(
    this.src, {
    String? path,
    @Deprecated('use path') String? rootFolder,
  }) : super(path ?? joinAll(scUriToPathParts(src)));

  // no using _gitCmd as not using workingDirectory
  // only get latest revision if [depth] = 1
  /// Creates a git clone command.
  ProcessCmd cloneCmd({bool? progress, int? depth, String? branch}) {
    final args = <String>[
      'clone',
      if (progress == true) '--progress',
      if (depth != null) ...['--depth', depth.toString()],
      if (branch != null) ...['--branch', branch],
      ...[src, path],
    ];
    return gitCmd(args);
  }

  /// Pulls if the repository exists, otherwise clones.
  Future pullOrClone() {
    // TODO: check the origin branch
    if (File(join(path, '.git', 'config')).existsSync()) {
      return runCmd(pullCmd());
    } else {
      return runCmd(cloneCmd());
    }
  }
}

/// checking recursively the parent for any hg or git directory
Future<String?> findGitTopLevelPath(String path) async {
  return await pathFindTopLevelDirPath(path, pathIsTopLevel: isGitTopLevelPath);
}
