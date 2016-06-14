#!/bin/bash

# Fast fail the script on failures.
set -e

dartanalyzer --fatal-warnings \
  lib/git.dart \
  lib/hg.dart \
  lib/sc.dart \

pub run test -p vm,firefox