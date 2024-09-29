@TestOn('vm')
library;

import 'package:dev_test/test.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_sc/hg.dart';

import 'bin_test.dart';
import 'io_dev_test_common.dart';

String get sccheckhgDartScript {
  return join(exampleBinPath, 'sccheckhg.dart');
}

void main() {
  //useVMConfiguration();
  group('sccheckhg', () {
    test('run', () async {
      if (await isHgSupported) {
        await runCmd(DartCmd([sccheckhgDartScript]));
      }
    });
  });
}
