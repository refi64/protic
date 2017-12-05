import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('set: and value work', () {
    expect(r'<+ set:var="value">var is: <+ value="$var">', compilesTo('var is: value'));
  });
}
