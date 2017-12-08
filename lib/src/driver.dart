import 'package:args/args.dart';

import 'api.dart';
import 'platform.dart';

void usage() {
  print('usage: pH [-h] [-o|--output <output>] <input>');
}

void run(List<String> argv) {
  var parser = new ArgParser()
    ..addFlag('help', abbr: 'h', help: 'show this screen')
    ..addOption('output', abbr: 'o', help: 'the output file',
                defaultsTo: '-')
    ..addOption('define', abbr: 'D', help: 'define a variable', allowMultiple: true);

  ArgResults args;

  try {
    args = parser.parse(argv);
  } on FormatException catch (ex) {
    print(ex.message);
    exit(1);
  }

  if (args['help']) {
    usage();
    print('');
    print('pass - for input/output to read from stdin/write to stdout');
    print('');
    print(parser.usage);
    exit();
  }

  if (args.rest.length != 1) {
    print('exactly one input file must be passed');
    usage();
    exit(1);
  }

  var inputFile = args.rest[0];
  var outputFile = args['output'];
  var fileProvider = platformFileProvider();

  String input;
  if (inputFile == '-') {
    input = fileProvider.readStdin();
  } else {
    input = fileProvider.read(inputFile);
  }

  if (input == null) {
    print('failed to read input file $inputFile');
    exit(1);
  }

  var vars = <String, String>{};
  for (var define in args['define']) {
    if (define.contains('=')) {
      var parts = define.split('=');
      vars[parts[0]] = parts.sublist(1).join('=');
    } else {
      vars[define] = '';
    }
  }

  var result = compile(input, vars: vars, url: inputFile, fileProvider: fileProvider);

  if (result.errors.isNotEmpty) {
    for (var error in result.errors) {
      print(error);
    }
    exit(1);
  }

  if (outputFile == '-') {
    print(result.code);
  } else {
    if (!fileProvider.write(outputFile, result.code)) {
      print('failed to write output file $outputFile');
    }
  }
}
