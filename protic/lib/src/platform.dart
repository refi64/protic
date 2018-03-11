export 'platform/generic.dart'
  if (dart.library.io) 'platform/vm.dart'
  if (dart.library.js) 'platform/node.dart';
