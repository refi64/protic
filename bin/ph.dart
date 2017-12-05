import 'package:ph/ph.dart';

void main(List<String> args) {
  var errors = [];
  print(compileString(args[0], errors: errors));
  for (var error in errors) {
    print(error);
  }
}
