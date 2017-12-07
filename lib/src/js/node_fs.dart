@JS()
library ph.src.js.node_fs;

import 'package:js/js.dart';

@JS()
external dynamic require(String module);

@JS()
@anonymous
class NodeFsReadOptions {
  external String get encoding;
  external factory NodeFsReadOptions({String encoding});
}

@JS()
@anonymous
class NodeFsModule {
  external String readFileSync(String path, NodeFsReadOptions options);
}

NodeFsModule requireFs() => require('fs') as NodeFsModule;
