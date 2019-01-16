#!/usr/bin/env dart
library tekartik_sc.bin.scstatus;

// Pull recursively

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_common_utils/log_utils.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/sc.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'package:tekartik_sc/src/scpath.dart';
import 'package:tekartik_sc/src/std_buf.dart';

const String _HELP = 'help';
const String _LOG = 'log';
const String verboseFlag = 'verbose';

String get currentScriptName => basenameWithoutExtension(Platform.script.path);

///
/// Recursively update (pull) git folders
///
///
Future main(List<String> arguments) async {
  //setupQuickLogging();

  ArgParser parser = ArgParser(allowTrailingOptions: true);
  parser.addFlag(_HELP, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addFlag("version",
      help: 'Display the script version', negatable: false);
  parser.addFlag(verboseFlag, abbr: 'v', help: 'Verbose', negatable: false);
  parser.addOption(_LOG,
      abbr: 'l', help: 'Log level (finest, finer, fine, debug, info...)');

  ArgResults _argsResult = parser.parse(arguments);

  bool help = _argsResult[_HELP] as bool;
  if (help) {
    stdout.writeln(
        'Display source control status recursively (default from current directory)');
    stdout.writeln();
    stdout.writeln(
        'Usage: ${currentScriptName} [<folder_paths...>] [<arguments>]');
    stdout.writeln();
    stdout.writeln("--log finer will display all path");
    stdout.writeln("--log finest will display all path and command executed");
    stdout.writeln();
    stdout.writeln("Global options:");
    stdout.writeln(parser.usage);
    return;
  }

  Level level = parseLogLevel(_argsResult[_LOG] as String);
  if (_argsResult[verboseFlag] as bool) {
    level = Level.FINEST;
  }

  bool commandVerbose = level <= Level.FINEST;

  if (_argsResult['version'] as bool) {
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
    if (await isGitPathAndSupported(dir)) {
      GitPath prj = GitPath(dir);

      GitStatusResult statusResult = await (prj.status());

      StdBuf buf = StdBuf();
      if (level <= Level.FINER) {
        buf.outAppend('--- git ${prj}');
      }
      if (level <= Level.FINEST) {
        buf.outAppend('> ${statusResult.cmd}');
        buf.appendResult(statusResult.runResult);
      }
      if (statusResult.branchIsAhead || !statusResult.nothingToCommit) {
        // already done
        if (level > Level.FINER) {
          buf.outAppend('--- git ${prj}');
        }
        if (statusResult.branchIsAhead) {
          buf.outAppend('Branch is ahead');
        }
        //stdout.writeln(statusResult.runResult.stdout);
        // rerun in short version mode
        ProcessCmd cmd = prj.statusCmd(short: true);
        if (level <= Level.FINEST) {
          buf.outAppend('> ${cmd}');
        }
        ProcessResult result =
            await runCmd(cmd, commandVerbose: commandVerbose);
        buf.appendResult(result);
      }
      buf.print();
    } else if (await isHgPathAndSupported(dir)) {
      HgPath prj = HgPath(dir);

      StdBuf buf = StdBuf();
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
    }
  }

  for (String dir in dirs) {
    print(dir);
    var _handle = handleScPath(dir, _handleDir, recursive: true);
    if (_handle is Future) {
      futures.add(_handle);
    }
  }

  await Future.wait(futures);
}
