# soap_dart

English | [中文](README.CN.md)

`soap_dart` provides a small SOAP client runtime, a WSDL/XSD parser, and a
`wsdl2dart` generator for typed Dart clients.

## Annotation generator

Add a SOAP interface and run `build_runner`:

```dart
import 'package:soap_dart/soap_dart.dart';

part 'calculator_api.g.dart';

@SoapApi(namespace: 'urn:calculator')
abstract class CalculatorApi {
  factory CalculatorApi(SoapClient client) = _CalculatorApi;

  @SoapOperation(action: 'urn:add', requestName: 'Add')
  Future<AddResponse> add(AddRequest request);
}

@SoapModel(name: 'Add')
class AddRequest {
  final int a;
  final int b;

  const AddRequest({required this.a, required this.b});
}

@SoapModel(name: 'AddResponse')
class AddResponse {
  @SoapField(name: 'result')
  final int value;

  const AddResponse({required this.value});
}
```

```sh
dart run build_runner build --delete-conflicting-outputs
```

The generated implementation sends SOAP envelopes through `SoapClient` and maps
SOAP body XML back to the declared return type.

## WSDL generator

```sh
dart run soap_dart:wsdl2dart -i service.wsdl -o lib/service_client.dart
```

Generated clients use the runtime in `package:soap_dart/soap_dart.dart`.


## For detailed usage
please refer to the [example](example/README.md)