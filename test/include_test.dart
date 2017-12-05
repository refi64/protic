import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('include works', () {
    var fileProvider = new MockFileProvider({
      'exists.html': '<div +#exists></div>',
    });

    expect('<+ include="exists.html">',
           compilesTo('<div id="exists"></div>', fileProvider: fileProvider));
    expect('<+ include="noexists.html">',
           compilesWithErrors(['noexists.html does not exist'],
                              fileProvider: fileProvider));
  });
}
