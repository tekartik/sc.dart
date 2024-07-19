import 'package:tekartik_sc/git.dart';

Future<void> main() async {
  var project = GitProject('.');
  var branch = await project.getCurrentBranch();
  print('Current branch: $branch');
  var branches = await project.getBranches();
  print('Local branches: $branches');
  branches = await project.getBranches(remote: true);
  print('Remote branches: $branches');
}
