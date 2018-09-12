# tekartik_sc.dart

Tekartik source control helpers (git &amp; hg) for dart

[![Build Status](https://travis-ci.org/tekartik/tekartik_sc.dart.svg?branch=master)](https://travis-ci.org/tekartik/tekartik_sc.dart)

## Usage

pubspec.yaml:

```yaml
dependencies
  tekartik_sc:
    git:
      url: git://github.com/tekartik/sc.dart
      ref: dart2
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

## Activation

### From git repository

    pub global activate -s git git://github.com/tekartik/sc.dart

### From local path

    pub global activate -s path .