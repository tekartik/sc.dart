library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

import 'src/scpath.dart';

//bool _DEBUG = false;

/// Hg status result.
class HgStatusResult {
  /// Command.
  final ProcessCmd cmd;

  /// Run result.
  final ProcessResult runResult;

  /// Hg status result.
  HgStatusResult(this.cmd, this.runResult);

  /// Nothing to commit.
  bool nothingToCommit = false;
  //bool branchIsAhead = false;
}

/// Hg outgoing result.
class HgOutgoingResult {
  /// Command.
  final ProcessCmd cmd;

  /// Run result.
  final ProcessResult runResult;

  /// Hg outgoing result.
  HgOutgoingResult(this.cmd, this.runResult);

  /// Branch is ahead.
  bool branchIsAhead = false;
}

/// Hg path.
class HgPath {
  @override
  String toString() => path;
  final String _path;

  /// Path.
  String get path => _path;

  /// Hg path.
  HgPath(this._path);

  ProcessCmd _hgCmd(List<String> args) {
    return hgCmd(args)..workingDirectory = path;
  }

  /// Status.
  Future<HgStatusResult> status({bool? verbose}) async {
    final cmd = _hgCmd(['status']);
    final result = await runCmd(cmd, verbose: verbose);

    final statusResult = HgStatusResult(cmd, result);

    //bool showResult = true;
    if (result.exitCode == 0) {
      if (result.stdout.toString().isEmpty) {
        statusResult.nothingToCommit = true;
      }
    }

    return statusResult;
  }

  /// Outgoing.
  Future<HgOutgoingResult> outgoing() async {
    final cmd = _hgCmd(['outgoing']);
    final result = await runCmd(cmd);
    final outgoingResult = HgOutgoingResult(cmd, result);
    switch (result.exitCode) {
      case 0:
      case 1:
        {
          final lines = LineSplitter.split(result.stdout as String);
          //print(lines.last);
          if (lines.last.startsWith('no changes found') ||
              lines.last.startsWith('aucun changement')) {
            outgoingResult.branchIsAhead = false;
          } else {
            outgoingResult.branchIsAhead = true;
          }
        }
    }

    return outgoingResult;
  }

  /// Revert command.
  ProcessCmd revertCmd({String? path, bool? noBackup}) {
    final args = <String>['revert'];
    if (path != null) {
      args.add(path);
    }
    if (noBackup == true) {
      args.add('--no-backup');
    }
    return _hgCmd(args);
  }

  /// Push command.
  ProcessCmd pushCmd() {
    final args = <String>['push'];
    return _hgCmd(args);
  }

  /// Pull command.
  ProcessCmd pullCmd({bool update = true}) {
    final args = <String>['pull'];
    if (update) {
      args.add('-u');
    }
    return _hgCmd(args);
  }

  /// Add command.
  ProcessCmd addCmd({required String pathspec}) {
    final args = <String>['add', pathspec];
    return _hgCmd(args);
  }

  /// Commit command.
  ProcessCmd commitCmd(String message, {bool? all}) {
    final args = <String>['commit'];
    if (all == true) {
      args.add('--all');
    }
    args.addAll(['-m', message]);
    return _hgCmd(args);
  }

  ///
  /// branch can be a commit/revision number
  ProcessCmd checkoutCmd({required String commit}) {
    return _hgCmd(['checkout', commit]);
  }
}

/// Hg project.
class HgProject extends HgPath {
  /// Source.
  String src;

  /// Hg project.
  HgProject(this.src, {String? path, String? rootFolder})
    : super(path ?? joinAll(scUriToPathParts(src)));

  // Don't specify a working dir here
  // [insecure] added for travis test
  /// Clone command.
  ProcessCmd cloneCmd({bool? insecure}) {
    final args = <String>[
      'clone',
      src,
      path,
      if (insecure == true) '--insecure',
    ];
    return hgCmd(args);
  }

  /// Pull or clone.
  Future pullOrClone() {
    // TODO: check the origin branch
    if (File(join(path, '.hg', 'hgrc')).existsSync()) {
      return runCmd(pullCmd());
    } else {
      return runCmd(cloneCmd());
    }
  }
}

bool? _isHgSupported;

/// Check if hg is supported (sync).
bool get isHgSupportedSync => _isHgSupported ??= checkHgSupportedSync();

// can be disable by env variable
/// Check if hg support is disabled.
bool get checkHgSupportDisabled =>
    parseBool(Platform.environment['TEKARTIK_HG_SUPPORT']) == false;

/// Check if hg is supported (sync).
bool checkHgSupportedSync({bool? verbose}) {
  if (checkHgSupportDisabled) {
    if (verbose == true) {
      stdout.writeln('hg disabled by env TEKARTIK_HG_SUPPORT');
    }
    return false;
  }
  try {
    var result = Process.runSync('hg', ['--version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

/// Check if hg is supported.
Future<bool> get isHgSupported async {
  _isHgSupported ??= await checkHgSupported();
  return _isHgSupported!;
}

/// Check if hg is supported.
Future<bool> checkHgSupported({bool? verbose}) async {
  if (checkHgSupportDisabled) {
    if (verbose == true) {
      stdout.writeln('hg disabled by env TEKARTIK_HG_SUPPORT');
    }
    return false;
  }
  try {
    await runCmd(hgVersionCmd(), verbose: verbose);
    return true;
  } catch (e) {
    return false;
  }
}

/*
@deprecated
Future<ProcessResult> hgRun(List<String> args,
        {String workingDirectory, bool connectIo: false}) =>
    runHg(args, workingDirectory: workingDirectory, connectIo: connectIo);
*/
/// Hg command.
ProcessCmd hgCmd(List<String> args) {
  // Force hg language to english
  final environment = <String, String>{'LANGUAGE': 'en_US.UTF8'};
  return ProcessCmd('hg', args)..environment = environment;
}

/// Hg version command.
ProcessCmd hgVersionCmd() => hgCmd(['--version']);

/// Check if it can be an hg repository.
bool canBeHgRepository(String uri) {
  // this is only for git
  if (uri.startsWith('git@')) {
    return false;
  }
  return true;
}

/// Check if it is an hg repository.
Future<bool> isHgRepository(String uri, {bool? verbose, bool? insecure}) async {
  if (!canBeHgRepository(uri)) {
    return false;
  }
  var args = ['identify', uri];
  if (insecure == true) {
    args.add('--insecure');
  }
  final runResult = await runCmd(hgCmd(args), verbose: verbose);
  // 0 is returned if found (or empty), out contains the last revision number such as 947e3404e4b7
  // 255 if an error occured
  return (runResult.exitCode == 0);
}

/// Check if path is hg top level path (sync).
bool isHgTopLevelPathSync(String path) {
  final dotHg = '.hg';
  final hgFile = join(path, dotHg);
  return FileSystemEntity.isDirectorySync(hgFile);
}

/// Check if path is hg top level path.
Future<bool> isHgTopLevelPath(String path) async {
  return isHgTopLevelPathSync(path);
}
