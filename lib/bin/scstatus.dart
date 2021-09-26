import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_common_utils/log_utils.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'package:tekartik_sc/src/scpath.dart';
import 'package:tekartik_sc/src/std_buf.dart';

const String _helpFlag = 'help';
const String _logOption = 'log';
const String verboseFlag = 'verbose';

String get currentScriptName => basenameWithoutExtension(Platform.script.path);

///
/// Recursively update (pull) git folders
///
///
Future main(List<String> arguments) async {
  //setupQuickLogging();

  final parser = ArgParser(allowTrailingOptions: true);
  parser.addFlag(_helpFlag, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addFlag('version',
      help: 'Display the script version', negatable: false);
  parser.addFlag(verboseFlag, abbr: 'v', help: 'Verbose', negatable: false);
  parser.addOption(_logOption,
      abbr: 'l', help: 'Log level (finest, finer, fine, debug, info...)');

  final _argsResult = parser.parse(arguments);

  final help = _argsResult[_helpFlag] as bool;
  if (help) {
    stdout.writeln(
        'Display source control status recursively (default from current directory)');
    stdout.writeln();
    stdout
        .writeln('Usage: $currentScriptName [<folder_paths...>] [<arguments>]');
    stdout.writeln();
    stdout.writeln('--log finer will display all path');
    stdout.writeln('--log finest will display all path and command executed');
    stdout.writeln();
    stdout.writeln('Global options:');
    stdout.writeln(parser.usage);
    return;
  }

  var level = parseLogLevel((_argsResult[_logOption] as String?) ?? '');
  if (_argsResult[verboseFlag] as bool) {
    level = Level.FINEST;
  }

  final commandVerbose = level <= Level.FINEST;

  if (_argsResult['version'] as bool) {
    stdout.write('$currentScriptName $version');
    return;
  }
  /*
  String logLevel = _argsResult[_LOG];
  if (logLevel != null) {
    setupQuickLogging(parseLogLevel(logLevel));
  }
  log = new Logger('rscstatus');
  log.fine('Log level ${Logger.root.level}');
  */

  // get dirs in parameters, default to current
  var dirs = _argsResult.rest;
  if (dirs.isEmpty) {
    dirs = [Directory.current.path];
  }

  final futures = <Future>[];

  Future _handleDir(String dir) async {
    if (await isGitPathAndSupported(dir)) {
      final prj = GitPath(dir);

      final statusResult = await (prj.status());

      final buf = StdBuf();
      if (level <= Level.FINER) {
        buf.outAppend('--- git $prj');
      }
      if (level <= Level.FINEST) {
        buf.outAppend('> ${statusResult.cmd}');
        buf.appendResult(statusResult.runResult);
      }
      if (statusResult.branchIsAhead || !statusResult.nothingToCommit) {
        // already done
        if (level > Level.FINER) {
          buf.outAppend('--- git $prj');
        }
        if (statusResult.branchIsAhead) {
          buf.outAppend('Branch is ahead');
        }
        //stdout.writeln(statusResult.runResult.stdout);
        // rerun in short version mode
        final cmd = prj.statusCmd(short: true);
        if (level <= Level.FINEST) {
          buf.outAppend('> $cmd');
        }
        final result = await runCmd(cmd, commandVerbose: commandVerbose);
        buf.appendResult(result);
      }
      buf.print();
    } else if (await isHgPathAndSupported(dir)) {
      final prj = HgPath(dir);

      final buf = StdBuf();
      final statusResult = await (prj.status());
      if (level <= Level.FINEST) {
        buf.outAppend('--- hg $prj');
        buf.outAppend('> ${statusResult.cmd}');
        buf.appendResult(statusResult.runResult);
      }
      if (statusResult.nothingToCommit) {
        final outgoingResult = await (prj.outgoing());
        if (level <= Level.FINEST) {
          buf.outAppend('> ${outgoingResult.cmd}');
        }
        if (outgoingResult.branchIsAhead) {
          buf.outAppend('--- hg $prj');
          buf.outAppend('Branch is ahead');
          buf.appendResult(outgoingResult.runResult);
        }
      } else {
        buf.outAppend('--- hg $prj');
        buf.appendResult(statusResult.runResult);
      }
      buf.print();
    }
  }

  for (final dir in dirs) {
    print(dir);
    var _handle = handleScPath(dir, _handleDir, recursive: true);

    futures.add(_handle);
  }

  await Future.wait(futures);
}
