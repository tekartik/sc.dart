import 'dart:io';
import 'package:process_run/cmd_run.dart';

class StdBuf {
  StringBuffer out = StringBuffer();
  StringBuffer err = StringBuffer();

  void outAppend(Object object) {
    if (out.length > 0) {
      out.writeln();
    }
    out.write(object);
  }

  void errAppend(Object object) {
    if (err.length > 0) {
      err.writeln();
    }
    err.write(object);
  }

  void appendResult(ProcessResult result) {
    if (result.stdout.toString().length > 0) {
      outAppend('${result.stdout}');
    }
    if (result.stderr.toString().length > 0) {
      errAppend('${result.stderr}');
    }
  }

  // debug
  void appendCmdResult(ProcessCmd cmd, ProcessResult result) {
    outAppend('> ${cmd}');
    outAppend('=> ${result.exitCode}');
    if (result.stdout.toString().length > 0) {
      outAppend('out: ${result.stdout}');
    }
    if (result.stderr.toString().length > 0) {
      errAppend('err: ${result.stderr}');
    }
  }

  void print([String header]) {
    if (header != null &&
        (out.toString().length > 0 || err.toString().length > 0)) {
      stdout.writeln(header);
    }
    if (out.toString().length > 0) {
      stdout.writeln(out);
    }
    if (err.toString().length > 0) {
      stderr.writeln(err);
    }
  }
}
