import 'dart:convert';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';

/// Fields read by [githubRepoGetInfo] (`gh repo view --json`).
const _githubJsonFields = [
  'nameWithOwner',
  'url',
  'visibility',
  'isArchived',
  'archivedAt',
  'isFork',
  'parent',
  'isTemplate',
  'isMirror',
  'description',
  'homepageUrl',
  'repositoryTopics',
  'primaryLanguage',
  'licenseInfo',
  'defaultBranchRef',
  'diskUsage',
  'stargazerCount',
  'forkCount',
  'issues',
  'pullRequests',
  'latestRelease',
  'createdAt',
  'pushedAt',
];

/// GitHub information of a repository, from `gh repo view --json`.
class GithubRepoInfo {
  /// `owner/name`.
  final String? nameWithOwner;

  /// Web url.
  final String? url;

  /// public, private or internal.
  final String? visibility;

  /// True if archived.
  final bool isArchived;

  /// Archive date (yyyy-mm-dd).
  final String? archivedAt;

  /// Parent `owner/name` of a fork, null if not a fork.
  final String? forkParent;

  /// True if forked (even if the parent is not visible).
  final bool isFork;

  /// True for a template repository.
  final bool isTemplate;

  /// True for a mirror.
  final bool isMirror;

  /// Description.
  final String? description;

  /// Homepage url.
  final String? homepageUrl;

  /// Topics.
  final List<String> topics;

  /// Primary language.
  final String? primaryLanguage;

  /// License (spdx like key, i.e. bsd-2-clause).
  final String? license;

  /// Default branch.
  final String? defaultBranch;

  /// Disk usage in KiB.
  final int? diskUsage;

  /// Star count.
  final int? stargazerCount;

  /// Fork count.
  final int? forkCount;

  /// Open issue count.
  final int? openIssueCount;

  /// Open pull request count.
  final int? openPullRequestCount;

  /// Latest release tag.
  final String? latestRelease;

  /// Creation date (yyyy-mm-dd).
  final String? createdAt;

  /// Last push date (yyyy-mm-dd).
  final String? pushedAt;

  /// From the `gh repo view --json` output.
  GithubRepoInfo.fromJson(Map<String, Object?> map)
    : nameWithOwner = map['nameWithOwner'] as String?,
      url = map['url'] as String?,
      visibility = (map['visibility'] as String?)?.toLowerCase(),
      isArchived = map['isArchived'] == true,
      archivedAt = _dateOrNull(map['archivedAt']),
      isFork = map['isFork'] == true,
      forkParent = _parentNameWithOwner(map['parent']),
      isTemplate = map['isTemplate'] == true,
      isMirror = map['isMirror'] == true,
      description = _nonEmptyOrNull(map['description']),
      homepageUrl = _nonEmptyOrNull(map['homepageUrl']),
      topics = [
        for (var topic in (map['repositoryTopics'] as List?) ?? const [])
          if (topic case {'name': String name}) name,
      ],
      primaryLanguage = _nameOrNull(map['primaryLanguage']),
      license = switch (map['licenseInfo']) {
        {'key': String key} => key,
        _ => null,
      },
      defaultBranch = _nameOrNull(map['defaultBranchRef']),
      diskUsage = map['diskUsage'] as int?,
      stargazerCount = map['stargazerCount'] as int?,
      forkCount = map['forkCount'] as int?,
      openIssueCount = _totalCountOrNull(map['issues']),
      openPullRequestCount = _totalCountOrNull(map['pullRequests']),
      latestRelease = switch (map['latestRelease']) {
        {'tagName': String tagName} => tagName,
        _ => null,
      },
      createdAt = _dateOrNull(map['createdAt']),
      pushedAt = _dateOrNull(map['pushedAt']);
}

String? _nonEmptyOrNull(Object? value) =>
    (value is String && value.isNotEmpty) ? value : null;

String? _nameOrNull(Object? map) => switch (map) {
  {'name': String name} => name,
  _ => null,
};

int? _totalCountOrNull(Object? map) => switch (map) {
  {'totalCount': int count} => count,
  _ => null,
};

/// 2026-07-30T13:01:15Z => 2026-07-30
String? _dateOrNull(Object? value) =>
    (value is String && value.length >= 10) ? value.substring(0, 10) : null;

String? _parentNameWithOwner(Object? parent) => switch (parent) {
  {'name': String name, 'owner': {'login': String owner}} => '$owner/$name',
  _ => null,
};

/// Information about a git repository, see [gitPathGetInfo].
class GitRepoInfo {
  /// Repository top level path.
  final String path;

  /// Remote origin url, null if none.
  String? originUrl;

  /// Current branch, null on a detached HEAD.
  String? branch;

  /// Upstream branch, null if none.
  String? upstream;

