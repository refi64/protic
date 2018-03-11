import 'package:protic/src/expression.dart';
import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('variables are parsed correctly', () {
    expect(r'$a', parsesTo(new Var('a')));
    expect(r'$myLong_Variabl-e', parsesTo(new Var('myLong_Variabl-e')));
    expect(r'$?exists', parsesTo(new Var('exists', isOptional: true)));
    expect(r'$@myMacroVar', parsesTo(new Var('myMacroVar', isMacroVar: true)));
    expect(r'$@?myMacroVar', parsesTo(new Var('myMacroVar', isMacroVar: true,
                                              isOptional: true)));
    expect(r'$', parseFails);
  });

  test('barewords are parsed correctly', () {
    expect('word', parsesTo(new Text('word')));
    expect('this%is_a@!cr@zY.W0rD', parsesTo(new Text('this%is_a@!cr@zY.W0rD')));
    expect('(a)', parsesTo(new Text('a')));
  });

  test('strings are parsed correctly', () {
    expect('"abc"', parsesTo(new Text('abc')));
    expect('"ab\\"c"', parsesTo(new Text('ab"c')));
    expect("'abc'", parsesTo(new Text("abc")));
    expect("'ab\\'c'", parsesTo(new Text("ab'c")));
    expect("'", parseFails);
  });

  test('concatenations are parsed correctly', () {
    expect('a b', parsesTo(new Concat([new Text('a'), new Text('b')], addSpace: true)));
    expect('a + b', parsesTo(new Concat([new Text('a'), new Text('b')])));
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
    expect(r'a and b or c',
           parsesTo(new Relation(left: new Relation(left: new Text('a'),
                                                    right: new Text('b'),
                                                    op: RelationOp.and),
                                 right: new Text('c'),
                                 op: RelationOp.or)));
  });

  test('negations are parsed correctly', () {
    expect(r'!$a', parsesTo(new Negation(new Var('a'))));
  });
}
