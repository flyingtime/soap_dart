# soap_dart example

English | [中文](README.CN.md)

Flutter example for `soap_dart` annotation-generated SOAP clients.

## Run

```sh
flutter run
```

The calculator buttons call the local annotation-generated `CalculatorApi`.
The `CountryInfoApi` button calls the annotation-generated CountryInfo SOAP
client in `lib/country_info_api.dart`:

```dart
final soapClient = SoapClient(countryInfoEndpoint);
final api = CountryInfoApi(soapClient);

final continents = await api.listOfContinentsByName();
final countries = await api.listOfCountryNamesByName();
```

The `CountryInfoPortTypeClient` button calls the WSDL-generated client in
`lib/country_client.dart`:

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

Regenerate annotation clients after changing annotated APIs:

```sh
dart run build_runner build --delete-conflicting-outputs
```
