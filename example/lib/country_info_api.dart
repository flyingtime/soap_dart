import 'package:soap_dart/soap_dart.dart';

part 'country_info_api.g.dart';

const countryInfoNamespace =
    'https://soap-service-free.mock.beeceptor.com/CountryInfoService';

const countryInfoEndpoint =
    'https://soap-service-free.mock.beeceptor.com/CountryInfoService.wso';

@SoapApi(endpoint: countryInfoEndpoint, namespace: countryInfoNamespace)
abstract class CountryInfoApi {
  factory CountryInfoApi([SoapClient? client]) = _CountryInfoApi;

  @SoapOperation(
    action:
        'https://soap-service-free.mock.beeceptor.com/CountryInfoService.wso/ListOfContinentsByName',
    requestName: 'ListOfContinentsByName',
    responseName: 'ListOfContinentsByNameResponse',
  )
  Future<ListOfContinentsByNameResponse> listOfContinentsByName();

  @SoapOperation(
    action:
        'https://soap-service-free.mock.beeceptor.com/CountryInfoService.wso/ListOfCountryNamesByName',
    requestName: 'ListOfCountryNamesByName',
    responseName: 'ListOfCountryNamesByNameResponse',
  )
  Future<ListOfCountryNamesByNameResponse> listOfCountryNamesByName();
}

@SoapModel(name: 'ListOfContinentsByNameResponse')
final class ListOfContinentsByNameResponse {
  @SoapField(name: 'ListOfContinentsByNameResult')
  final ArrayOfContinents? listOfContinentsByNameResult;

  const ListOfContinentsByNameResponse({this.listOfContinentsByNameResult});
}

@SoapModel(name: 'ListOfCountryNamesByNameResponse')
final class ListOfCountryNamesByNameResponse {
  @SoapField(name: 'ListOfCountryNamesByNameResult')
  final ArrayOfCountryNames? listOfCountryNamesByNameResult;

  const ListOfCountryNamesByNameResponse({this.listOfCountryNamesByNameResult});
}

@SoapModel(name: 'ArrayOfContinents')
final class ArrayOfContinents {
  @SoapField(name: 'tContinent')
  final List<Continent> tContinent;

  const ArrayOfContinents({this.tContinent = const []});
}

@SoapModel(name: 'ArrayOfCountryNames')
final class ArrayOfCountryNames {
  @SoapField(name: 'tCountryCodeAndName')
  final List<CountryCodeAndName> tCountryCodeAndName;

  const ArrayOfCountryNames({this.tCountryCodeAndName = const []});
}

@SoapModel(name: 'Continent')
final class Continent {
  @SoapField(name: 'sCode')
  final String sCode;

  @SoapField(name: 'sName')
  final String sName;

  const Continent({this.sCode = '', this.sName = ''});
}

@SoapModel(name: 'CountryCodeAndName')
final class CountryCodeAndName {
  @SoapField(name: 'sISOCode')
  final String sISOCode;

  @SoapField(name: 'sName')
  final String sName;

  const CountryCodeAndName({this.sISOCode = '', this.sName = ''});
}
