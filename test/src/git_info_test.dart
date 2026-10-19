@TestOn('vm')
library;

import 'package:dev_test/test.dart';
import 'package:tekartik_sc/src/git_info.dart';

void main() => defineTests();

void defineTests() {
  group('git_info', () {
    test('gitUrlToWebUrlOrNull', () {
      expect(
        gitUrlToWebUrlOrNull('git@github.com:tekartik/sc.dart.git'),
        'https://github.com/tekartik/sc.dart',
      );
      expect(
        gitUrlToWebUrlOrNull('https://github.com/tekartik/sc.dart'),
        'https://github.com/tekartik/sc.dart',
      );
      expect(
        gitUrlToWebUrlOrNull('ssh://git@gitlab.com:22/alexrx/script.dart.git'),
        'https://gitlab.com/alexrx/script.dart',
      );
      expect(
        gitUrlToWebUrlOrNull('git@bitbucket.org:tka2k/sprite_winter'),
        'https://bitbucket.org/tka2k/sprite_winter',
      );
      // Local
      expect(gitUrlToWebUrlOrNull('/tmp/origin.git'), isNull);
      expect(gitUrlToWebUrlOrNull('../origin'), isNull);
      expect(gitUrlToWebUrlOrNull('file:///tmp/origin.git'), isNull);
    });

    test('githubWebUrlGetNameWithOwnerOrNull', () {
      expect(
        githubWebUrlGetNameWithOwnerOrNull(
          'https://github.com/tekartik/sc.dart',
        ),
        'tekartik/sc.dart',
      );
      expect(
        githubWebUrlGetNameWithOwnerOrNull(
          'https://gitlab.com/alexrx/script.dart',
        ),
        isNull,
      );
      expect(
        githubWebUrlGetNameWithOwnerOrNull('https://github.com/tekartik'),
        isNull,
      );
    });

    test('formatByteSize', () {
      expect(formatByteSize(0), '0 B');
      expect(formatByteSize(1023), '1023 B');
      expect(formatByteSize(1536), '1.5 KiB');
      expect(formatByteSize(3 * 1024 * 1024), '3.0 MiB');
      expect(formatByteSize(5 * 1024 * 1024 * 1024 * 1024), '5120.0 GiB');
    });

    test('GithubRepoInfo', () {
      var info = GithubRepoInfo.fromJson({
        'archivedAt': '2026-07-30T13:01:15Z',
        'createdAt': '2015-12-09T11:14:53Z',
        'defaultBranchRef': {'name': 'master'},
        'description': '',
        'diskUsage': 718,
        'isArchived': true,
        'isFork': true,
        'issues': {'totalCount': 2},
        'licenseInfo': {'key': 'bsd-2-clause', 'name': 'BSD 2-Clause'},
        'parent': {
          'id': 'x',
          'name': 'firebase-dart',
          'owner': {'id': 'y', 'login': 'googlearchive'},
        },
        'pullRequests': {'totalCount': 1},
        'repositoryTopics': [
          {'name': 'dart'},
          {'name': 'git'},
        ],
        'url': 'https://github.com/tekartik/firebase-dart',
        'visibility': 'PUBLIC',
      });
      expect(info.visibility, 'public');
      expect(info.isArchived, isTrue);
      expect(info.archivedAt, '2026-07-30');
      expect(info.isFork, isTrue);
      expect(info.forkParent, 'googlearchive/firebase-dart');
      expect(info.description, isNull);
      expect(info.defaultBranch, 'master');
      expect(info.license, 'bsd-2-clause');
      expect(info.topics, ['dart', 'git']);
      expect(info.openIssueCount, 2);
      expect(info.openPullRequestCount, 1);
      expect(info.latestRelease, isNull);
      expect(info.createdAt, '2015-12-09');

      var repoInfo = GitRepoInfo('/repo')
        ..originUrl = 'git@github.com:tekartik/firebase-dart.git'
        ..github = info;
      var lines = repoInfo.toLines();
      expect(
        lines,
        contains('Url:            https://github.com/tekartik/firebase-dart'),
      );
      expect(lines, contains('Visibility:     public'));
      expect(lines, contains('Archived:       yes (2026-07-30)'));
      expect(lines, contains('Fork of:        googlearchive/firebase-dart'));
      expect(lines, contains('Open:           2 issues, 1 pull request'));
    });

    test('gitRepoInfoParseStatus', () {
      var info = GitRepoInfo('/repo');
      gitRepoInfoParseStatus(info, '''
# branch.oid dadb93c16eae774d026b6c41905b0237fec0d885
# branch.head main
# branch.upstream origin/main
# branch.ab +2 -1
1 .M N... 100644 100644 100644 a b f
2 R. N... 100644 100644 100644 a b R100 g\th
u UU N... 100644 100644 100644 100644 a b c i
? new.txt
? other.txt
''');
      expect(info.branch, 'main');
      expect(info.upstream, 'origin/main');
      expect(info.ahead, 2);
      expect(info.behind, 1);
      expect(info.changedFileCount, 3);
      expect(info.untrackedFileCount, 2);
      expect(
        info.toLines(),
        contains('Branch:      main -> origin/main (ahead 2, behind 1)'),
      );
      expect(info.toLines(), contains('Status:      3 changed, 2 untracked'));

      info = GitRepoInfo('/repo');
      gitRepoInfoParseStatus(info, '# branch.head (detached)\n');
      expect(info.branch, isNull);
      expect(info.toLines(), contains('Branch:      detached HEAD'));
      expect(info.toLines(), contains('Status:      clean'));
    });

    test('gitRepoInfoParseLsTree', () {
      var info = GitRepoInfo('/repo');
      gitRepoInfoParseLsTree(
        info,
        [
          '100644 blob 1111111111111111111111111111111111111111     100\tpubspec.yaml',
          '100644 blob 2222222222222222222222222222222222222222    1948\tsub dir/pubspec.yaml',
          '120000 blob 3333333333333333333333333333333333333333      12\tlink',
          '160000 commit 4444444444444444444444444444444444444444       -\tmodule',
          '',
        ].join('\x00'),
      );
      expect(info.fileCount, 3);
      expect(info.fileSize, 2060);
      expect(info.dartPackageCount, 2);
      expect(info.submoduleCount, 1);
    });

    test('gitRepoInfoParseCountObjects', () {
      var info = GitRepoInfo('/repo');
      gitRepoInfoParseCountObjects(info, '''
count: 564
size: 2256
in-pack: 890
packs: 1
size-pack: 180
prune-packable: 0
garbage: 0
size-garbage: 4
''');
      expect(info.gitObjectsSize, (2256 + 180 + 4) * 1024);
    });
  });
}
