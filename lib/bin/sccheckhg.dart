#!/usr/bin/env dart
library tekartik_sc.bin.sccheckhg;

import 'package:tekartik_sc/hg.dart';

main() async {
  print('Hg supported: ${await checkHgSupported(verbose: true)}');
}
