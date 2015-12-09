library tekartik_io_tools.src.scpath;

import 'package:path/path.dart';

///
/// Convert a uri to a convenient path part
/// removing user information and scheme
List<String> scUriToPathParts(String uri) {
  Uri _uri = Uri.parse(uri);
  List<String> parts = posix.split(_uri.path);

  // remove root if any
  if (parts[0] == '/') {
    parts = parts.sublist(1);
  }
  // remove user information from domain
  String domain = _uri.host;
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
