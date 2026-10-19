import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'package:tekartik_sc/src/git_info.dart';
import 'package:tekartik_sc/src/scpath.dart';

const String _helpFlag = 'help';

/// Verbose flag.
const String verboseFlag = 'verbose';

/// Offline flag.
const String offlineFlag = 'offline';

/// Separator printed between two repositories.
const String scInfoSeparator = '###';

/// Current script name.
String get currentScriptName => scriptPathGetName(Platform.script.path);

Future<void> main(List<String> arguments) async {
  await scInfoMain(arguments);
}

/// Recursively display repository information.
Future<void> scInfoMain(List<String> arguments) async {
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
    help: 'Verbose output (show the commands run)',
    negatable: false,
  );
  parser.addFlag(
    offlineFlag,
    abbr: 'o',
    help: 'Do not query GitHub (visibility, archived...)',
    negatable: false,
  );

  final argResults = parser.parse(arguments);

  final help = argResults[_helpFlag] as bool;
  if (help) {
    stdout.writeln(
      'Display source control repository information recursively (default from current directory)',
    );
    stdout.writeln();
    stdout.writeln(
      'Usage: $currentScriptName [<folder_paths...>] [<arguments>]',
    );
    stdout.writeln();
    stdout.writeln(
      'GitHub information (visibility, archived, size...) requires the gh CLI.',
    );
    stdout.writeln();
    stdout.writeln('Global options:');
    stdout.writeln(parser.usage);
    return;
  }

  if (argResults['version'] as bool) {
    stdout.writeln('$currentScriptName $version');
    return;
  }

  final verbose = argResults[verboseFlag] as bool;
  final offline = argResults[offlineFlag] as bool;

  // get dirs in parameters, default to current
  var dirs = argResults.rest;
  if (dirs.isEmpty) {
    dirs = [Directory.current.path];
  }

  var repoCount = 0;
  void printRepo(List<String> lines) {
    if (repoCount++ > 0) {
      stdout.writeln(scInfoSeparator);
      stdout.writeln();
    }
    stdout.writeln(lines.join('\n'));
  }

  Future<void> handleDir(String dir) async {
    if (await isGitPathAndScSupported(dir)) {
      var info = await gitPathGetInfo(
        GitPath(dir),
        github: !offline,
        verbose: verbose,
      );
      printRepo(info.toLines());
    } else if (await isHgPathAndSupported(dir)) {
      printRepo(await hgPathGetInfoLines(dir, verbose: verbose));
    }
  }

  await Future.wait([
    for (final dir in dirs) handleScPath(dir, handleDir, recursive: true),
  ]);
}
