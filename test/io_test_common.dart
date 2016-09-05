library tekartik_io_tools.io_common;

import 'package:path/path.dart';
import 'dart:io';
import 'package:dev_test/test.dart';
import 'package:tekartik_pub/script.dart';
export 'package:dev_test/test.dart';

// This script resolver
class TestScript extends Script {}

// Test directory
String get testDirPath => dirname(getScriptPath(TestScript));

String get outDataPath => getOutTestPath(testDescriptions);

String getOutTestPath([List<String> parts]) {
  if (parts == null) {
    parts = testDescriptions;
  }
  return join(testDirPath, "out", joinAll(parts));
}

String clearOutTestPath([List<String> parts]) {
  String outPath = getOutTestPath(parts);
  try {
    new Directory(outPath).deleteSync(recursive: true);
  } catch (e) {}
  try {
    new Directory(outPath).createSync(recursive: true);
  } catch (e) {}
  return outPath;
}
