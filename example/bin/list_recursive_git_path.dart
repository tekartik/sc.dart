import 'dart:io';

import 'package:args/args.dart';
import 'package:tekartik_sc/git.dart';

const _ignoreMainFlag = 'ignore-main';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag(
      _ignoreMainFlag,
      abbr: 'i',
      help: 'Skip a repository whose current branch is main or master',
      negatable: false,
    );
  final argResults = parser.parse(arguments);
  var ignoreMain = argResults[_ignoreMainFlag] as bool;

  await recursiveGitRun(
    ['.'],
    action: (path) async {
      var currentBranch = await GitPath(path).getCurrentBranch();
      if (ignoreMain &&
          (currentBranch == 'main' || currentBranch == 'master')) {
        return;
      }
      stdout.writeln('path: $path');
      stdout.writeln('  branch: $currentBranch');
    },
  );
}
