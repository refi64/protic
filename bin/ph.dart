import 'package:ph/ph.dart';

void main(List<String> args) {
  var errors = [];
  print(compileString(args[0], errors: errors, vars: {'var': 'test'}));
  for (var error in errors) {
    print(error);
  }
}
