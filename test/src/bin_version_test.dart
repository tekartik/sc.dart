@TestOn('vm')
library;

import 'package:dev_test/test.dart';
import 'package:tekartik_sc/src/bin_version.dart';

void main() => defineTests();

void defineTests() {
  test('scriptPathGetName', () {
    expect(scriptPathGetName('/a/example/bin/scinfo.dart'), 'scinfo');
    // pub global activate
    expect(
      scriptPathGetName(
        '/home/user/.pub-cache/global_packages/tekartik_script/bin/scinfo.dart-3.13.5.snapshot',
      ),
      'scinfo',
    );
    expect(scriptPathGetName('/a/scinfo.dart.snapshot'), 'scinfo');
    // compiled
    expect(scriptPathGetName('/a/scinfo'), 'scinfo');
    expect(scriptPathGetName('/a/scinfo.exe'), 'scinfo');
  });
}
