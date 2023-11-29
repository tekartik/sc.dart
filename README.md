# tekartik_sc.dart

Tekartik source control helpers (git &amp; hg) for dart

## Setup

in `pubspec.yaml`:

```yaml
dependencies:
  tekartik_sc:
    git:
      url: https://github.com/tekartik/sc.dart
      ref: dart3a
    version: '>=0.7.0'
```

Versioning follows [dart project versioning](https://github.com/tekartik/common.dart/blob/main/doc/tekartik_versioning.md) conventions.

## Usage

pubspec.yaml:

```yaml
dependencies:
  tekartik_sc:
    git:
      url: https://github.com/tekartik/sc.dart
      ref: dart3a
    version: '>=0.7.0'
```

Recursively pull

    scpull

Recursively get status

    scstatus

Push & pull

    scpp

Revert local change

    screvert

Clone either mercurial/git repository building path like  `<sc>/domain.com/path` (example: git/github/tekartik/tekartik_sc.dart)

    scsclone

