library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';

import 'src/git.dart';

export 'src/git.dart'
    show
        gitEnvironment,
        GitPathExt,
        recursiveGitRun,
        GitPath,
        GitProject,
        GitStatusResult,
        findGitTopLevelPath,
        recursiveGitRunPoolSize,
        gitUrlGetHostname,
        gitUrlToHttpsUri;
export 'src/git_branches.dart' show GitBranchResult, GitBranchesResult;

/// A class that represents a Git command.
class _GitCommand {
  _GitCommand({this.runInShell});

  /// Whether to run the command in a shell.
  bool? runInShell;

  /// The binary path of the Git executable.
  String? binaryPath;

  /// Creates a [ProcessCmd] object for the given arguments.
  ProcessCmd processCmd(List<String> args) {
    return ProcessCmd(
      binaryPath ?? 'git',
      args,
      // Force english
      environment: gitEnvironment,
      runInShell: runInShell ?? false,
    );
  }
}

// default git command
_GitCommand? _gitCommand;

_GitCommand _defaultGitCommand = _GitCommand();

//bool _DEBUG = false;

/// Version command
ProcessCmd gitVersionCmd() => gitCmd(['--version']);

bool? _isGitSupported;

/// check if git is supported, only once
Future<bool> get isGitSupported async =>
    _isGitSupported ??= await checkGitSupported();

/// Check if git is supported (sync).
bool get isGitSupportedSync => _isGitSupported ??= checkGitSupportedSync();

/// Check if git is supported (sync).
bool checkGitSupportedSync({bool? verbose}) {
  try {
    var result = Process.runSync('git', ['--version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

// [once] if true check only once and check the result for later calls with once: true
/// Check if git is supported.
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

/// Git command.
ProcessCmd gitCmd(List<String> args) =>
    (_gitCommand ?? _defaultGitCommand).processCmd(args);

// always true
/// Check if it can be a git repository.
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
    verbose: verbose,
  );
  // 2 is returned if if no matching refs are found
  // 128 if an error occurred
  return (runResult.exitCode == 0) || (runResult.exitCode == 2);
}

/// Check if a path is a git top level path.
Future<bool> isGitTopLevelPath(String path) async {
  return isGitTopLevelPathSync(path);
}

/// Check if a path is a git top level path (sync).
bool isGitTopLevelPathSync(String path) {
  final dotGit = '.git';
  final gitFile = join(path, dotGit);
  return FileSystemEntity.isDirectorySync(gitFile);
}
