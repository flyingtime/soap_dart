import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/builder/soap_api_generator.dart';

Builder soapBuilder(BuilderOptions options) =>
    SharedPartBuilder([SoapApiGenerator()], 'soap');
