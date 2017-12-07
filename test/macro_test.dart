import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('macro definitions work', () {
    expect('<+ macro="expand">abc</+>', compilesTo(''));
    expect('<+ macro>abc</+>', compilesWithErrors(['macro name cannot be empty']));
  });

  test('macro expansions work', () {
    expect('<+ macro="expand">expand</+><+@ expand></+@>', compilesTo('expand'));
    expect('<+@ expand></+@>', compilesWithErrors(['undefined macro expand']));
    expect('<+@></+@>',
           compilesWithErrors(['macro expansion requires a macro name to expand']));
    expect('<+@ name="value"></+@>',
           compilesWithErrors(['macro name should not have a value']));
    expect(r'<+ macro="expand"><+ value="var: $@var"></+><+@ expand var="1"></+@>',
           compilesTo('var: 1'));
  });

  test('macro slots work', () {
    expect('<+ macro="expand"><+ slot></+><+@ expand>slot contents</+@>',
           compilesTo('slot contents'));
  });
}
