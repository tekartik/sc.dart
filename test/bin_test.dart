@TestOn('vm')
library tekartik_sc.test.bin_test;

import 'package:dev_test/test.dart';
import 'package:path/path.dart';

import 'io_dev_test_common.dart';

var exampleBinPath = join('example', 'bin');

String get pubTestDartScript {
  return join(exampleBinPath, 'pubtest.dart');
}

void main() {
  //useVMConfiguration();
  group('pubtest', () {
    test('src.version', () async {
      // expect(version, await extractPubspecYamlVersion(_pubPackageRoot));
    });
  });
}
