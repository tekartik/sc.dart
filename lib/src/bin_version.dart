library;

import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';

/// The current version of the bin tool.
Version version = Version(0, 8, 1);

/// The script name from its path, `scinfo` for `scinfo.dart`, a compiled
/// `scinfo` or `scinfo.exe`, or a snapshot `scinfo.dart-3.13.5.snapshot` (pub
/// global activate) or `scinfo.dart.snapshot`.
String scriptPathGetName(String scriptPath) {
  var name = basename(scriptPath);
  var match = RegExp(r'^(.+?)\.dart(-.*|\.snapshot)?$').firstMatch(name);
  return match?.group(1) ?? basenameWithoutExtension(name);
}
