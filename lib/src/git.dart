import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:process_run/process_run.dart';
import 'package:tekartik_io_utils/io_utils_import.dart';
import 'package:tekartik_sc/git.dart';

import 'scpath.dart';

extension GitPathExt on GitPath {
  Future<List<String>> getBranches({bool? verbose}) async {
    return (await runGit("branch --format='%(refname:short)'",
            verbose: verbose))
        .outLines
        .toList();
  }

  Future<String> getCurrentBranch({bool? verbose}) async {
    return (await runGit('branch --show-current', verbose: verbose))
        .outLines
        .first;
  }
}

/// Each path is tested
///
/// [poolSize] default to 4
Future<void> recursiveGitRun(List<String> paths,
    {required FutureOr<dynamic> Function(String package) action}) async {
  for (var path in paths) {
    await handleScPath(path, (dir) {
      if (isGitTopLevelPathSync(dir)) {
        action(dir);
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
                line.startsWith(
                    '# Your branch is ahead of') // output of drone io
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

  GitProject(this.src,
      {String? path, @Deprecated('use path') String? rootFolder})
      : super(path ?? joinAll(scUriToPathParts(src)));

  // no using _gitCmd as not using workingDirectory
  // only get latest revision if [depth] = 1
  ProcessCmd cloneCmd({bool? progress, int? depth, String? branch}) {
    final args = <String>[
      'clone',
      if (progress == true) '--progress',
      if (depth != null) ...['--depth', depth.toString()],
      if (branch != null) ...['--branch', branch],
      ...[src, path]
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
