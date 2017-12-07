export 'platform/generic.dart'
  if (dart.library.io) 'platform/vm.dart'
  if (node) 'platform/node.dart';
