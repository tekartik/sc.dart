library tekartik_io_tools.io_common;

import 'dart:io';

import 'package:dev_test/test.dart';
import 'package:path/path.dart';
import 'package:tekartik_common_utils/bool_utils.dart';

export 'package:dev_test/test.dart';

String get outDataPath => getOutTestPath(testDescriptions);

String getOutTestPath([List<String>? parts]) {
  parts ??= testDescriptions;

  return join('.dart_tool', 'tekartik_sc', 'test', joinAll(parts));
}

String clearOutTestPath([List<String>? parts]) {
  final outPath = getOutTestPath(parts);
  try {
    Directory(outPath).deleteSync(recursive: true);
  } catch (_) {}
  try {
    Directory(outPath).createSync(recursive: true);
  } catch (_) {}
  return outPath;
}

bool get runningInTravis {
  return parseBool(Platform.environment['TRAVIS']) == true;
}
