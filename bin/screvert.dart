#!/usr/bin/env dart
library tekartik_sc.bin.screvert;

// revert directories
import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/sc.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'package:process_run/cmd_run.dart';
import 'package:path/path.dart';

const String _HELP = 'help';

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
  parser.addFlag("dry-run",
      abbr: 'n',
      help: 'Do not run test, simple show packages to be tested',
      negatable: false);
  //parser.addOption(_LOG, abbr: 'l', help: 'Log level (fine, debug, info...)');

  ArgResults _argsResult = parser.parse(arguments);

  bool help = _argsResult[_HELP];
  if (help) {
    stdout.writeln(
        'Revert files in the given directories');
    stdout.writeln();
    stdout.writeln(
        'Usage: ${currentScriptName} <folder_paths...> [<arguments>]');
    stdout.writeln();
    stdout.writeln("Global options:");
    stdout.writeln(parser.usage);
    return;
  }

  if (_argsResult['version']) {
    stdout.write('${currentScriptName} ${version}');
    return;
  }

  bool dryRun = _argsResult["dry-run"];

  // get dirs in parameters, default to current
  List<String> dirOrFiles = _argsResult.rest;
  if (dirOrFiles.isEmpty) {
    stderr.writeln("you must specify a directory. Example: ${currentScriptName} .");
    exit(1);
  }

  List<Future> futures = [];

  Future _handleDir(String dirOrFile) async {
    // Get top level
    dirOrFile = absolute(dirOrFile);
    String scTopPath = await findScTopLevelPath(dirOrFile);
    if (scTopPath == null) {
      stderr.writeln('$dirOrFile does not belong to source control');
    } else {
      //print(dirOrFile);
      //print(dirOrFile);
      String rel = relative(dirOrFile, from: scTopPath);
      if (await isGitTopLevelPath(scTopPath)) {
        GitPath prj = new GitPath(scTopPath);
        ProcessCmd cmd = prj.checkoutCmd(path: rel);

        stdout.writeln(cmd);
        if (!dryRun) {
          await runCmd(cmd
            ..connectStderr = true
            ..connectStdout = true);
        }
        /*
        GitStatusResult statusResult = await (prj.status());
        if (statusResult.branchIsAhead ||
            statusResult.nothingToCommit != true) {
          stdout.writeln('--- git');
          stdout.writeln(prj);
          stdout.writeln(statusResult.runResult.stdout);
        }
        */
      } else if (await isHgTopLevelPath(scTopPath)) {
        HgPath prj = new HgPath(scTopPath);
        ProcessCmd cmd = prj.revertCmd(path: rel);

        stdout.writeln(cmd);
        if (!dryRun) {
          await runCmd(cmd
            ..connectStderr = true
            ..connectStdout = true);
        }
      }
    }



  }
  for (String dirOrFile in dirOrFiles) {
    var _handle = _handleDir(dirOrFile);
    if (_handle is Future) {
      futures.add(_handle);
    }
  }
}
