import 'dart:io';

import 'package:args/args.dart';
// ignore: implementation_imports
import 'package:dev_build/src/io/run_ci.dart' as run_ci;
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'package:tekartik_sc/src/scpath.dart';

const String _helpFlag = 'help';
const String _versionFlag = 'version';
const String _verboseFlag = 'verbose';
const String _keepFlag = 'keep';
const String _branchOption = 'branch';
const String _depthOption = 'depth';

/// Current script name.
String get currentScriptName => basenameWithoutExtension(Platform.script.path);

/// Options handled by scrunci itself, everything else is forwarded to run_ci.
final _scrunciFlags = <String>{
  '-h',
  '--$_helpFlag',
  '--$_versionFlag',
  '--$_keepFlag',
};
final _scrunciOptions = <String>{'-b', '--$_branchOption', '--$_depthOption'};

/// Split the arguments between scrunci arguments and run_ci arguments.
///
/// run_ci arguments are the unknown options and the rest arguments
/// but the first one (the url).
({List<String> scrunciArgs, List<String> runCiArgs}) _splitArguments(
  List<String> arguments,
) {
  final scrunciArgs = <String>[];
  final runCiArgs = <String>[];
  var i = 0;
  while (i < arguments.length) {
    final arg = arguments[i++];
    if (_scrunciFlags.contains(arg)) {
      scrunciArgs.add(arg);
    } else if (_scrunciOptions.contains(arg)) {
      scrunciArgs.add(arg);
      if (i < arguments.length) {
        scrunciArgs.add(arguments[i++]);
      }
    } else if (_scrunciOptions.any((option) => arg.startsWith('$option='))) {
      scrunciArgs.add(arg);
    } else if (arg == '-v' || arg == '--$_verboseFlag') {
      // Verbose applies to both
      scrunciArgs.add(arg);
      runCiArgs.add(arg);
    } else if (arg.startsWith('-')) {
      runCiArgs.add(arg);
    } else {
      // Positional argument (url first, then sub paths)
      scrunciArgs.add(arg);
    }
  }
  return (scrunciArgs: scrunciArgs, runCiArgs: runCiArgs);
}

/// Clone a git repository in a temp folder and run dev_build run_ci on it.
Future main(List<String> arguments) async {
  final parser = ArgParser(allowTrailingOptions: true);
  parser.addFlag(_helpFlag, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addFlag(
    _versionFlag,
    help: 'Display the script version',
    negatable: false,
  );
  parser.addFlag(
    _verboseFlag,
    abbr: 'v',
    help: 'Verbose output (also forwarded to run_ci)',
    negatable: false,
  );
  parser.addFlag(
    _keepFlag,
    help: 'Keep the temp folder (always kept on failure)',
    negatable: false,
  );
  parser.addOption(_depthOption, help: 'depth (git --depth 1)');
  parser.addOption(
    _branchOption,
    abbr: 'b',
    help: 'branch (git clone -b <branch>)',
  );

  final split = _splitArguments(arguments);
  final argResults = parser.parse(split.scrunciArgs);
  final runCiArgs = split.runCiArgs;

  final help = argResults[_helpFlag] as bool;
  final verbose = argResults[_verboseFlag] as bool;
  final keep = argResults[_keepFlag] as bool;
  final branch = argResults[_branchOption] as String?;
  final depth = parseInt(argResults[_depthOption]);

  void printUsage() {
    stdout.writeln(
      'clone a git project by its url in a temp folder and run dev_build run_ci on it',
    );
    stdout.writeln();
    stdout.writeln(
      'Usage: $currentScriptName <source_control_uri> [<sub_paths...>] [<arguments>] [<run_ci arguments>]',
    );
    stdout.writeln();
    stdout.writeln(
      'Example: $currentScriptName https://github.com/tekartik/sc.dart --no-test',
    );
    stdout.writeln(
      'Example: $currentScriptName https://github.com/tekartik/app_build.dart packages/common_build',
    );
    stdout.writeln();
    stdout.writeln('Global options:');
    stdout.writeln(parser.usage);
    stdout.writeln();
    stdout.writeln(
      'Any other option is forwarded to run_ci (run_ci --help for the list)',
    );
  }

  if (help) {
    printUsage();
    return;
  }

  if (argResults[_versionFlag] as bool) {
    stdout.writeln('$currentScriptName $version');
    return;
  }

  final rest = argResults.rest;
  if (rest.isEmpty) {
    printUsage();
    exit(1);
  }
  final uri = rest.first;
  final subPaths = rest.sublist(1);

  final tempDir = await Directory.systemTemp.createTemp('scrunci_');
  final path = join(tempDir.path, joinAll(scUriToPathParts(uri)));
  var success = false;
  try {
    final prj = GitProject(uri, path: path);
    final cmd = prj.cloneCmd(depth: depth, branch: branch);
    stdout.writeln('> $cmd');
    final result = await runCmd(cmd, verbose: true);
    if (result.exitCode != 0) {
      throw StateError('git clone failed (${result.exitCode})');
    }

    final paths = subPaths.isEmpty
        ? [path]
        : subPaths.map((subPath) => join(path, subPath)).toList();
    final args = [...paths, ...runCiArgs];
    if (verbose) {
      stdout.writeln('> run_ci ${args.join(' ')}');
    }
    await run_ci.runCiMain(args);
    success = true;
  } finally {
    if (success && !keep) {
      await tempDir.delete(recursive: true);
    } else {
      stdout.writeln('temp folder kept: ${tempDir.path}');
    }
  }
}
