library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

import 'src/scpath.dart';

//bool _DEBUG = false;

class HgStatusResult {
  final ProcessCmd cmd;
  final ProcessResult runResult;
  HgStatusResult(this.cmd, this.runResult);
  bool nothingToCommit = false;
  //bool branchIsAhead = false;
}

class HgOutgoingResult {
  final ProcessCmd cmd;
  final ProcessResult runResult;
  HgOutgoingResult(this.cmd, this.runResult);
  bool branchIsAhead = false;
}

class HgPath {
  @override
  String toString() => path;
  final String _path;
  String get path => _path;
  HgPath(this._path);

  ProcessCmd _hgCmd(List<String> args) {
    return hgCmd(args)..workingDirectory = path;
  }

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

  ProcessCmd pushCmd() {
    final args = <String>['push'];
    return _hgCmd(args);
  }

  ProcessCmd pullCmd({bool update = true}) {
    final args = <String>['pull'];
    if (update) {
      args.add('-u');
    }
    return _hgCmd(args);
  }

  ProcessCmd addCmd({required String pathspec}) {
    final args = <String>['add', pathspec];
    return _hgCmd(args);
  }

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

class HgProject extends HgPath {
  String src;
  HgProject(this.src, {String? path, String? rootFolder})
      : super(path ?? joinAll(scUriToPathParts(src)));

  // Don't specify a working dir here
  // [insecure] added for travis test
  ProcessCmd cloneCmd({bool? insecure}) {
    final args = <String>[
      'clone',
      src,
      path,
      if (insecure == true) '--insecure'
    ];
    return hgCmd(args);
  }

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

bool get isHgSupportedSync => _isHgSupported ??= checkHgSupportedSync();

// can be disable by env variable
bool get checkHgSupportDisabled =>
    parseBool(Platform.environment['TEKARTIK_HG_SUPPORT']) == false;
bool checkHgSupportedSync({bool? verbose}) {
  if (checkHgSupportDisabled) {
    if (verbose == true) {
      print('hg disabled by env TEKARTIK_HG_SUPPORT');
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

Future<bool> get isHgSupported async {
  _isHgSupported ??= await checkHgSupported();
  return _isHgSupported!;
}

Future<bool> checkHgSupported({bool? verbose}) async {
  if (checkHgSupportDisabled) {
    if (verbose == true) {
      print('hg disabled by env TEKARTIK_HG_SUPPORT');
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
ProcessCmd hgCmd(List<String> args) {
  // Force hg language to english
  final environment = <String, String>{'LANGUAGE': 'en_US.UTF8'};
  return ProcessCmd('hg', args)..environment = environment;
}

ProcessCmd hgVersionCmd() => hgCmd(['--version']);

bool canBeHgRepository(String uri) {
  // this is only for git
  if (uri.startsWith('git@')) {
    return false;
  }
  return true;
}

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

bool isHgTopLevelPathSync(String path) {
  final dotHg = '.hg';
  final hgFile = join(path, dotHg);
  return FileSystemEntity.isDirectorySync(hgFile);
}

Future<bool> isHgTopLevelPath(String path) async {
  return isHgTopLevelPathSync(path);
}
