#!/usr/bin/env dart
library tekartik_io_tools.scclone;

// Pull recursively

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'package:tekartik_sc/src/scpath.dart';

const String _HELP = 'help';
const String _DRY_RUN = 'dry-run';
const String verboseFlag = "verbose";

String get currentScriptName => basenameWithoutExtension(Platform.script.path);

///
/// clone hg or git repository
///
main(List<String> arguments) async {
  //setupQuickLogging();

  ArgParser parser = new ArgParser(allowTrailingOptions: true);
  parser.addFlag(_HELP, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addFlag("version",
      help: 'Display the script version', negatable: false);
  parser.addFlag(_DRY_RUN,
      abbr: 'd',
      help: 'Do not clone, simple show the folders created',
      negatable: false);
  parser.addFlag(verboseFlag,
      abbr: 'v', help: 'Verbose output', negatable: false);
  ArgResults _argsResult = parser.parse(arguments);

  bool help = _argsResult[_HELP] as bool;
  bool verbose = _argsResult[verboseFlag] as bool;

  _printUsage() {
    stdout.writeln(
        'clone one or multiple projects by their url and create pre-defined directory structure');
    stdout.writeln();
    stdout.writeln(
        'Usage: ${currentScriptName} <source_control_uris...> [<arguments>]');
    stdout.writeln();
    stdout.writeln(
        'Example: ${currentScriptName} https://github.com/alextekartik/tekartik_io_tools.dart');
    stdout.writeln(
        'will clone the project into ./git/github.com/alextekartik/tekartik_io_tools.dart');
    stdout.writeln();
    stdout.writeln("Global options:");
    stdout.writeln(parser.usage);
  }

  if (help) {
    _printUsage();
    return;
  }

  if (_argsResult['version'] as bool) {
    stdout.writeln('${currentScriptName} ${version}');
    return;
  }

  bool dryRun = _argsResult[_DRY_RUN] as bool;

  // get uris in parameters, default to current
  List<String> uris = _argsResult.rest;
  if (uris.isEmpty) {
    _printUsage();
  }

  Future _handleUri(String uri) async {
    List<String> parts = scUriToPathParts(uri);

    String topDirName = basename(Directory.current.path);

    bool done = false;
    _tryGit(String uri, List<String> parts) async {
      // try git first
      if ((!done) &&
          await checkGitSupported(once: true, verbose: verbose) &&
          await isGitRepository(uri, verbose: verbose)) {
        done = true;
        // Check if remote is a git repository
        List<String> gitParts = new List.from(parts);
        if (topDirName != "git") {
          gitParts.insert(0, "git");
        }
        String path = absolute(joinAll(gitParts));
        if (await isGitTopLevelPath(path)) {
          stderr.writeln("git: ${path} already exists");
        } else {
          GitProject prj = new GitProject(uri, path: path);
          if (dryRun) {
            print("git clone ${prj.src} ${prj.path}");
          } else {
            ProcessCmd cmd = prj.cloneCmd();
            stdout.writeln('> $cmd');
            await runCmd(cmd, verbose: true);
          }
        }
      }
    }

    // try remove .git
    if (uri.endsWith(".git")) {
      String newUri = uri.substring(0, uri.length - 4);
      await _tryGit(newUri, scUriToPathParts(newUri));
    }

    if (!done) {
      await _tryGit(uri, parts);
    }

    if ((!done) &&
        await checkHgSupported(verbose: verbose) &&
        await isHgRepository(uri, verbose: verbose)) {
      done = true;

      // try hg then
      List<String> hgParts = new List.from(parts);
      if (topDirName != "hg") {
        hgParts.insert(0, "hg");
      }

      String path = absolute(joinAll(hgParts));
      if (await isHgTopLevelPath(path)) {
        stdout.writeln("hg: ${path} already exists");
      } else {
        HgProject prj = new HgProject(uri, path: path);
        if (dryRun) {
          print("hg clone ${prj.src} ${prj.path}");
        } else {
          ProcessCmd cmd = prj.cloneCmd();
          await runCmd(cmd, verbose: true);
        }
      }
    }

    if (!done) {
      stderr.writeln(
          "Could not find sc control for $uri. Try running with verbose mode on (-v) for more information");
    }
  }

  // handle all uris
  for (String uri in uris) {
    await _handleUri(uri);
  }
}
