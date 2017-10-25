library tekartik_io_tools.src.scpath;

import 'package:path/path.dart';

///
/// Convert a uri to a convenient path part
/// removing user information and scheme
List<String> scUriToPathParts(String uri) {
  List<String> parts;
  String domain;
  try {
    Uri _uri = Uri.parse(uri);
    parts = posix.split(_uri.path);
    domain = _uri.host;
  } on FormatException catch (_) {
    // ssh? something like git@github.com:tekartik/sc.dart.git
    // find first part (before :)
    List<String> domainParts = uri.split(":");
    domain = domainParts[0];
    parts = posix.split(domainParts[1]);
  }

  // remove root if any
  if (parts[0] == '/') {
    parts = parts.sublist(1);
  }
  // remove user information from domain

  int userInfoIndex = domain.indexOf("@");
  if (userInfoIndex != -1) {
    domain = domain.substring(userInfoIndex + 1);
  }

  parts.insert(0, domain);

  // remove tilde ~ which causes issue
  int tildeIndex = parts.indexOf("~");
  if (tildeIndex != -1) {
    parts.removeAt(tildeIndex);
  }
  return parts;
}
