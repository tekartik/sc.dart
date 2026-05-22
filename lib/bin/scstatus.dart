import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_common_utils/log_utils.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'package:tekartik_sc/src/scpath.dart';
import 'package:tekartik_sc/src/std_buf.dart';

const String _helpFlag = 'help';
const String _logOption = 'log';

/// Verbose flag.
const String verboseFlag = 'verbose';

/// Modified files flag.
const String modifiedFilesFlag = 'modified';

/// Current script name.
String get currentScriptName => basenameWithoutExtension(Platform.script.path);

Future<void> main(List<String> arguments) async {
  await scStatusMain(arguments);
}

///
/// Recursively update (pull) git folders
///
///
Future<void> scStatusMain(List<String> arguments) async {
  //setupQuickLogging();

  final parser = ArgParser(allowTrailingOptions: true);
  parser.addFlag(_helpFlag, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addFlag(
    'version',
    help: 'Display the script version',
    negatable: false,
  );
  parser.addFlag(verboseFlag, abbr: 'v', help: 'Verbose', negatable: false);
  parser.addFlag(
    modifiedFilesFlag,
    abbr: 'm',
    help: 'Modified files only',
    negatable: false,
  );
  parser.addOption(
    _logOption,
    abbr: 'l',
    help: 'Log level (finest, finer, fine, debug, info...)',
  );

  final argResults = parser.parse(arguments);

  final help = argResults[_helpFlag] as bool;
  if (help) {
    stdout.writeln(
      'Display source control status recursively (default from current directory)',
    );
    stdout.writeln();
    stdout.writeln(
      'Usage: $currentScriptName [<folder_paths...>] [<arguments>]',
    );
    stdout.writeln();
    stdout.writeln('--log finer will display all path');
    stdout.writeln('--log finest will display all path and command executed');
    stdout.writeln();
    stdout.writeln('Global options:');
    stdout.writeln(parser.usage);
    return;
  }

  var modifiedFilesOnly = argResults[modifiedFilesFlag] as bool;
  var level = parseLogLevel((argResults[_logOption] as String?) ?? '');
  if (argResults[verboseFlag] as bool) {
    level = Level.FINEST;
  }

  final commandVerbose = level <= Level.FINEST;

  if (argResults['version'] as bool) {
    stdout.write('$currentScriptName $version');
    return;
  }
  /*
  String logLevel = argResults[_LOG];
  if (logLevel != null) {
    setupQuickLogging(parseLogLevel(logLevel));
  }
  log = new Logger('rscstatus');
  log.fine('Log level ${Logger.root.level}');
  */

  // get dirs in parameters, default to current
  var dirs = argResults.rest;
  if (dirs.isEmpty) {
    dirs = [Directory.current.path];
  }

  final futures = <Future>[];

  Future handleDir(String dir) async {
    if (await isGitPathAndScSupported(dir)) {
      final prj = GitPath(dir);

      final statusResult = await (prj.status());

      final buf = StdBuf();
      var origin = await prj.getRemoteOriginUrl();
      var sb = StringBuffer();
      sb.write('Origin: $origin');
      if (await prj.isGithubRepo()) {
        if (await isGithubCliInstalled()) {
          final private = await prj.githubIsPrivate();
          sb.write(' (github: ${private ? 'private' : 'public'})');
        } else {
          sb.write(' (github)');
        }
      }
      buf.outAppend(sb);
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
        if (modifiedFilesOnly) {
          var shell = Shell(
            workingDirectory: prj.path,
            commandVerbose: commandVerbose,
            verbose: false,
          );
          var result = (await shell.run('git ls-files -m')).first;
          buf.appendResult(result);
        } else {
          //stdout.writeln(statusResult.runResult.stdout);
          // rerun in short version mode
          final cmd = prj.statusCmd(short: true);
          if (level <= Level.FINEST) {
            buf.outAppend('> $cmd');
          }
          final result = await runCmd(cmd, commandVerbose: commandVerbose);
          buf.appendResult(result);
        }
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
    stdout.writeln(dir);
    var handle = handleScPath(dir, handleDir, recursive: true);

    futures.add(handle);
  }

  await Future.wait(futures);
}
