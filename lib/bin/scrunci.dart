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
import 'package:tekartik_sc/src/scrunci_args.dart';

/// Current script name.
String get currentScriptName => basenameWithoutExtension(Platform.script.path);

/// Clone a git repository in a temp folder and run dev_build run_ci on it.
Future main(List<String> arguments) async {
  final parser = ArgParser(allowTrailingOptions: true);
  parser.addFlag(
    scrunciHelpFlag,
    abbr: 'h',
    help: 'Usage help',
    negatable: false,
  );
  parser.addFlag(
    scrunciVersionFlag,
    help: 'Display the script version',
    negatable: false,
  );
  parser.addFlag(
    scrunciVerboseFlag,
    abbr: 'v',
    help: 'Verbose output (also forwarded to run_ci)',
    negatable: false,
  );
  parser.addFlag(
    scrunciKeepFlag,
    help: 'Keep the temp folder (always kept on failure)',
    negatable: false,
  );
  parser.addOption(scrunciDepthOption, help: 'depth (git --depth 1)');
  parser.addOption(
    scrunciBranchOption,
    abbr: 'b',
    help: 'branch (git clone -b <branch>)',
  );

  final split = scrunciSplitArguments(arguments);
  final argResults = parser.parse(split.scrunciArgs);
  final runCiArgs = split.runCiArgs;

  final help = argResults[scrunciHelpFlag] as bool;
  final verbose = argResults[scrunciVerboseFlag] as bool;
  final keep = argResults[scrunciKeepFlag] as bool;
  final branch = argResults[scrunciBranchOption] as String?;
  final depth = parseInt(argResults[scrunciDepthOption]);

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

  if (argResults[scrunciVersionFlag] as bool) {
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
