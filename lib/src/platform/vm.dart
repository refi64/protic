import 'dart:io' as io;

import '../api.dart';

class FileSystemProvider implements FileProvider {
  String read(String path) {
    try {
      return new io.File(path).readAsStringSync();
    } on io.FileSystemException {
      return null;
    }
  }

  String readStdin() {
    var buffer = new StringBuffer();
    while (true) {
      var line = io.stdin.readLineSync(retainNewlines: true);
      if (line == null) {
        break;
      }
      buffer.write(line);
    }
    return buffer.toString();
  }

  bool write(String path, String data) {
    try {
      new io.File(path).writeAsStringSync(data);
    } on io.FileSystemException {
      return false;
    }
    return true;
  }
}

FileProvider platformFileProvider() => new FileSystemProvider();

void exit([int code]) => io.exit(code ?? 0);
