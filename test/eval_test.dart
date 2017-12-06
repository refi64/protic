import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('barewords and strings are evaluated correctly', () {
    expect('abc', evalsTo('abc'));
    expect('"123"', evalsTo('123'));
  });

  test('variables are evaluated correctly', () {
    expect(r'$a', evalFails(r'undefined variable $a'));
    expect(r'$a', evalsTo('1', vars: {'a': '1'}));
    expect(r'$?a', evalsTo(null));
    expect(r'$@a', evalFails(r'macro var $@a requested in non-macro'));
    expect(r'$@a', evalFails(r'undefined variable $@a', macroVars: {}));
    expect(r'$@a', evalsTo('1', macroVars: {'a': '1'}));
    expect(r'$@?a', evalsTo(null, macroVars: {}));
  });

  test('negations are evaluated correctly', () {
    expect(r'!a', evalsTo(null));
    expect(r'!$?a', evalsTo(''));
  });

  test('concatenations are evaluated correctly', () {
    expect('my name  is', evalsTo('my name is'));
    expect(r'my name is $name', evalsTo('my name is test', vars: {'name': 'test'}));
    expect('name + .', evalsTo('name.'));
    expect(r'$name + .', evalsTo('test.', vars: {'name': 'test'}));
    expect(r'this is empty: $?empty', evalsTo('this is empty:'));
    expect(r'this is also empty: + $?empty', evalsTo('this is also empty:'));
  });

  test('comparisons are evaluated correctly', () {
    expect('a == a', evalsTo(''));
    expect('a != a', evalsTo(null));
    expect('a == b', evalsTo(null));
    expect('a != b', evalsTo(''));
  });

  test('relationals are evaluated correctly', () {
    expect('a and b', evalsTo('b'));
    expect(r'$?a and b', evalsTo(null));
    expect(r'a and $?b', evalsTo(null));

    expect('a or b', evalsTo('a'));
    expect(r'$?a or b', evalsTo('b'));
    expect(r'$?a or $?b', evalsTo(null));
  });
}
