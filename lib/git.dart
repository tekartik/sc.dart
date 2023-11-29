library tekartik_sc.git;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';

export 'src/git.dart'
    show
        GitPathExt,
        recursiveGitRun,
        GitPath,
        GitProject,
        GitStatusResult,
        findGitTopLevelPath;

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
