#!/usr/bin/env dart
library tekartik_sc.bin.scpp;

// Pull recursively

import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:path/path.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'package:tekartik_sc/src/std_buf.dart';
import 'package:tekartik_core/log_utils.dart';

const String _HELP = 'help';
const String _LOG = 'log';
const String _DRY_RUN = 'dry-run';

String get currentScriptName => basenameWithoutExtension(Platform.script.path);

///
/// Recursively update (pull) git folders
///
///
main(List<String> arguments) async {
  //Logger log;
  //setupQuickLogging();

  ArgParser parser = new ArgParser(allowTrailingOptions: true);
  parser.addFlag(_HELP, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addFlag("version",
      help: 'Display the script version', negatable: false);
  parser.addOption(_LOG, abbr: 'l', help: 'Log level (finest, finer, fine, debug, info...)');
  parser.addFlag(_DRY_RUN,
      abbr: 'n',
      help: 'Do not run test, simple show packages to be tested',
      negatable: false);

  ArgResults _argsResult = parser.parse(arguments);

  bool help = _argsResult[_HELP];
  if (help) {
    stdout.writeln(
        'Push & Pull(update) from source control recursively (default from current directory)');
    stdout.writeln();
    stdout.writeln(
        'Usage: ${currentScriptName} [<folder_paths...>] [<arguments>]');
    stdout.writeln();
    stdout.writeln("Global options:");
    stdout.writeln(parser.usage);
    return;
  }
  bool dryRun = _argsResult[_DRY_RUN];

  if (_argsResult['version']) {
    stdout.write('${currentScriptName} ${version}');
    return;
  }

  Level level = parseLogLevel(_argsResult[_LOG]);
  /*
  String logLevel = _argsResult[_LOG];
  if (logLevel != null) {
    setupQuickLogging(parseLogLevel(logLevel));
  }
  log = new Logger("rscpull");
  log.fine('Log level ${Logger.root.level}');
  */

  // get dirs in parameters, default to current
  List<String> dirs = _argsResult.rest;
  if (dirs.isEmpty) {
    dirs = [Directory.current.path];
  }

  List<Future> futures = [];

  bool _isHgSupported = await isHgSupported;
  bool _isGitSupported = await isGitSupported;

  Future _handleDir(String dir) async {
    Future<ProcessResult> _execute(StdBuf buf, ProcessCmd cmd) async {
      if (dryRun == true) {
        stdout.writeln(cmd);
        return null;
      } else {
        ProcessResult result = await runCmd(cmd);
        if (level <= Level.FINEST) {
          buf.appendCmdResult(cmd, result);
        }
        return result;
      }
    }
    // Ignore folder starting with .
    // don't event go below
    if (!basename(dir).startsWith('.') &&
        (await FileSystemEntity.isDirectory(dir))) {
      if (_isGitSupported && await isGitTopLevelPath(dir)) {
        StdBuf buf = new StdBuf();
        GitPath prj = new GitPath(dir);

        ProcessCmd cmd = prj.pushCmd();
        ProcessResult result = await _execute(buf, cmd);
        if (result.exitCode != 0 || !result.stderr.toString().contains('up-to-date')) {
          buf.outAppend('> ${cmd}');
          buf.appendResult(result);
        }
        cmd = prj.pullCmd();
        result = await _execute(buf, cmd);
        if (result.exitCode != 0 || !result.stdout.toString().contains('up-to-date')) {
          buf.outAppend('> ${cmd}');
          buf.appendResult(result);
        }

        buf.print("--- git ${prj}");
      } else if (_isHgSupported && await isHgTopLevelPath(dir)) {
        StdBuf buf = new StdBuf();
        HgPath prj = new HgPath(dir);
        //ProcessResult result =
        ProcessCmd cmd = prj.pushCmd();
        ProcessResult result = await _execute(buf, cmd);
        // exitCode seems to be always 1 on linux...
        // result.exitCode != 0 ||
        if (!result.stdout.toString().contains('no changes found')) {
          buf.outAppend('> ${cmd}');
          buf.appendResult(result);
        }
        cmd = prj.pullCmd();
        result = await _execute(buf, cmd);
        if (result.exitCode != 0 || !result.stdout.toString().contains('no changes found')) {
          buf.outAppend('> ${cmd}');
          buf.appendResult(result);
        }
        buf.print("--- hg ${prj}");
      } else {
        try {
          List<Future> sub = [];
          await new Directory(dir).list().listen((FileSystemEntity fse) {
            sub.add(_handleDir(fse.path));
          }).asFuture();
          await Future.wait(sub);
        } catch (_, __) {}
      }
    }
  }
  for (String dir in dirs) {
    print(dir);
    var _handle = _handleDir(dir);
    if (_handle is Future) {
      futures.add(_handle);
    }
  }
}
