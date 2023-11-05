import 'package:tekartik_sc/git.dart';

Future<void> main() async {
  await recursiveGitRun(['.'], action: (path) async {
    var currentBranch = await GitPath(path).getCurrentBranch();
    print('path: $path');
    print('  branch: $currentBranch');
  });
}
