import 'package:flutter_test/flutter_test.dart';
import 'package:soap_dart/soap_dart.dart';
import 'package:soap_dart_example/country_info_api.dart';

void main() {
  test('country info annotation client calls Beeceptor service', () async {
    final requests = <String>[];
    final actions = <String?>[];
    final client = SoapClient(
      countryInfoEndpoint,
      onRequest: (request) {
        requests.add(request.body);
        actions.add(request.headers['SOAPAction']);
      },
    );
    addTearDown(client.close);
    final api = CountryInfoApi(client);

    final continentsResponse = await api.listOfContinentsByName();
    final countriesResponse = await api.listOfCountryNamesByName();

    final continents =
        continentsResponse.listOfContinentsByNameResult?.tContinent ?? [];
    final countries =
        countriesResponse.listOfCountryNamesByNameResult?.tCountryCodeAndName ??
        [];

    expect(continents.map((continent) => continent.sName), contains('Asia'));
    expect(continents.map((continent) => continent.sName), contains('Europe'));
    expect(
      countries.any(
        (country) => country.sISOCode == 'CN' && country.sName == 'China',
      ),
      isTrue,
    );
    expect(
      countries.any(
        (country) =>
            country.sISOCode == 'US' && country.sName == 'United States',
      ),
      isTrue,
    );
    expect(requests.first, contains('<ListOfContinentsByName'));
    expect(requests.first, contains('xmlns="$countryInfoNamespace"'));
    expect(requests.last, contains('<ListOfCountryNamesByName'));
    expect(actions, [
      '"$countryInfoEndpoint/ListOfContinentsByName"',
      '"$countryInfoEndpoint/ListOfCountryNamesByName"',
    ]);
  });
}
