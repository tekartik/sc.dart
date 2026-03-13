import 'dart:async';

import 'package:process_run/stdio.dart';
import 'package:tekartik_sc/hg.dart';

Future main() async {
  stdout.writeln('Hg supported: ${await checkHgSupported(verbose: true)}');
}
