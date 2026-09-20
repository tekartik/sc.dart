---
name: tekartik-sc-tools
description: >-
  Use when walking a tree of git/mercurial checkouts or wrapping the sc
  command line tools of tekartik_sc: handleScPath,
  recursiveHandleScPathPoolSize, isScTopLevelPath, getScName,
  findScTopLevelPath from package:tekartik_sc/sc.dart, the mercurial API
  (HgPath, HgProject, HgStatusResult, HgOutgoingResult, isHgSupported,
  hgCmd), and the package:tekartik_sc/bin/ entry points scpull, scpp,
  scstatus, scclone, screvert, screset, sccleanup, scrunci, sccheckgit and
  sccheckhg.
---

# Source-control tree tools (tekartik_sc)

Besides its git API, `tekartik_sc` offers a source-control agnostic layer
(git or mercurial), a recursive walker that stops at each repository root,
and a set of `sc*` command line tools built on both. Everything is
`dart:io`, VM only.

## Guidelines

* Dependency (git only, not on pub.dev - the repo root is the package, no
  `path:`):
  ```yaml
  dependencies:
    tekartik_sc:
      git:
        url: https://github.com/tekartik/sc.dart
      version: '>=0.7.0'
  ```
* `import 'package:tekartik_sc/sc.dart';` for the agnostic layer,
  `package:tekartik_sc/hg.dart` for mercurial,
  `package:tekartik_sc/bin/<command>.dart` for a command entry point. Never
  import `package:tekartik_sc/src/...`.
* Detection: `await getScName(path)` returns the `git` or `hg` string
  constant, or `null` when the path is not a repository root;
  `await isScTopLevelPath(path)` is the boolean form;
  `await findScTopLevelPath(path)` walks the parents up to the enclosing
  repository root (`null` when there is none).
* `await handleScPath(dir, (topPath) async {...}, recursive: true)` is the
  walker every `sc*` tool uses: when `dir` is inside a repository, the
  callback runs once on its top level path and the walk stops there;
  otherwise, with `recursive: true`, it descends into sub directories,
  skipping anything starting with `.`. Without `recursive` it writes
  `<dir> does not belong to source control` on stderr. Errors during the
  recursion are swallowed.
* Concurrency: callbacks run through a pool of
  `recursiveHandleScPathPoolSize` (default 10). Assign it before the first
  walk; it re-creates the pool (the same value backs `recursiveGitRunPoolSize`
  of `git.dart`).
* Mercurial (`hg.dart`) mirrors the git API: `HgPath(path)` with
  `status()` -> `HgStatusResult.nothingToCommit`, `outgoing()` ->
  `HgOutgoingResult.branchIsAhead`, and the `pullCmd(update: true)`,
  `pushCmd()`, `revertCmd(path:, noBackup:)`, `addCmd(pathspec:)`,
  `commitCmd(message, all:)`, `checkoutCmd(commit:)` builders;
  `HgProject(src, path: dir)` adds `cloneCmd(insecure:)` and
  `pullOrClone()`. Check `await isHgSupported` first;
  `checkHgSupportDisabled` is true when the `TEKARTIK_HG_SUPPORT`
  environment variable is set to `false`, which turns hg support off for the
  whole process.
* Mercurial support is legacy: `screset` explicitly prints
  `hg (mercurial) not supported yet`, and new code should stay on the git
  API.
* Command entry points, each a `main(List<String> arguments)` in
  `package:tekartik_sc/bin/`: `scpull` (recursive pull), `scpp` (push and
  pull), `scstatus` (recursive status, also exposed as `scStatusMain`),
  `scclone` (clone an url into a `<host>/<owner>/<repo>` tree), `screvert`
  (revert local changes), `screset` (reset branches to `origin/<branch>`),
  `sccleanup` (`git fetch --prune` then delete the local branches whose
  upstream is gone), `scrunci` (clone a repository in a temp folder and run
  `dev_build`'s `run_ci` on it), `sccheckgit` and `sccheckhg` (diagnose the
  git/hg installation).