  /// Commits ahead of [upstream].
  int? ahead;

  /// Commits behind [upstream] (as of the last fetch).
  int? behind;

  /// Modified, added, deleted or conflicting files.
  var changedFileCount = 0;

  /// Untracked files.
  var untrackedFileCount = 0;

  /// Last commit (short hash, date, subject), null if none.
  String? lastCommit;

  /// Number of commits in HEAD.
  int? commitCount;

  /// Date of the first commit.
  String? firstCommitDate;

  /// Local branches.
  var localBranchCount = 0;

  /// Remote branches.
  var remoteBranchCount = 0;

  /// Tags.
  var tagCount = 0;

  /// Stash entries.
  var stashCount = 0;

  /// Files tracked in HEAD, null if no commit.
  int? fileCount;

  /// Total size of the files tracked in HEAD.
  int? fileSize;

  /// Submodules in HEAD.
  var submoduleCount = 0;

  /// `pubspec.yaml` files tracked in HEAD.
  var dartPackageCount = 0;

  /// Size of the git object store (loose and packed objects).
  int? gitObjectsSize;

  /// GitHub information, null if not on GitHub or not available.
  GithubRepoInfo? github;

  /// Why [github] is not available for a GitHub repository.
  String? githubError;

  /// Information about the repository at [path].
  GitRepoInfo(this.path);

  /// Web url of the origin, null if none or local.
  String? get webUrl {
    var originUrl = this.originUrl;
    return github?.url ??
        (originUrl == null ? null : gitUrlToWebUrlOrNull(originUrl));
  }

  /// Display lines, `Label: value`, labels aligned.
  List<String> toLines() {
    var entries = <(String, String)>[];
    void add(String label, Object? value) {
      if (value != null) {
        entries.add((label, value.toString()));
      }
    }

    add('Path', path);
    add('Url', webUrl);
    add('Origin', originUrl ?? 'none');
    var github = this.github;
    if (github != null) {
      add('Visibility', github.visibility);
      add(
        'Archived',
        github.isArchived
            ? (github.archivedAt == null ? 'yes' : 'yes (${github.archivedAt})')
            : 'no',
      );
      if (github.isFork) {
        add('Fork of', github.forkParent ?? 'unknown');
      }
      if (github.isTemplate) {
        add('Template', 'yes');
      }
      if (github.isMirror) {
        add('Mirror', 'yes');
      }
      add('Description', github.description);
      add('Homepage', github.homepageUrl);
      if (github.topics.isNotEmpty) {
        add('Topics', github.topics.join(', '));
      }
      add('Language', github.primaryLanguage);
      add('License', github.license);
      add('Default branch', github.defaultBranch);
    } else {
      add('GitHub', githubError);
    }
    add('Branch', _branchText);
    add('Status', _statusText);
    add('Last commit', lastCommit ?? 'none');
    if (commitCount != null) {
      add(
        'Commits',
        firstCommitDate == null
            ? '$commitCount'
            : '$commitCount (since $firstCommitDate)',
      );
    }
    add(
      'Refs',
      '${_count(localBranchCount, 'local branch', 'local branches')}, '
          '${_count(remoteBranchCount, 'remote branch', 'remote branches')}, '
          '${_count(tagCount, 'tag')}',
    );
    if (stashCount > 0) {
      add('Stashes', stashCount);
    }
    if (fileCount != null) {
      add('Files', '$fileCount (${formatByteSize(fileSize ?? 0)})');
    }
    if (submoduleCount > 0) {
      add('Submodules', submoduleCount);
    }
    if (dartPackageCount > 0) {
      add('Dart packages', dartPackageCount);
    }
    if (gitObjectsSize != null) {
      add('Git objects', formatByteSize(gitObjectsSize!));
    }
    if (github != null) {
      if (github.diskUsage != null) {
        add('GitHub size', formatByteSize(github.diskUsage! * 1024));
      }
      add(
        'Stars',
        '${github.stargazerCount ?? 0} '
            '(${_count(github.forkCount ?? 0, 'fork')})',
      );
      add(
        'Open',
        '${_count(github.openIssueCount ?? 0, 'issue')}, '
            '${_count(github.openPullRequestCount ?? 0, 'pull request')}',
      );
      add('Latest release', github.latestRelease);
      add('Created', github.createdAt);
      add('Pushed', github.pushedAt);
    }

    var width = entries.fold(
      0,
      (max, e) => e.$1.length > max ? e.$1.length : max,
    );
    return [
      for (var (label, value) in entries)
        '${'$label:'.padRight(width + 2)}$value',
    ];
  }

