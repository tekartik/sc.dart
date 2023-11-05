import 'package:tekartik_sc/git.dart';

Future<void> main() async {
  await recursiveGitRun(['.'], action: (path) {
    print('path: $path');
  });
}
