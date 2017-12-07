export 'platform_generic.dart'
  if (dart.library.io) 'platform_vm.dart'
  if (node) 'platform_node.dart';
