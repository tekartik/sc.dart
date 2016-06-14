library tekartik_sc.hg;

import 'dart:async';
import 'dart:io';

import 'dart:convert';
import 'package:process_run/cmd_run.dart';
import 'src/scpath.dart';
import 'package:path/path.dart';

bool _DEBUG = false;

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
  String toString() => path;
  String _path;
  String get path => _path;
  HgPath(this._path);
  HgPath._();

  ProcessCmd _hgCmd(List<String> args) {
    return hgCmd(args)..workingDirectory = path;
  }

  Future<HgStatusResult> status() async {
    ProcessCmd cmd = _hgCmd(['status']);
    ProcessResult result = await runCmd(cmd);

    HgStatusResult statusResult = new HgStatusResult(cmd, result);

    //bool showResult = true;
    if (result.exitCode == 0) {
      if (result.stdout.isEmpty) {
        statusResult.nothingToCommit = true;
      }
    }

    return statusResult;
  }

  Future<HgOutgoingResult> outgoing() async {
    ProcessCmd cmd = _hgCmd(['outgoing']);
    ProcessResult result = await runCmd(cmd);
    HgOutgoingResult outgoingResult = new HgOutgoingResult(cmd, result);
    switch (result.exitCode) {
      case 0:
      case 1:
        {
          Iterable<String> lines = LineSplitter.split(result.stdout);
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

  ProcessCmd revertCmd({String path, bool noBackup}) {
    List<String> args = ['revert'];
    if (path != null) {
      args.add(path);
    }
    if (noBackup == true) {
      args.add('--no-backup');
    }
    return _hgCmd(args);
  }

  ProcessCmd pushCmd() {
    List<String> args = ['push'];
    return _hgCmd(args);
  }

  ProcessCmd pullCmd({bool update: true}) {
    List<String> args = ['pull'];
    if (update == true) {
      args.add('-u');
    }
    return _hgCmd(args);
  }

  ProcessCmd addCmd({String pathspec}) {
    List<String> args = ['add', pathspec];
    return _hgCmd(args);
  }

  ProcessCmd commitCmd(String message, {bool all}) {
    List<String> args = ['commit'];
    if (all == true) {
      args.add("--all");
    }
    args.addAll(['-m', message]);
    return _hgCmd(args);
  }

  ///
  /// branch can be a commit/revision number
  ProcessCmd checkoutCmd({String commit}) {
    return _hgCmd(['checkout', commit]);
  }
}

class HgProject extends HgPath {
  String src;
  HgProject(this.src, {String path, String rootFolder}) : super._() {
    var parts = scUriToPathParts(src);

    _path = joinAll(parts);

    if (_path == null) {
      throw new Exception(
          'null path only allowed for https://github.com/xxxuser/xxxproject src');
    }
    if (rootFolder != null) {
      _path = absolute(join(rootFolder, path));
    } else {
      _path = absolute(_path);
    }
  }

  // Don't specify a working dir here
  ProcessCmd cloneCmd() {
    List<String> args = ['clone'];
    args.addAll([src, path]);
    return hgCmd(args);
  }

  Future pullOrClone() {
    // TODO: check the origin branch
    if (new File(join(path, '.hg', 'hgrc')).existsSync()) {
      return runCmd(pullCmd());
    } else {
      return runCmd(cloneCmd());
    }
  }
}

Future<bool> get isHgSupported async {
  try {
    await runCmd(hgVersionCmd());
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
  Map<String, String> environment = {"LANGUAGE": "en_US.UTF8"};
  return processCmd("hg", args)..environment = environment;
}

ProcessCmd hgVersionCmd() => hgCmd(['--version']);

Future<bool> isHgRepository(String uri) async {
  ProcessResult runResult = await runCmd(hgCmd(['identify', uri])
    ..connectStdout = false
    ..connectStderr = false);
  // 0 is returned if found (or empty), out contains the last revision number such as 947e3404e4b7
  // 255 if an error occured
  return (runResult.exitCode == 0);
}

Future<bool> isHgTopLevelPath(String path) async {
  String dotHg = ".hg";
  String hgFile = join(path, dotHg);
  return await FileSystemEntity.isDirectory(hgFile);
}
