#!/usr/bin/env dart
library tekartik_sc.bin.scstatus;

// Pull recursively

import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'package:tekartik_sc/src/std_buf.dart';
import 'package:process_run/cmd_run.dart';
import 'package:path/path.dart';
import 'package:tekartik_common_utils/log_utils.dart';
import 'package:logging/logging.dart';

const String _HELP = 'help';
const String _LOG = 'log';

String get currentScriptName => basenameWithoutExtension(Platform.script.path);

///
/// Recursively update (pull) git folders
///
///
void main(List<String> arguments) {
  //setupQuickLogging();

  ArgParser parser = new ArgParser(allowTrailingOptions: true);
  parser.addFlag(_HELP, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addFlag("version",
      help: 'Display the script version', negatable: false);
  parser.addOption(_LOG,
      abbr: 'l', help: 'Log level (finest, finer, fine, debug, info...)');

  ArgResults _argsResult = parser.parse(arguments);

  bool help = _argsResult[_HELP];
  if (help) {
    stdout.writeln(
        'Display source control status recursively (default from current directory)');
    stdout.writeln();
    stdout.writeln(
        'Usage: ${currentScriptName} [<folder_paths...>] [<arguments>]');
    stdout.writeln();
    stdout.writeln("Global options:");
    stdout.writeln(parser.usage);
    return;
  }

  Level level = parseLogLevel(_argsResult[_LOG]);

  if (_argsResult['version']) {
    stdout.write('${currentScriptName} ${version}');
    return;
  }
  /*
  String logLevel = _argsResult[_LOG];
  if (logLevel != null) {
    setupQuickLogging(parseLogLevel(logLevel));
  }
  log = new Logger("rscstatus");
  log.fine('Log level ${Logger.root.level}');
  */

  // get dirs in parameters, default to current
  List<String> dirs = _argsResult.rest;
  if (dirs.isEmpty) {
    dirs = [Directory.current.path];
  }

  List<Future> futures = [];

  Future _handleDir(String dir) async {
    if (await FileSystemEntity.isDirectory(dir)) {
      if (await isGitTopLevelPath(dir)) {
        GitPath prj = new GitPath(dir);

        GitStatusResult statusResult = await (prj.status());

        StdBuf buf = new StdBuf();
        if (level <= Level.FINEST) {
          buf.outAppend('--- git ${prj}');
          buf.outAppend('> ${statusResult.cmd}');
          buf.appendResult(statusResult.runResult);
        }
        if (statusResult.branchIsAhead || !statusResult.nothingToCommit) {
          buf.outAppend('--- git ${prj}');
          if (statusResult.branchIsAhead) {
            buf.outAppend('Branch is ahread');
          }
          //stdout.writeln(statusResult.runResult.stdout);
          // rerun in short version mode
          ProcessCmd cmd = prj.statusCmd(short: true);
          if (level <= Level.FINEST) {
            buf.outAppend('> ${cmd}');
          }
          ProcessResult result = await runCmd(cmd);
          buf.appendResult(result);
        }
        buf.print();
      } else if (await isHgTopLevelPath(dir)) {
        HgPath prj = new HgPath(dir);

        StdBuf buf = new StdBuf();
        HgStatusResult statusResult = await (prj.status());
        if (level <= Level.FINEST) {
          buf.outAppend('--- hg ${prj}');
          buf.outAppend('> ${statusResult.cmd}');
          buf.appendResult(statusResult.runResult);
        }
        if (statusResult.nothingToCommit) {
          HgOutgoingResult outgoingResult = await (prj.outgoing());
          if (level <= Level.FINEST) {
            buf.outAppend('> ${outgoingResult.cmd}');
          }
          if (outgoingResult.branchIsAhead) {
            buf.outAppend('--- hg ${prj}');
            buf.outAppend('Branch is ahead');
            buf.appendResult(outgoingResult.runResult);
          }
        } else {
          buf.outAppend('--- hg ${prj}');
          buf.appendResult(statusResult.runResult);
        }
        buf.print();
      } else {
        try {
          List<Future> sub = [];
          await new Directory(dir).list().listen((FileSystemEntity fse) {
            sub.add(_handleDir(fse.path));
          }).asFuture();
          await Future.wait(sub);
        } catch (_, __) {
          // log.fine(e.toString(), e, st);
        }
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
