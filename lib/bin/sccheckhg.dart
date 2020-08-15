import 'dart:async';

import 'package:tekartik_sc/hg.dart';

Future main() async {
  print('Hg supported: ${await checkHgSupported(verbose: true)}');
}
