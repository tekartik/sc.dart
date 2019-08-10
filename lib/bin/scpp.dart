#!/usr/bin/env dart
library tekartik_sc.bin.scpp;

// Pull recursively

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_common_utils/log_utils.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/sc.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'package:tekartik_sc/src/scpath.dart';
import 'package:tekartik_sc/src/std_buf.dart';

const String _helpFlag = 'help';
const String _logOption = 'log';
const String _dryRunFlag = 'dry-run';
const String verboseFlag = 'verbose';
const String timeoutOption = 'timeout';

String get currentScriptName => basenameWithoutExtension(Platform.script.path);

///
/// Recursively update (pull) git folders
///
///
Future main(List<String> arguments) async {
  //Logger log;
  //setupQuickLogging();

  ArgParser parser = ArgParser(allowTrailingOptions: true);
  parser.addFlag(_helpFlag, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addFlag("version",
      help: 'Display the script version', negatable: false);
  parser.addFlag(verboseFlag,
      abbr: 'v', help: 'Verbose output', negatable: false);
  parser.addOption(_logOption,
      abbr: 'l', help: 'Log level (finest, finer, fine, debug, info...)');
  parser.addOption(timeoutOption,
      abbr: 't', help: 'Timeout for each operation in milliseconds');
  parser.addFlag(_dryRunFlag,
      abbr: 'n',
      help: 'Do not run test, simple show packages to be tested',
      negatable: false);

  ArgResults argResults = parser.parse(arguments);

  bool help = argResults[_helpFlag] as bool;
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
  bool dryRun = argResults[_dryRunFlag] as bool;
  var timeout = int.tryParse((argResults[timeoutOption] as String) ?? '');

  if (argResults['version'] as bool) {
    stdout.write('${currentScriptName} ${version}');
    return;
  }

  bool verbose = argResults[verboseFlag] as bool;
  Level level = parseLogLevel(argResults[_logOption] as String);
  if (verbose) {
    level = Level.FINEST;
  }
  /*
  String logLevel = _argsResult[_LOG];
  if (logLevel != null) {
    setupQuickLogging(parseLogLevel(logLevel));
  }
  log = new Logger("rscpull");
  log.fine('Log level ${Logger.root.level}');
  */

  // get dirs in parameters, default to current
  List<String> dirs = argResults.rest;
  if (dirs.isEmpty) {
    dirs = [Directory.current.path];
  }

  List<Future> futures = [];

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

    if (await isGitPathAndSupported(dir)) {
      StdBuf buf = StdBuf();
      GitPath prj = GitPath(dir);

      var statusResult = await prj.status();
      // Only push if branch is ahead
      if (statusResult.branchIsAhead) {
        ProcessCmd cmd = prj.pushCmd();
        ProcessResult result = await _execute(buf, cmd);
        // dry-run returns null
        if (result != null) {
          if (result.exitCode != 0 ||
              !result.stderr.toString().contains('up-to-date')) {
            buf.outAppend('> ${cmd}');
            buf.appendResult(result);
          }
        }
      } else {
        if (level <= Level.FINEST) {
          buf.outAppend("no push, branch is not ahead");
        }
      }
      var cmd = prj.pullCmd();
      var result = await _execute(buf, cmd);
      // dry-run returns null
      if (result != null) {
        var pullOutput = result.stdout.toString();
        if (result.exitCode != 0 ||
            !(pullOutput.contains('up-to-date') ||
                pullOutput.contains('up to date'))) {
          buf.outAppend('> ${cmd}');
          buf.appendResult(result);
        }
      }

      buf.print("--- git ${prj}");
    } else if (await isHgPathAndSupported(dir)) {
      StdBuf buf = StdBuf();
      HgPath prj = HgPath(dir);
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
      if (result.exitCode != 0 ||
          !result.stdout.toString().contains('no changes found')) {
        buf.outAppend('> ${cmd}');
        buf.appendResult(result);
      }
      buf.print("--- hg ${prj}");
    }
  }

  Future _handleDirWithTimeout(String dir) async {
    if (timeout != null) {
      await _handleDir(dir)
          .timeout(Duration(milliseconds: timeout))
          .catchError((e) {
        stderr.writeln("$e for $dir");
      });
    } else {
      await _handleDir(dir);
    }
  }

  for (String dir in dirs) {
    print(dir);
    var _handle = handleScPath(dir, _handleDirWithTimeout, recursive: true);
    if (_handle is Future) {
      futures.add(_handle);
    }
  }

  await Future.wait(futures);
}
