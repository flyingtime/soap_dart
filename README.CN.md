# soap_dart

[English](README.md) | 中文

`soap_dart` 提供一个轻量级 SOAP 客户端运行时、WSDL/XSD 解析器，以及用于生成类型安全 Dart 客户端的 `wsdl2dart` 代码生成器。

## 注解生成器

添加一个 SOAP 接口，然后运行 `build_runner`：

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

生成的实现会通过 `SoapClient` 发送 SOAP Envelope，并将 SOAP Body XML 映射回声明的返回类型。

## WSDL 生成器

```sh
dart run soap_dart:wsdl2dart -i service.wsdl -o lib/service_client.dart
```

生成的客户端会使用 `package:soap_dart/soap_dart.dart` 中的运行时。

## 详细用法

请参考 [example](example/README.CN.md)。
