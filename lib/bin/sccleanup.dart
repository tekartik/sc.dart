import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'package:tekartik_sc/src/scpath.dart';
import 'package:tekartik_sc/src/std_buf.dart';

const String _helpFlag = 'help';
const String _dryRunFlag = 'dry-run';

/// Verbose flag.
const String verboseFlag = 'verbose';

/// Timeout option.
const String timeoutOption = 'timeout';

/// Current script name.
String get currentScriptName => basenameWithoutExtension(Platform.script.path);

/// Recursively update (pull) git folders
Future main(List<String> arguments) async {
  //Logger log;
  //setupQuickLogging();

  final parser = ArgParser(allowTrailingOptions: true);
  parser.addFlag(_helpFlag, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addFlag(
    'version',
    help: 'Display the script version',
    negatable: false,
  );
  parser.addFlag(
    verboseFlag,
    abbr: 'v',
    help: 'Verbose output',
    negatable: false,
  );

  parser.addOption(
    timeoutOption,
    abbr: 't',
    help: 'Timeout for each operation in milliseconds',
  );
  parser.addFlag(
    _dryRunFlag,
    abbr: 'n',
    help: 'Do not run test, simple show packages to be tested',
    negatable: false,
  );

  final argResults = parser.parse(arguments);

  final help = argResults[_helpFlag] as bool;
  if (help) {
    stdout.writeln(
      'Clean local (remote deleted) recursively (default from current directory)',
    );
    stdout.writeln();
    stdout.writeln(
      'Usage: $currentScriptName [<folder_paths...>] [<arguments>]',
    );
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

  // get dirs in parameters, default to current
  var dirs = argResults.rest;
  if (dirs.isEmpty) {
    dirs = [Directory.current.path];
  }

  final futures = <Future>[];

  Future handleDir(String dir) async {
    Future<ProcessResult?> execute(
      StdBuf buf,
      ProcessCmd cmd, {
      bool forceVerbose = false,
    }) async {
      if (dryRun) {
        stdout.writeln(cmd);
        return null;
      } else {
        final result = await runCmd(cmd);
        if (verbose || forceVerbose) {
          buf.appendCmdResult(cmd, result);
        }
        return result;
      }
    }

    if (await isGitPathAndScSupported(dir)) {
      final buf = StdBuf();
      final prj = GitPath(dir);

      await execute(buf, prj.cmd(['fetch', '--prune']), forceVerbose: true);
      var branchesResult = await prj.branches(verbose: verbose);
      for (var branch in branchesResult.branches) {
        if (verbose) {
          buf.outAppend('branch $branch');
        }
        if (branch.gone) {
          await execute(
            buf,
            prj.cmd(['branch', '-D', branch.name]),
            forceVerbose: true,
          );
        }
      }

      buf.print('--- git $prj');
    }
  }

  Future handleDirWithTimeout(String dir) async {
    if (timeout != null) {
      await handleDir(dir).timeout(Duration(milliseconds: timeout)).catchError((
        Object e,
      ) {
        stderr.writeln('$e for $dir');
      });
    } else {
      await handleDir(dir);
    }
  }

  for (final dir in dirs) {
    stdout.writeln(dir);
    var handle = handleScPath(dir, handleDirWithTimeout, recursive: true);
    futures.add(handle);
  }

  await Future.wait(futures);
}
