@TestOn('vm')
library tekartik_sc.test.bin_sccheckhg_test;

import 'package:dev_test/test.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_pub/io.dart';
import 'package:tekartik_sc/hg.dart';

import 'io_test_common.dart';

String get _pubPackageRoot => normalize(absolute('.'));

String get sccheckhgDartScript {
  final pkg = PubPackage(_pubPackageRoot);
  return join(pkg.path, 'bin', 'sccheckhg.dart');
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
