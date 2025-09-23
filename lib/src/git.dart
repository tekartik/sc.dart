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

extension GitPathExt on GitPath {
  Future<List<String>> getBranches({bool? verbose, bool? remote}) async {
    return (await runGit(
      "branch${(remote ?? false) ? ' -r' : ''} --format='%(refname:short)'",
      verbose: verbose,
    )).outLines.toList();
  }

  Future<String> getCurrentBranch({bool? verbose}) async {
    return (await runGit(
      'branch --show-current',
      verbose: verbose,
    )).outLines.first;
  }

  Future<String> getRemoteOriginUrl({bool? verbose}) async {
    return (await runGit(
      'config --get remote.origin.url',
      verbose: verbose,
    )).outLines.first.trim();
  }
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

class GitStatusResult {
  final ProcessCmd cmd;
  final ProcessResult runResult;

  GitStatusResult(this.cmd, this.runResult);

  bool nothingToCommit = false;
  bool branchIsAhead = false;
}

class GitPath {
  @override
  String toString() => path;

  final String _path;

  String get path => _path;

  GitPath(String path) : _path = path;

  ProcessCmd _gitCmd(List<String> args) {
    final cmd = gitCmd(args)..workingDirectory = path;
    return cmd;
  }

  ProcessCmd cmd(List<String> args) {
    return _gitCmd(args);
  }

  ProcessCmd pushCmd() {
    final args = <String>['push'];
    return _gitCmd(args);
  }

  ProcessCmd pullCmd() {
    return _gitCmd(['pull']);
  }

  ProcessCmd statusCmd({bool? short}) {
    final args = <String>['status'];
    if (short == true) {
      args.add('--short');
    }
    return _gitCmd(args);
  }

  /// printResultIfChanges: show result if different than 'nothing to commit'
  Future<GitStatusResult> status({bool? verbose}) async {
    final cmd = statusCmd();
    if (verbose == true) {
      print('working dir: ${cmd.workingDirectory}');
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
  Future<ProcessResult> runGit(String command, {bool? verbose}) async {
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

  ProcessCmd addCmd({required String pathspec}) {
    final args = <String>['add', pathspec];
    return _gitCmd(args);
  }

  ProcessCmd commitCmd(String message, {bool? all}) {
    final args = <String>['commit'];
    if (all == true) {
      args.add('--all');
    }
    args.addAll(['-m', message]);
    return _gitCmd(args);
  }

  ///
  /// branch can be a commit/revision number
  ProcessCmd checkoutCmd({String? path, String? commit}) {
    if (path != null) {
      return _gitCmd(['checkout', path]);
    } else {
      return _gitCmd(['checkout', commit!]);
    }
  }
}

class GitProject extends GitPath {
  String src;

  GitProject(
    this.src, {
    String? path,
    @Deprecated('use path') String? rootFolder,
  }) : super(path ?? joinAll(scUriToPathParts(src)));

  // no using _gitCmd as not using workingDirectory
  // only get latest revision if [depth] = 1
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

  Future pullOrClone() {
    // TODO: check the origin branch
    if (File(join(path, '.git', 'config')).existsSync()) {
      return runCmd(pullCmd());
    } else {
      return runCmd(cloneCmd());
    }
  }
}

///
/// checking recursively the parent for any hg or git directory
///
Future<String?> findGitTopLevelPath(String path) async {
  return await pathFindTopLevelDirPath(path, pathIsTopLevel: isGitTopLevelPath);
}
