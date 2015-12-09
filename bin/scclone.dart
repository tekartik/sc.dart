#!/usr/bin/env dart
library tekartik_io_tools.scclone;

// Pull recursively

import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/src/scpath.dart';
import 'package:path/path.dart';
import 'package:tekartik_sc/src/bin_version.dart';

const String _HELP = 'help';
const String _DRY_RUN = 'dry-run';

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
  ArgResults _argsResult = parser.parse(arguments);

  bool help = _argsResult[_HELP];

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

  if (_argsResult['version']) {
    stdout.writeln('${currentScriptName} ${version}');
    return;
  }

  bool dryRun = _argsResult[_DRY_RUN];

  // get uris in parameters, default to current
  List<String> uris = _argsResult.rest;
  if (uris.isEmpty) {
    _printUsage();
  }

  Future _handleUri(String uri) async {
    List<String> parts = scUriToPathParts(uri);

    String topDirName = basename(Directory.current.path);

    bool done = false;
    _tryGit(uri, parts) async {
      // try git first
      if ((!done) && await isGitSupported && await isGitRepository(uri)) {
        done = true;
        // Check if remote is a git repository
        List<String> gitParts = new List.from(parts);
        if (topDirName != "git") {
          gitParts.insert(0, "git");
        }
        String path = absolute(joinAll(gitParts));
        if (await isGitTopLevelPath(path)) {
          stdout.writeln("git: ${path} already exists");
        } else {
          GitProject prj = new GitProject(uri, path: path);
          if (dryRun) {
            print("git clone ${prj.src} ${prj.path}");
          } else {
            await runCmd(prj.cloneCmd()
              ..connectStderr = true
              ..connectStdout = true);
          }
        }
      }
    }

    // try remove .git
    if (uri.endsWith(".git")) {
      String newUri = uri.substring(0, uri.length - 4);
      await _tryGit(newUri, scUriToPathParts(newUri));
    }
    await _tryGit(uri, parts);

    if ((!done) && await isHgSupported && await isHgRepository(uri)) {
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
          await runCmd(prj.cloneCmd()
            ..connectStderr = true
            ..connectStdout = true);
        }
      }
    }
  }

  // handle all uris
  for (String uri in uris) {
    await _handleUri(uri);
  }
}
