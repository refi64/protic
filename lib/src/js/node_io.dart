@JS()
library ph.src.js.node_fs;

import 'package:js/js.dart';

@JS()
external dynamic require(String module);

@JS()
@anonymous
class NodeFsOptions {
  external String get encoding;
  external factory NodeFsOptions({String encoding});
}

@JS()
@anonymous
class NodeFsModule {
  external dynamic readFileSync(dynamic path, NodeFsOptions options);
  external void writeFileSync(dynamic path, dynamic data, NodeFsOptions options);
}

NodeFsModule requireFs() => require('fs') as NodeFsModule;

@JS('process.exit')
external void exit([int code]);