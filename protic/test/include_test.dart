import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('include works', () {
    var fileProvider = new MockFileProvider({
      'exists.html': '<div +#exists></div>',
    });

    expect('<+ include="exists.html">',
           compilesTo('<div id="exists"></div>', fileProvider: fileProvider));
    expect(r'<+ include="$file">',
           compilesTo('<div id="exists"></div>', vars: {'file': 'exists.html'},
                      fileProvider: fileProvider));
    expect('<+ include="noexists.html">',
           compilesWithErrors(['noexists.html does not exist'],
                              fileProvider: fileProvider));
  });

  test('include passes down proper variables', () {
    var fileProvider = new MockFileProvider({
      'file.html': r'<+ value="$var">',
    });

    expect('<+ set var="1"><+ include="file.html">',
           compilesWithErrors([r'error evaluating expression: undefined variable $var'],
                              fileProvider: fileProvider));
    expect('<+ include="file.html">',
           compilesTo('1', vars: {'var': '1'}, fileProvider: fileProvider));
    expect('<+ include="file.html" var="1">',
           compilesTo('1', fileProvider: fileProvider));
  });

  test('include does not load macros', () {
    var fileProvider = new MockFileProvider({
      'file.html': '<+ macro="expand">expanded!</+>',
    });

    expect('<+ include="file.html"><+@ expand>',
           compilesWithErrors(['undefined macro expand'], fileProvider: fileProvider));
  });
}
