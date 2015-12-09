#!/usr/bin/env dart
library tekartik_sc.scstatus;

// Pull recursively

import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/src/bin_version.dart';
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
  //parser.addOption(_LOG, abbr: 'l', help: 'Log level (fine, debug, info...)');

  ArgResults _argsResult = parser.parse(arguments);

  bool help = _argsResult[_HELP];
  if (help) {
    stdout.writeln(
        'Display source control status recursively (default from current directory)');
    stdout.writeln();
    stdout.writeln(
        'Usage: ${currentScriptName} [<folder_paths...>] [<arguments>]');
    stdout.writeln();
    stdout.writeln("Global options:");
    stdout.writeln(parser.usage);
    return;
  }

  if (_argsResult['version']) {
    stdout.write('${currentScriptName} ${version}');
    return;
  }
  /*
  String logLevel = _argsResult[_LOG];
  if (logLevel != null) {
    setupQuickLogging(parseLogLevel(logLevel));
  }
  log = new Logger("rscstatus");
  log.fine('Log level ${Logger.root.level}');
  */

  // get dirs in parameters, default to current
  List<String> dirs = _argsResult.rest;
  if (dirs.isEmpty) {
    dirs = [Directory.current.path];
  }

  List<Future> futures = [];

  Future _handleDir(String dir) async {
    if (await FileSystemEntity.isDirectory(dir)) {
      if (await isGitTopLevelPath(dir)) {
        GitPath prj = new GitPath(dir);
        GitStatusResult statusResult = await (prj.status());
        if (statusResult.branchIsAhead ||
            statusResult.nothingToCommit != true) {
          stdout.writeln('--- git');
          stdout.writeln(prj);
          stdout.writeln(statusResult.runResult.stdout);
        }
      } else if (await isHgTopLevelPath(dir)) {
        HgPath prj = new HgPath(dir);
        HgStatusResult statusResult =
            await (prj.status(printResultIfChanges: true));
        if (statusResult.nothingToCommit) {
          HgOutgoingResult outgoingResult = await (prj.outgoing());
          if (outgoingResult.branchIsAhead) {
            stdout.writeln('--- hg');
            stdout.writeln(prj);
            stdout.writeln(statusResult.runResult.stdout);
          }
        } else {
          stdout.writeln('--- hg');
          stdout.writeln(prj);
          stdout.writeln(statusResult.runResult.stdout);
        }
      } else {
        try {
          List<Future> sub = [];
          await new Directory(dir).list().listen((FileSystemEntity fse) {
            sub.add(_handleDir(fse.path));
          }).asFuture();
          await Future.wait(sub);
        } catch (_, __) {
          // log.fine(e.toString(), e, st);
        }
      }
    }
    /*
    // this is a directoru
    String dotGit = ".git";
    return (FileSystemEntity.isDirectory(dir)).then((bool isDir) {
      //print("dir $dir: ${isDir}");
      if (isDir) {
        String gitFile = join(dir, dotGit);
        return FileSystemEntity.isDirectory(gitFile).then((bool containsDotGit) {
          //print("gitFile $gitFile: ${containsDotGit}");
          if (containsDotGit) {
            gitPull(dir);
            print("git folder: ${dir}");
          } else {
            List<Future> sub = [];

            return new Directory(dir).list().listen((FileSystemEntity fse) {
              sub.add(_handleDir(fse.path));
            }).asFuture().then((_) {
              Future.wait(sub);
            });
          }
        });
      }
    });
    */
  }
  for (String dir in dirs) {
    print(dir);
    var _handle = _handleDir(dir);
    if (_handle is Future) {
      futures.add(_handle);
    }
  }
}
