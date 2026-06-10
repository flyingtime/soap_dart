// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'country_info_api.dart';

// **************************************************************************
// SoapApiGenerator
// **************************************************************************

final class _CountryInfoApi implements CountryInfoApi {
  _CountryInfoApi([SoapClient? client])
    : _client =
          client ??
          SoapClient(
            'https://soap-service-free.mock.beeceptor.com/CountryInfoService.wso',
          );

  final SoapClient _client;

  @override
  Future<ListOfContinentsByNameResponse> listOfContinentsByName() {
    return _client.call<ListOfContinentsByNameResponse>(
      body: _soapBuildRequest(
        'ListOfContinentsByName',
        namespace:
            'https://soap-service-free.mock.beeceptor.com/CountryInfoService',
      ),
      soapAction:
          'https://soap-service-free.mock.beeceptor.com/CountryInfoService.wso/ListOfContinentsByName',
      soap12: false,
      decode: _listOfContinentsByNameResponseFromSoapXml,
    );
  }

  @override
  Future<ListOfCountryNamesByNameResponse> listOfCountryNamesByName() {
    return _client.call<ListOfCountryNamesByNameResponse>(
      body: _soapBuildRequest(
        'ListOfCountryNamesByName',
        namespace:
            'https://soap-service-free.mock.beeceptor.com/CountryInfoService',
      ),
      soapAction:
          'https://soap-service-free.mock.beeceptor.com/CountryInfoService.wso/ListOfCountryNamesByName',
      soap12: false,
      decode: _listOfCountryNamesByNameResponseFromSoapXml,
    );
  }
}

Continent _continentFromSoapXml(XmlElement element) {
  return Continent(
    sCode: (_soapGeneratedReadElement(
      element,
      'sCode',
      (element) => (soapElementText(element) ?? ''),
    ))!,
    sName: (_soapGeneratedReadElement(
      element,
      'sName',
      (element) => (soapElementText(element) ?? ''),
    ))!,
  );
}

ArrayOfContinents _arrayOfContinentsFromSoapXml(XmlElement element) {
  return ArrayOfContinents(
    tContinent: _soapGeneratedReadList(
      element,
      'tContinent',
      _continentFromSoapXml,
    ),
  );
}

ListOfContinentsByNameResponse _listOfContinentsByNameResponseFromSoapXml(
  XmlElement element,
) {
  return ListOfContinentsByNameResponse(
    listOfContinentsByNameResult: _soapGeneratedReadElement(
      element,
      'ListOfContinentsByNameResult',
      _arrayOfContinentsFromSoapXml,
    ),
  );
}

CountryCodeAndName _countryCodeAndNameFromSoapXml(XmlElement element) {
  return CountryCodeAndName(
    sISOCode: (_soapGeneratedReadElement(
      element,
      'sISOCode',
      (element) => (soapElementText(element) ?? ''),
    ))!,
    sName: (_soapGeneratedReadElement(
      element,
      'sName',
      (element) => (soapElementText(element) ?? ''),
    ))!,
  );
}

ArrayOfCountryNames _arrayOfCountryNamesFromSoapXml(XmlElement element) {
  return ArrayOfCountryNames(
    tCountryCodeAndName: _soapGeneratedReadList(
      element,
      'tCountryCodeAndName',
      _countryCodeAndNameFromSoapXml,
    ),
  );
}

ListOfCountryNamesByNameResponse _listOfCountryNamesByNameResponseFromSoapXml(
  XmlElement element,
) {
  return ListOfCountryNamesByNameResponse(
    listOfCountryNamesByNameResult: _soapGeneratedReadElement(
      element,
      'ListOfCountryNamesByNameResult',
      _arrayOfCountryNamesFromSoapXml,
    ),
  );
}

final class _SoapGeneratedEntry {
  const _SoapGeneratedEntry(this.name, this.value);

  final String name;

  final Object? value;
}

XmlElement _soapBuildRequest(
  String name, {
  String? namespace,
  List<_SoapGeneratedEntry> children = const [],
  List<_SoapGeneratedEntry> attributes = const [],
}) {
  final builder = XmlBuilder();
  builder.element(
    name,
    nest: () {
      if (namespace != null) {
        builder.attribute('xmlns', namespace);
      }
      for (final attribute in attributes) {
        if (attribute.value != null) {
          builder.attribute(
            attribute.name,
            _soapGeneratedFormat(attribute.value!),
          );
        }
      }
      for (final child in children) {
        _soapGeneratedWriteElement(builder, child.name, child.value);
      }
    },
  );
  return builder.buildDocument().rootElement;
}

T? _soapGeneratedReadElement<T>(
  XmlElement parent,
  String name,
  T Function(XmlElement element) read,
) {
  final child = parent.getElementByLocalName(name);
  return child == null ? null : read(child);
}

List<T> _soapGeneratedReadList<T>(
  XmlElement parent,
  String name,
  T Function(XmlElement element) read,
) => parent.getElementsByLocalName(name).map(read).toList();
void _soapGeneratedWriteElement(
  XmlBuilder builder,
  String name,
  Object? value,
) {
  if (value == null) return;
  if (value is XmlElement) {
    builder.xml(value.toXmlString());
    return;
  }
  if (value is SoapAny) {
    builder.element(
      name,
      nest: () {
        builder.xml(value.toXmlString());
      },
    );
    return;
  }
  builder.element(
    name,
    nest: () {
      builder.text(_soapGeneratedFormat(value));
    },
  );
}

String _soapGeneratedFormat(Object value) => soapFormatValue(value);
