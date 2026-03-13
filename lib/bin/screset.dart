import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/sc.dart';
import 'package:tekartik_sc/src/bin_version.dart';

const String _helpFlag = 'help';

/// Current script name.
String get currentScriptName => basenameWithoutExtension(Platform.script.path);

///
/// Recursively update (pull) git folders
///
///
void main(List<String> arguments) {
  //setupQuickLogging();

  final parser = ArgParser(allowTrailingOptions: true);
  parser.addFlag(_helpFlag, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addFlag(
    'version',
    help: 'Display the script version',
    negatable: false,
  );
  parser.addFlag('recursive', abbr: 'r', help: 'Recursive', negatable: false);
  parser.addFlag(
    'dry-run',
    abbr: 'n',
    help: 'Do not run test, simple show packages to be tested',
    negatable: false,
  );
  parser.addFlag(
    'verbose',
    abbr: 'v',
    help: 'Verbose output',
    negatable: false,
  );
  //parser.addOption(_LOG, abbr: 'l', help: 'Log level (fine, debug, info...)');

  final argResults = parser.parse(arguments);

  final help = argResults.flag(_helpFlag);
  if (help) {
    stdout.writeln('Revert files in the given directories');
    stdout.writeln();
    stdout.writeln('Usage: $currentScriptName <folder_paths...> [<arguments>]');
    stdout.writeln();
    stdout.writeln('Global options:');
    stdout.writeln(parser.usage);
    return;
  }

  if (argResults.flag('version')) {
    stdout.write('$currentScriptName $version');
    return;
  }

  final dryRun = argResults.flag('dry-run');
  final recursive = argResults.flag('recursive');
  final verbose = argResults.flag('verbose');

  // get dirs in parameters, default to current
  final dirOrFiles = argResults.rest;
  if (dirOrFiles.isEmpty) {
    stderr.writeln(
      'you must specify a directory. Example: $currentScriptName .',
    );
    exit(1);
  }

  final futures = <Future>[];

  Future handleDir(String dirOrFile) async {
    // Get top level
    dirOrFile = absolute(dirOrFile);
    final scTopPath = await findScTopLevelPath(dirOrFile);
    if (scTopPath == null) {
      stderr.writeln('$dirOrFile does not belong to source control');
    } else {
      if (await isGitTopLevelPath(scTopPath)) {
        if (await isGitSupported) {
          final prj = GitPath(scTopPath);
          var status = await prj.status(verbose: verbose);
          if (!status.nothingToCommit) {
            stderr.writeln('Revert current changes first (run screvert .)');
            return;
          } else {
            await prj.resetToOrigin(verbose: true, dryRun: dryRun);
          }
        } else if (await isHgTopLevelPath(scTopPath)) {
          stdout.writeln('hg (mercurial) not supported yet');
        }
      }
    }
  }

  Future handleDirRecursively(String dirOrFile) async {
    await recursiveGitRun(
      [dirOrFile],
      action: (path) async {
        await handleDir(path);
      },
    );
  }

  for (final dirOrFile in dirOrFiles) {
    var handle = recursive
        ? handleDirRecursively(dirOrFile)
        : handleDir(dirOrFile);

    futures.add(handle);
  }
}
