import 'package:ph/src/expression.dart';
import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('variables are parsed correctly', () {
    expect(r'$a', parsesTo(new Var('a')));
    expect(r'$myLong_Variable', parsesTo(new Var('myLong_Variable')));
    expect(r'$@myMacroVar', parsesTo(new Var('myMacroVar', isMacroVar: true)));
    expect(r'$', parseFails);
  });

  test('barewords are parsed correctly', () {
    expect('word', parsesTo(new Text('word')));
    expect('this%is_a@!cr@zY.W0rD', parsesTo(new Text('this%is_a@!cr@zY.W0rD')));
  });

  test('strings are parsed correctly', () {
    expect('"abc"', parsesTo(new Text('abc')));
    expect('"ab\\"c"', parsesTo(new Text('ab"c')));
    expect("'abc'", parsesTo(new Text("abc")));
    expect("'ab\\'c'", parsesTo(new Text("ab'c")));
    expect("'", parseFails);
  });

  test('comparisons are parsed correctly', () {
    expect(r'$a == b', parsesTo(new Comparison(left: new Var('a'), right: new Text('b'),
                                               op: ComparisonOp.eq)));
    expect(r'c != $d', parsesTo(new Comparison(left: new Text('c'), right: new Var('d'),
                                               op: ComparisonOp.ne)));
  });

  test('relationals are parsed correctly', () {
    expect(r'$a == b and ($c or $d)',
           parsesTo(new Relation(left: new Comparison(left: new Var('a'),
                                                      right: new Text('b'),
                                                      op: ComparisonOp.eq),
                                 right: new Relation(left: new Var('c'),
                                                     right: new Var('d'),
                                                     op: RelationOp.or),
                                 op: RelationOp.and)));
  });
}
