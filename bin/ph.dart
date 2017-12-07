import 'package:ph/ph.dart';

void main(List<String> args) {
  var result = compile(args[0], vars: {'var': 'test'});
  print(result.code);
  for (var error in result.errors) {
    print(error);
  }
}
