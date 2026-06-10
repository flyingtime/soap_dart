import 'dart:io';

import 'package:args/args.dart';

import '../wsdl/parser.dart';
import 'generator.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('input',
        abbr: 'i', help: 'Input WSDL file, URL, or - for stdin.')
    ..addOption('output', abbr: 'o', help: 'Output Dart file, or - for stdout.')
    ..addOption('namespace', abbr: 'n', help: 'Override target namespace.')
    ..addOption(
      'client-suffix',
      defaultsTo: 'Client',
      help: 'Suffix for generated port type client classes.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');

  final result = parser.parse(arguments);
  if (result.flag('help')) {
    stdout.writeln('Usage: dart run wsdl2dart -i service.wsdl -o service.dart');
    stdout.writeln(parser.usage);
    return;
  }

  final input = result.option('input') ?? '-';
  final output = result.option('output') ?? '-';
  final wsdlParser = WsdlParser();
  final document = input == '-'
      ? await wsdlParser.parseWithImports(
          await stdin.transform(systemEncoding.decoder).join(),
        )
      : (Uri.tryParse(input)?.scheme.isNotEmpty ?? false)
          ? await wsdlParser.parseUri(Uri.parse(input))
          : await wsdlParser.parseFile(input);

  final code = WsdlDartGenerator(
    namespaceOverride: result.option('namespace'),
    clientSuffix: result.option('client-suffix') ?? 'Client',
  ).generate(document);

  if (output == '-') {
    stdout.write(code);
  } else {
    await File(output).writeAsString(code);
  }
}
