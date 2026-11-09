// ignore_for_file: avoid_print

import 'package:tekartik_sc/git.dart';

/// Prints the branches of the git checkout of the current folder.
Future<void> main() async {
  var gitPath = GitPath('.');
  // Throws a StateError on a detached HEAD
  var branch = await gitPath.getCurrentBranch();
  print('Current branch: $branch');
  var branches = await gitPath.getBranches();
  print('Local branches: $branches');
  branches = await gitPath.getBranches(remote: true);
  print('Remote branches: $branches');
  var status = await gitPath.status();
  print(
    'Clean: ${status.nothingToCommit}, unpushed commits: ${status.branchIsAhead}',
  );
}
