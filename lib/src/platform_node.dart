import '../api.dart';
import 'js/node_io.dart';

export 'js/node_io.dart' show exit;

class FileSystemProvider implements FileProvider {
  NodeFsModule _fs;

  FileSystemProvider(): _fs = requireFs();

  String read(String path) {
    try {
      return _fs.readFileSync(path, new NodeFsOptions(encoding: 'utf8'));
    } catch (ex) {
      return null;
    }
  }

  String readStdin() {
    try {
      return _fs.readFileSync(0, new NodeFsOptions(encoding: 'utf8'));
    } catch (ex) {
      return null;
    }
  }

  bool write(String path, String data) {
    try {
      _fs.writeFileSync(path, data, new NodeFsOptions(encoding: 'utf8'));
    } catch (ex) {
      return false;
    }
    return true;
  }
}

FileProvider platformFileProvider() => new FileSystemProvider();