  String get _branchText {
    var sb = StringBuffer(branch ?? 'detached HEAD');
    if (upstream != null) {
      sb.write(' -> $upstream');
      var parts = [
        if ((ahead ?? 0) > 0) 'ahead $ahead',
        if ((behind ?? 0) > 0) 'behind $behind',
      ];
      if (parts.isNotEmpty) {
        sb.write(' (${parts.join(', ')})');
      }
    }
    return sb.toString();
  }

  String get _statusText {
    if (changedFileCount == 0 && untrackedFileCount == 0) {
      return 'clean';
    }
    return [
      if (changedFileCount > 0) '$changedFileCount changed',
      if (untrackedFileCount > 0) '$untrackedFileCount untracked',
    ].join(', ');
  }

  @override
  String toString() => toLines().join('\n');
}

String _count(int count, String singular, [String? plural]) =>
    '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';

/// 1536 => 1.5 KiB
String formatByteSize(int size) {
  if (size < 1024) {
    return '$size B';
  }
  var value = size / 1024;
  for (var unit in ['KiB', 'MiB', 'GiB']) {
    if (value < 1024 || unit == 'GiB') {
      return '${value.toStringAsFixed(1)} $unit';
    }
    value /= 1024;
  }
  throw StateError('unreachable');
}

/// Converts a remote git url to a web url, null for a local path.
///
/// git@github.com:tekartik/sc.dart.git => https://github.com/tekartik/sc.dart
/// ssh://git@gitlab.com/alexrx/script.dart => https://gitlab.com/alexrx/script.dart
String? gitUrlToWebUrlOrNull(String url) {
  if (!url.startsWith('git@') && !url.contains('://')) {
    return null;
  }
  Uri uri;
  try {
    uri = gitUrlToHttpsUri(url);
  } on FormatException catch (_) {
    return null;
  }
  if (uri.host.isEmpty ||
      !const ['https', 'http', 'ssh', 'git'].contains(uri.scheme)) {
    return null;
  }
  var path = uri.path;
  if (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path.endsWith('.git')) {
    path = path.substring(0, path.length - 4);
  }
  return Uri(scheme: 'https', host: uri.host, path: path).toString();
}

/// `owner/name` of a GitHub web url, null if not on GitHub.
String? githubWebUrlGetNameWithOwnerOrNull(String webUrl) {
  var uri = Uri.parse(webUrl);
  if (uri.host.toLowerCase() != 'github.com') {
    return null;
  }
  var segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
  if (segments.length < 2) {
    return null;
  }
  return segments.take(2).join('/');
}

/// Applies `git status --porcelain=v2 --branch` output to [info].
void gitRepoInfoParseStatus(GitRepoInfo info, String out) {
  for (var line in LineSplitter.split(out)) {
    if (line.startsWith('# branch.head ')) {
      var head = line.substring('# branch.head '.length);
      info.branch = head == '(detached)' ? null : head;
    } else if (line.startsWith('# branch.upstream ')) {
      info.upstream = line.substring('# branch.upstream '.length);
    } else if (line.startsWith('# branch.ab ')) {
      var parts = line.substring('# branch.ab '.length).split(' ');
      if (parts.length == 2) {
        info.ahead = int.tryParse(parts[0].replaceFirst('+', ''));
        info.behind = int.tryParse(parts[1].replaceFirst('-', ''));
      }
    } else if (line.startsWith('? ')) {
      info.untrackedFileCount++;
    } else if (line.startsWith('1 ') ||
        line.startsWith('2 ') ||
        line.startsWith('u ')) {
      info.changedFileCount++;
    }
  }
}

/// Applies `git ls-tree -r -l -z HEAD` output to [info].
void gitRepoInfoParseLsTree(GitRepoInfo info, String out) {
  var fileCount = 0;
  var fileSize = 0;
  for (var entry in out.split('\x00')) {
    // <mode> SP <type> SP <object> SP+ <size> TAB <path>
    var tabIndex = entry.indexOf('\t');
    if (tabIndex == -1) {
      continue;
    }
    var meta = entry.substring(0, tabIndex).split(RegExp(r'\s+'));
    if (meta.length < 4) {
      continue;
    }
    var type = meta[1];
    if (type == 'commit') {
      info.submoduleCount++;
    } else if (type == 'blob') {
      fileCount++;
      fileSize += int.tryParse(meta[3]) ?? 0;
      if (posix.basename(entry.substring(tabIndex + 1)) == 'pubspec.yaml') {
        info.dartPackageCount++;
      }
    }
  }
  info.fileCount = fileCount;
  info.fileSize = fileSize;
}

/// Applies `git count-objects -v` output to [info], sizes are in KiB.
void gitRepoInfoParseCountObjects(GitRepoInfo info, String out) {
  var size = 0;
  for (var line in LineSplitter.split(out)) {
    var parts = line.split(':');
    if (parts.length == 2 &&
        const ['size', 'size-pack', 'size-garbage'].contains(parts[0])) {
      size += int.tryParse(parts[1].trim()) ?? 0;
    }
  }
  info.gitObjectsSize = size * 1024;
}

