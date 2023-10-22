library tekartik_sc.git;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:process_run/process_run.dart';

import 'src/scpath.dart';
export 'src/git.dart' show GitPathExt;

class _GitCommand {
  _GitCommand({this.runInShell});
  bool? runInShell;
  String? binaryPath;

  ProcessCmd processCmd(List<String> args) {
    return ProcessCmd(binaryPath ?? 'git', args,
        // Force english
        environment: {'LC_ALL': 'C'},
        runInShell: runInShell ?? false);
  }
}

// default git command
_GitCommand? _gitCommand;

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

/// Version command
ProcessCmd gitVersionCmd() => gitCmd(['--version']);

bool? _isGitSupported;

/// check if git is supported, only once
Future<bool> get isGitSupported async =>
    _isGitSupported ??= await checkGitSupported();

bool get isGitSupportedSync => _isGitSupported ??= checkGitSupportedSync();

bool checkGitSupportedSync({bool? verbose}) {
  try {
    var result = Process.runSync('git', ['--version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

// [once] if true check only once and check the result for later calls with once: true
Future<bool> checkGitSupported({bool? verbose}) async {
  Future<bool> tryGitCommand(_GitCommand gitCommand, bool? verbose) async {
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
    return tryGitCommand(_gitCommand!, verbose);
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
Future<bool> isGitRepository(String uri, {bool? verbose}) async {
  if (!canBeGitRepository(uri)) {
    return false;
  }
  final runResult = await runCmd(
      gitCmd(['ls-remote', '--exit-code', '-h', uri]),
      verbose: verbose);
  // 2 is returned if not found
  // 128 if an error occured
  return (runResult.exitCode == 0) || (runResult.exitCode == 2);
}

Future<bool> isGitTopLevelPath(String path) async {
  return isGitTopLevelPathSync(path);
}

bool isGitTopLevelPathSync(String path) {
  final dotGit = '.git';
  final gitFile = join(path, dotGit);
  return FileSystemEntity.isDirectorySync(gitFile);
}
