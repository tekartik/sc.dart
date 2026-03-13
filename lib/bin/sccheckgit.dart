import 'dart:async';

import 'package:process_run/cmd_run.dart';
import 'package:process_run/stdio.dart';
import 'package:tekartik_sc/git.dart';

Future main() async {
  stdout.writeln('Git supported: ${await checkGitSupported(verbose: true)}');
  stdout.writeln(
    '${await runCmd(ProcessCmd('which', ['git']), verbose: true)}',
  );
  stdout.writeln(
    '${await runCmd(ProcessCmd('git', ['--version'], runInShell: true), verbose: true)}',
  );
}
