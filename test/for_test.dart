import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('for works', () {
    expect(r'<+ for var in="1 2 3"><+ value="$var"></+>', compilesTo('1\n2\n3\n'));
    expect(r'<+ for var upto="3"><+ value="$var"></+>', compilesTo('0\n1\n2\n'));

    expect('<+ for var in="1 2 3">',
           compilesWithErrors(['for statement must have a body']));
    expect('<+ for></+>', compilesWithErrors(['invalid for statement']));
    expect('<+ for a></+>', compilesWithErrors(['invalid for statement']));
    expect('<+ for a b c></+>', compilesWithErrors(['invalid for statement']));
    expect('<+ for var="1" value></+>',
           compilesWithErrors(['for statement variable attribute must not have a value',
                               'for statement expression must not be empty']));
    expect('<+ for var value></+>',
           compilesWithErrors(['for statement expression must not be empty']));
    expect('<+ for var value="123"></+>',
           compilesWithErrors(['for statement expression kind must be in or upto']));
    expect('<+ for var upto="a"></+>',
           compilesWithErrors(['expression is not a valid integer']));
  });
}
