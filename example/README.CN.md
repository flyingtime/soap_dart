# soap_dart 示例

[English](README.md) | 中文

这是一个 Flutter 示例项目，用于演示 `soap_dart` 基于注解生成的 SOAP 客户端。

## 运行

```sh
flutter run
```

计算器按钮会调用本地基于注解生成的 `CalculatorApi`。
`CountryInfoApi` 按钮会调用 `lib/country_info_api.dart` 中基于注解生成的 CountryInfo SOAP 客户端：

```dart
final soapClient = SoapClient(countryInfoEndpoint);
final api = CountryInfoApi(soapClient);

final continents = await api.listOfContinentsByName();
final countries = await api.listOfCountryNamesByName();
```

`CountryInfoPortTypeClient` 按钮会调用 `lib/country_client.dart` 中由 WSDL 生成的客户端：

```dart
final soapClient = SoapClient(countryInfoEndpoint);
final api = CountryInfoPortTypeClient(soapClient);

final continents = await api.listOfContinentsByName(
  const ListOfContinentsByNameType(),
);
final countries = await api.listOfCountryNamesByName(
  const ListOfCountryNamesByNameType(),
);
```

修改注解 API 后，使用以下命令重新生成注解客户端：

```sh
dart run build_runner build --delete-conflicting-outputs
```
