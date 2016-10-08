library tekartik_sc.git;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';

import 'src/scpath.dart';

bool _DEBUG = false;

class GitStatusResult {
  final ProcessCmd cmd;
  final ProcessResult runResult;

  GitStatusResult(this.cmd, this.runResult);

  bool nothingToCommit = false;
  bool branchIsAhead = false;
}

class GitPath {
  String toString() => path;

  String _path;

  String get path => _path;

  GitPath(this._path);

  GitPath._();

  ProcessCmd _gitCmd(List<String> args) {
    ProcessCmd cmd = gitCmd(args)..workingDirectory = path;
    return cmd;
  }

  ProcessCmd pushCmd() {
    List<String> args = ['push'];
    return _gitCmd(args);
  }

  ProcessCmd pullCmd() {
    return _gitCmd(['pull']);
  }

  ProcessCmd statusCmd({bool short}) {
    List<String> args = ['status'];
    if (short == true) {
      args.add('--short');
    }
    return _gitCmd(args);
  }

  /// printResultIfChanges: show result if different than 'nothing to commit'
  Future<GitStatusResult> status() async {
    ProcessCmd cmd = statusCmd();
    ProcessResult result = await runCmd(cmd);
    GitStatusResult statusResult = new GitStatusResult(cmd, result);

    if (result.exitCode == 0) {
      Iterable<String> lines = LineSplitter.split(result.stdout);

      lines.forEach((String line) {
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
      });
    }

    return statusResult;
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

  ProcessCmd addCmd({String pathspec}) {
    List<String> args = ['add', pathspec];
    return _gitCmd(args);
  }

  ProcessCmd commitCmd(String message, {bool all}) {
    List<String> args = ['commit'];
    if (all == true) {
      args.add("--all");
    }
    args.addAll(['-m', message]);
    return _gitCmd(args);
  }

  ///
  /// branch can be a commit/revision number
  ProcessCmd checkoutCmd({String path, String commit}) {
    if (path != null) {
      return _gitCmd(['checkout', path]);
    } else {
      return _gitCmd(['checkout', commit]);
    }
  }
}

class GitProject extends GitPath {
  String src;

  GitProject(this.src, {String path,
  @deprecated // use path
  String rootFolder}) : super._() {
    // Handle null
    if (path == null) {
      var parts = scUriToPathParts(src);

      _path = joinAll(parts);

      if (_path == null) {
        throw new Exception(
            'null path only allowed for https://github.com/xxxuser/xxxproject src');
      }
      // ignore: deprecated_member_use
      if (rootFolder != null) {
        // ignore: deprecated_member_use
        _path = absolute(join(rootFolder, path));
      } else {
        _path = absolute(_path);
      }
    } else {
      this._path = path;
    }
  }

  // no using _gitCmd as not using workingDirectory
  // only get latest revision if [depth] = 1
  ProcessCmd cloneCmd({bool progress, int depth}) {
    List<String> args = ['clone'];
    if (progress == true) {
      args.add('--progress');
    }
    if (depth != null) {
      args.addAll(['--depth', depth.toString()]);
    }
    args.addAll([src, path]);
    return gitCmd(args);
  }

  Future pullOrClone() {
    // TODO: check the origin branch
    if (new File(join(path, '.git', 'config')).existsSync()) {
      return runCmd(pullCmd());
    } else {
      return runCmd(cloneCmd());
    }
  }
}

/// Version command
ProcessCmd gitVersionCmd() => gitCmd(['--version']);

/// check if git is supported
Future<bool> get isGitSupported async {
  try {
    await runCmd(gitVersionCmd());
    return true;
  } catch (e) {
    return false;
  }
}

ProcessCmd gitCmd(List<String> args) => processCmd('git', args);

/// Check if an url is a git repository
Future<bool> isGitRepository(String uri) async {
  ProcessResult runResult =
      await runCmd(gitCmd(['ls-remote', '--exit-code', '-h', uri]));
  // 2 is returned if not found
  // 128 if an error occured
  return (runResult.exitCode == 0) || (runResult.exitCode == 2);
}

Future<bool> isGitTopLevelPath(String path) async {
  String dotGit = ".git";
  String gitFile = join(path, dotGit);
  return await FileSystemEntity.isDirectory(gitFile);
}
