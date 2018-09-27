library tekartik_io_tools.src.scpath;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/sc.dart';

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

Future handleScPath(String dir, dynamic Function(String dir) handleScDir,
    {bool recursive}) async {
  recursive ??= false;
  dir ??= Directory.current.path;
  dir = absolute(normalize(dir));
  var topDir = await findScTopLevelPath(dir);

  // We are in a git, don't recurse)
  if (topDir != null) {
    await handleScDir(topDir);
  } else {
    if (recursive) {
      try {
        List<Future> sub = [];
        await Directory(dir).list().listen((FileSystemEntity fse) {
          sub.add(() async {
            var path = fse.path;
            // Ignore folder starting with .
            // don't event go below
            if (!basename(path).startsWith('.') &&
                (await FileSystemEntity.isDirectory(dir))) {
              await handleScPath(fse.path, handleScDir, recursive: recursive);
            }
          }());
        }).asFuture();
        await Future.wait(sub);
      } catch (_, __) {}
    } else {
      stderr.writeln('$dir does not belong to source control');
    }
  }
}

Future<bool> isGitPathAndSupported(String path) async {
  return await isGitSupported && await isGitTopLevelPath(path);
}

Future<bool> isHgPathAndSupported(String path) async {
  return await isHgSupported && await isHgTopLevelPath(path);
}