/// Reads the GitHub information of [nameWithOwner] using the `gh` CLI.
///
/// Throws a [StateError] with the `gh` error on failure.
Future<GithubRepoInfo> githubRepoGetInfo(
  String nameWithOwner, {
  bool? verbose,
}) async {
  var result = await runCmd(
    ProcessCmd('gh', [
      'repo',
      'view',
      nameWithOwner,
      '--json',
      _githubJsonFields.join(','),
    ]),
    verbose: verbose,
  );
  if (result.exitCode != 0) {
    var error = LineSplitter.split(
      result.stderr.toString(),
    ).firstWhere((line) => line.trim().isNotEmpty, orElse: () => 'gh error');
    throw StateError(error.trim());
  }
  return GithubRepoInfo.fromJson(
    (jsonDecode(result.stdout.toString()) as Map).cast<String, Object?>(),
  );
}

/// Gathers information about the repository at [gitPath].
///
/// GitHub information is read with the `gh` CLI unless [github] is false.
Future<GitRepoInfo> gitPathGetInfo(
  GitPath gitPath, {
  bool github = true,
  bool? verbose,
}) async {
  var info = GitRepoInfo(gitPath.path);

  /// Stdout of a git command, null on failure.
  Future<String?> git(List<String> args) async {
    var result = await runCmd(gitPath.cmd(args), verbose: verbose);
    return result.exitCode == 0 ? result.stdout.toString() : null;
  }

  Future<void> readOrigin() async {
    info.originUrl = (await git([
      'config',
      '--get',
      'remote.origin.url',
    ]))?.trim().nullIfEmpty;
    var webUrl = info.webUrl;
    var nameWithOwner = webUrl == null
        ? null
        : githubWebUrlGetNameWithOwnerOrNull(webUrl);
    if (nameWithOwner == null || !github) {
      return;
    }
    if (!await isGithubCliInstalled()) {
      info.githubError = 'gh not installed';
    } else {
      try {
        info.github = await githubRepoGetInfo(nameWithOwner, verbose: verbose);
      } on StateError catch (e) {
        info.githubError = e.message;
      }
    }
  }

  await Future.wait([
    readOrigin(),
    () async {
      var out = await git(['status', '--porcelain=v2', '--branch']);
      if (out != null) {
        gitRepoInfoParseStatus(info, out);
      }
    }(),
    () async {
      info.lastCommit = (await git([
        'log',
        '-1',
        '--format=%h %cs %s',
      ]))?.trim().nullIfEmpty;
    }(),
    () async {
      info.commitCount = int.tryParse(
        (await git(['rev-list', '--count', 'HEAD']))?.trim() ?? '',
      );
    }(),
    () async {
      // More than one root commit is possible, keep the oldest
      var dates = LineSplitter.split(
        (await git(['log', '--max-parents=0', '--format=%cs', 'HEAD'])) ?? '',
      ).where((line) => line.isNotEmpty).toList()..sort();
      info.firstCommitDate = dates.firstOrNull;
    }(),
    () async {
      var out = await git([
        'for-each-ref',
        '--format=%(refname)',
        'refs/heads',
        'refs/remotes',
        'refs/tags',
      ]);
      for (var ref in LineSplitter.split(out ?? '')) {
        if (ref.startsWith('refs/heads/')) {
          info.localBranchCount++;
        } else if (ref.startsWith('refs/remotes/')) {
          if (!ref.endsWith('/HEAD')) {
            info.remoteBranchCount++;
          }
        } else if (ref.startsWith('refs/tags/')) {
          info.tagCount++;
        }
      }
    }(),
    () async {
      info.stashCount = LineSplitter.split(
        (await git(['stash', 'list'])) ?? '',
      ).where((line) => line.isNotEmpty).length;
    }(),
    () async {
      var out = await git(['ls-tree', '-r', '-l', '-z', 'HEAD']);
      if (out != null) {
        gitRepoInfoParseLsTree(info, out);
      }
    }(),
    () async {
      var out = await git(['count-objects', '-v']);
      if (out != null) {
        gitRepoInfoParseCountObjects(info, out);
      }
    }(),
  ]);
  return info;
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

/// Display lines of the mercurial repository at [path].
Future<List<String>> hgPathGetInfoLines(String path, {bool? verbose}) async {
  var result = await runCmd(
    hgCmd(['paths', 'default'])..workingDirectory = path,
    verbose: verbose,
  );
  var origin = result.exitCode == 0 ? result.stdout.toString().trim() : '';
  return [
    'Path:           $path',
    'Source control: hg',
    'Origin:         ${origin.isEmpty ? 'none' : origin}',
  ];
}
