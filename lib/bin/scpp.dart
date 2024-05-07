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

  final parser = ArgParser(allowTrailingOptions: true);
  parser.addFlag(_helpFlag, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addFlag('version',
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

  final argResults = parser.parse(arguments);

  final help = argResults[_helpFlag] as bool;
  if (help) {
    stdout.writeln(
        'Push & Pull(update) from source control recursively (default from current directory)');
    stdout.writeln();
    stdout
        .writeln('Usage: $currentScriptName [<folder_paths...>] [<arguments>]');
    stdout.writeln();
    stdout.writeln('Global options:');
    stdout.writeln(parser.usage);
    return;
  }
  final dryRun = argResults[_dryRunFlag] as bool;
  var timeout = int.tryParse((argResults[timeoutOption] as String?) ?? '');

  if (argResults['version'] as bool) {
    stdout.write('$currentScriptName $version');
    return;
  }

  final verbose = argResults[verboseFlag] as bool;
  var level = parseLogLevel((argResults[_logOption] as String?) ?? '');
  if (verbose) {
    level = Level.FINEST;
  }
  /*
  String logLevel = argResults[_LOG];
  if (logLevel != null) {
    setupQuickLogging(parseLogLevel(logLevel));
  }
  log = new Logger('rscpull');
  log.fine('Log level ${Logger.root.level}');
  */

  // get dirs in parameters, default to current
  var dirs = argResults.rest;
  if (dirs.isEmpty) {
    dirs = [Directory.current.path];
  }

  final futures = <Future>[];

  Future handleDir(String dir) async {
    Future<ProcessResult?> execute(StdBuf buf, ProcessCmd cmd) async {
      if (dryRun) {
        stdout.writeln(cmd);
        return null;
      } else {
        final result = await runCmd(cmd);
        if (level <= Level.FINEST) {
          buf.appendCmdResult(cmd, result);
        }
        return result;
      }
    }

    if (await isGitPathAndScSupported(dir)) {
      var skipRunCiFilePath = join(dir, '.local', '.skip_sc');
      if (File(skipRunCiFilePath).existsSync()) {
        stderr.write('Skipping $dir');
      }
      final buf = StdBuf();
      final prj = GitPath(dir);

      var statusResult = await prj.status();
      // Only push if branch is ahead
      if (statusResult.branchIsAhead) {
        final cmd = prj.pushCmd();
        final result = await execute(buf, cmd);
        // dry-run returns null
        if (result != null) {
          if (result.exitCode != 0 ||
              !result.stderr.toString().contains('up-to-date')) {
            buf.outAppend('> $cmd');
            buf.appendResult(result);
          }
        }
      } else {
        if (level <= Level.FINEST) {
          buf.outAppend('no push, branch is not ahead');
        }
      }
      var cmd = prj.pullCmd();
      var result = await execute(buf, cmd);
      // dry-run returns null
      if (result != null) {
        var pullOutput = result.stdout.toString();
        if (result.exitCode != 0 ||
            !(pullOutput.contains('up-to-date') ||
                pullOutput.contains('up to date'))) {
          buf.outAppend('> $cmd');
          buf.appendResult(result);
        }
      }

      buf.print('--- git $prj');
    } else if (await isHgPathAndSupported(dir)) {
      final buf = StdBuf();
      final prj = HgPath(dir);
      //ProcessResult result =
      var cmd = prj.pushCmd();
      var result = await (execute(buf, cmd) as FutureOr<ProcessResult>);
      // exitCode seems to be always 1 on linux...
      // result.exitCode != 0 ||
      if (!result.stdout.toString().contains('no changes found')) {
        buf.outAppend('> $cmd');
        buf.appendResult(result);
      }
      cmd = prj.pullCmd();
      result = await (execute(buf, cmd) as FutureOr<ProcessResult>);
      if (result.exitCode != 0 ||
          !result.stdout.toString().contains('no changes found')) {
        buf.outAppend('> $cmd');
        buf.appendResult(result);
      }
      buf.print('--- hg $prj');
    }
  }

  Future handleDirWithTimeout(String dir) async {
    if (timeout != null) {
      await handleDir(dir)
          .timeout(Duration(milliseconds: timeout))
          .catchError((Object e) {
        stderr.writeln('$e for $dir');
      });
    } else {
      await handleDir(dir);
    }
  }

  for (final dir in dirs) {
    print(dir);
    var handle = handleScPath(dir, handleDirWithTimeout, recursive: true);
    futures.add(handle);
  }

  await Future.wait(futures);
}
