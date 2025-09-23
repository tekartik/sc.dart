import 'dart:io';

import 'package:tekartik_sc/git.dart';

Future<void> main() async {
  await recursiveGitRun(
    ['.'],
    action: (path) async {
      var currentBranch = await GitPath(path).getCurrentBranch();
      stdout.writeln('path: $path');
      stdout.writeln('  branch: $currentBranch');
    },
  );
}
