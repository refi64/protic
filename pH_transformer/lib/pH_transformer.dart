import 'package:barback/barback.dart';
import 'package:pH/pH.dart' as pH;

import 'dart:async';

class PhTransformer extends Transformer {
  final BarbackSettings _settings;
  PhTransformer.asPlugin(this._settings);

  String get allowedExtensions => '.html';

  Future apply(Transform transform) async {
    var primary = transform.primaryInput;
    var content = await primary.readAsString();
    var result = pH.compile(content, vars: _settings.configuration['vars']);

    if (result.errors.isNotEmpty) {
      for (var error in result.errors) {
        transform.logger.error(error.toString(), asset: primary.id);
      }
    }

    transform.addOutput(new Asset.fromString(primary.id, content));
    return new Future.value();
  }
}
