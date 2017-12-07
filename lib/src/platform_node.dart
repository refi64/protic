import 'dart:js';

import '../api.dart';
import 'js/node_fs.dart';

class FileSystemProvider implements FileProvider {
  NodeFsModule _fs;

  FileSystemProvider(): _fs = requireFs();

  String read(String path) {
    try {
      return _fs.readFileSync(path, new NodeFsReadOptions(encoding: 'utf8'));
    } catch (ex) {
      return null;
    }
  }
}

FileProvider platformFileProvider() => new FileSystemProvider();
