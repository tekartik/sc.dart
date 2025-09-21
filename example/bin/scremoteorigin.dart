import 'package:process_run/stdio.dart';
import 'package:tekartik_sc/git.dart';

Future<void> main(List<String> args) async {
  var gitPath = GitPath('.');
  var url = await gitPath.getRemoteOriginUrl();
  stdout.writeln(url);
}
