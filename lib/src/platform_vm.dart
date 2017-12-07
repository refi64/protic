import 'dart:io';

import '../api.dart';

class FileSystemProvider implements FileProvider {
  String read(String path) {
    try {
      return new File(path).readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }
}

FileProvider platformFileProvider() => new FileSystemProvider();