* Shared command options: `-h/--help`, `--version`, `-v/--verbose` and
  `-n/--dry-run` (print the commands instead of running them; `scclone` uses
  `-d` for it). `scpp` and `sccleanup` add `-t/--timeout <ms>` per
  repository, `screvert` and `screset` a `-r/--recursive` flag, `scstatus` a
  `-m/--modified` flag and `-l/--log <level>`. Positional arguments are the
  folders to walk, defaulting to `.`.
* A repository containing a `.local/.skip_sc` file is skipped by the tools
  that walk a tree; use it to park a checkout you do not want touched.
* To get the commands as executables, add a one-line wrapper per command in
  your own package's `bin/` (`export 'package:tekartik_sc/bin/scpull.dart';`,
  as `example/bin/` does in this repo), list them under `executables:` in
  your `pubspec.yaml`, then `dart pub global activate --source path .`. You
  can also call a command's `main` from Dart with your own argument list.
* The git API itself (`GitPath`, `GitProject`, `recursiveGitRun`, branches,
  status) is in [../tekartik-sc-git/SKILL.md](../tekartik-sc-git/SKILL.md).

## Examples

### Walk a tree and report what each checkout is

```dart
import 'package:tekartik_sc/sc.dart';

Future<void> main(List<String> args) async {
  recursiveHandleScPathPoolSize = 4;
  for (var dir in args.isEmpty ? ['.'] : args) {
    await handleScPath(dir, (topPath) async {
      print('$topPath: ${await getScName(topPath)}');
    }, recursive: true);
  }
}
```

### Find the repository a file belongs to

```dart
import 'package:tekartik_sc/sc.dart';

Future<void> describe(String path) async {
  var top = await findScTopLevelPath(path);
  if (top == null) {
    print('$path is not under source control');
    return;
  }
  print('$path belongs to $top (${await getScName(top)})');
}
```

### Handle git and mercurial in the same walk

```dart
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/sc.dart';

Future<void> main() async {
  await handleScPath('.', (topPath) async {
    switch (await getScName(topPath)) {
      case 'git':
        await runCmd(GitPath(topPath).pullCmd(), verbose: true);
      case 'hg':
        if (await isHgSupported) {
          await runCmd(HgPath(topPath).pullCmd(), verbose: true);
        }
    }
  }, recursive: true);
}
```

### Mercurial status and outgoing changes

```dart
import 'package:tekartik_sc/hg.dart';

Future<void> report(String path) async {
  if (!await isHgSupported) {
    print('hg not available (disabled: $checkHgSupportDisabled)');
    return;
  }
  var hgPath = HgPath(path);
  var status = await hgPath.status(verbose: true);
  var outgoing = await hgPath.outgoing();
  print('clean: ${status.nothingToCommit}, ahead: ${outgoing.branchIsAhead}');
}
```

### Run a command entry point from Dart

```dart
// bin/scpull.dart of your own package is simply:
// export 'package:tekartik_sc/bin/scpull.dart';
import 'package:tekartik_sc/bin/scstatus.dart';

Future<void> main() async {
  // Same as: scstatus -v --modified .local/checkout
  await scStatusMain(['-v', '--modified', '.local/checkout']);
}
```

## Common mistakes

* Calling `handleScPath` without `recursive: true` on a plain folder: it only
  complains on stderr.
* Setting `recursiveHandleScPathPoolSize` after the walk has started - the
  pool is created on assignment.
* Expecting `handleScPath` to surface errors: its recursion catches and
  ignores them, so report failures from inside your own callback.
* Writing new code against `HgPath`/`HgProject`: mercurial support is legacy
  and partly unimplemented in the tools.
* Trying to `dart pub global activate` `tekartik_sc` itself: it declares no
  `executables:`, wrap the `bin/` libraries in your own package.
