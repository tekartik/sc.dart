#!/usr/bin/env dart
library tekartik_sc.bin.scpull;

// Pull recursively

import 'package:args/args.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_io_utils/io_utils_import.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/sc.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'package:tekartik_sc/src/scpath.dart';

const String _HELP = 'help';
//const String _LOG = 'log';
const String _DRY_RUN = 'dry-run';
const String verboseFlag = "verbose";

String get currentScriptName => basenameWithoutExtension(Platform.script.path);

class App {
  int projectCount = 0;

  void outSummary() {
    stdout.writeln('[$projectCount] project(s) updated');
  }
}

App app;

///
/// Recursively update (pull) git folders
///
///
main(List<String> arguments) async {
  app = App();
  //Logger log;
  //setupQuickLogging();

  ArgParser parser = ArgParser(allowTrailingOptions: true);
  parser.addFlag(_HELP, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addFlag(verboseFlag,
      abbr: 'v', help: 'Verbose output', negatable: false);
  parser.addFlag("version",
      help: 'Display the script version', negatable: false);
  //parser.addOption(_LOG, abbr: 'l', help: 'Log level (fine, debug, info...)');
  parser.addFlag(_DRY_RUN,
      abbr: 'n',
      help: 'Do not run test, simple show packages to be tested',
      negatable: false);

  ArgResults _argsResult = parser.parse(arguments);

  bool help = _argsResult[_HELP] as bool;
  if (help) {
    stdout.writeln(
        'Pull(update) from source control recursively (default from current directory)');
    stdout.writeln();
    stdout.writeln(
        'Usage: ${currentScriptName} [<folder_paths...>] [<arguments>]');
    stdout.writeln();
    stdout.writeln("Global options:");
    stdout.writeln(parser.usage);
    return;
  }
  bool dryRun = _argsResult[_DRY_RUN] as bool;
  bool verbose = _argsResult[verboseFlag] as bool;

  if (_argsResult['version'] as bool) {
    stdout.write('${currentScriptName} ${version}');
    return;
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
  List<String> dirs = _argsResult.rest;
  if (dirs.isEmpty) {
    dirs = [Directory.current.path];
  }

  List<Future> futures = [];

  Future _handleDir(String dir) async {
    Future<ProcessResult> _execute(ProcessCmd cmd) async {
      if (dryRun == true) {
        stdout.writeln(cmd);
        return null;
      } else {
        //int waitCount = 0;
        if (verbose) {
          stdout.writeln('[${cmd.workingDirectory}]');
        }
        ProcessResult result;
        _waiter() async {
          await sleep(15000);
          if (result == null) {
            stderr.writeln('[${cmd.workingDirectory}]...');
            _waiter();
          }
        }

        _waiter();
        result = await runCmd(cmd, verbose: verbose);
        return result;
      }
    }

    // Ignore folder starting with .
    // don't event go below
    if (await isGitPathAndSupported(dir)) {
      GitPath prj = GitPath(dir);
      //ProcessResult result =
      await _execute(prj.pullCmd());
    } else if (await isHgPathAndSupported(dir)) {
      HgPath prj = HgPath(dir);
      //ProcessResult result =
      await _execute(prj.pullCmd());
    }
  }

  for (String dir in dirs) {
    print(dir);
    var _handle = handleScPath(dir, _handleDir, recursive: true);
    if (_handle is Future) {
      futures.add(_handle);
    }
  }

  await futures;

  app.outSummary();
}
