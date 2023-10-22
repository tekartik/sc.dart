import 'package:process_run/process_run.dart';
import 'package:tekartik_sc/git.dart';

extension GitPathExt on GitPath {
  Future<List<String>> getBranches() async {
    return (await runGit("branch --format='%(refname:short)'", verbose: true))
        .outLines
        .toList();
  }

  Future<String> getCurrentBranch() async {
    return (await runGit('branch --show-current', verbose: true))
        .outLines
        .first;
  }
}
