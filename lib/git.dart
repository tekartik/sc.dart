library tekartik_sc.git;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';

import 'src/scpath.dart';

class _GitCommand {
  _GitCommand({this.runInShell});
  bool runInShell;
  String binaryPath;

  ProcessCmd processCmd(List<String> args) {
    return ProcessCmd(binaryPath ?? 'git', args,
        runInShell: runInShell ?? false);
  }
}

// default git command
_GitCommand _gitCommand;

_GitCommand _defaultGitCommand = _GitCommand();

//bool _DEBUG = false;

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

  GitPath([String path]) {
    this._path = path;
  }

  GitPath._();

  ProcessCmd _gitCmd(List<String> args) {
    ProcessCmd cmd = gitCmd(args)..workingDirectory = path;
    return cmd;
  }

  ProcessCmd cmd(List<String> args) {
    return _gitCmd(args);
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
  Future<GitStatusResult> status({bool verbose}) async {
    ProcessCmd cmd = statusCmd();
    if (verbose == true) {
      print('working dir: ${cmd.workingDirectory}');
    }
    ProcessResult result = await runCmd(cmd, verbose: verbose);
    GitStatusResult statusResult = GitStatusResult(cmd, result);

    if (result.exitCode == 0) {
      Iterable<String> lines = LineSplitter.split(result.stdout.toString());

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

  GitProject(
      this.src,
      {String path,
      @deprecated // use path
          String rootFolder})
      : super._() {
    // Handle null
    if (path == null) {
      var parts = scUriToPathParts(src);

      _path = joinAll(parts);

      if (_path == null) {
        throw Exception(
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
  ProcessCmd cloneCmd({bool progress, int depth, String branch}) {
    List<String> args = ['clone'];
    if (progress == true) {
      args.add('--progress');
    }
    if (depth != null) {
      args.addAll(['--depth', depth.toString()]);
    }
    if (branch != null) {
      args.addAll(['--branch', branch]);
    }
    args.addAll([src, path]);
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

/// Version command
ProcessCmd gitVersionCmd() => gitCmd(['--version']);

bool _isGitSupported;

/// check if git is supported, only once
Future<bool> get isGitSupported async => await checkGitSupported(once: true);

bool get isGitSupportedSync => _isGitSupported ??= checkGitSupportedSync();

bool checkGitSupportedSync({bool verbose}) {
  try {
    var result = Process.runSync('git', ['--version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

// [once] if true check only once and check the result for later calls with once: true
Future<bool> checkGitSupported({bool once, bool verbose}) async {
  if (once == true && _isGitSupported != null) {
    return _isGitSupported;
  }

  Future<bool> tryGitCommand(_GitCommand gitCommand, bool verbose) async {
    try {
      await runCmd(gitCommand.processCmd(['--version']), verbose: verbose);
      _isGitSupported = true;
      _gitCommand = gitCommand;
      return true;
    } catch (e, st) {
      if (verbose == true) {
        stderr.writeln(e);
        stderr.writeln(st);
      }
      _isGitSupported = false;
      return false;
    }
  }

  if (_gitCommand != null) {
    return tryGitCommand(_gitCommand, verbose);
  } else {
    if (!await tryGitCommand(_defaultGitCommand, false)) {
      return tryGitCommand(_GitCommand(runInShell: true), verbose);
    }
  }
  return true;
}

ProcessCmd gitCmd(List<String> args) =>
    (_gitCommand ?? _defaultGitCommand).processCmd(args);

// always true
bool canBeGitRepository(String uri) {
  return true;
}

/// Check if an url is a git repository
Future<bool> isGitRepository(String uri, {bool verbose}) async {
  if (!canBeGitRepository(uri)) {
    return false;
  }
  ProcessResult runResult = await runCmd(
      gitCmd(['ls-remote', '--exit-code', '-h', uri]),
      verbose: verbose);
  // 2 is returned if not found
  // 128 if an error occured
  return (runResult.exitCode == 0) || (runResult.exitCode == 2);
}

Future<bool> isGitTopLevelPath(String path) async {
  String dotGit = ".git";
  String gitFile = join(path, dotGit);
  return await FileSystemEntity.isDirectory(gitFile);
}
