// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'annotated_api.dart';

// **************************************************************************
// SoapApiGenerator
// **************************************************************************

final class _CalculatorApi implements CalculatorApi {
  _CalculatorApi(this._client);

  final SoapClient _client;

  @override
  Future<AddResponse> add(AddRequest request) {
    return _client.call<AddResponse>(
      body: _addRequestToSoapXml(request,
          name: 'Add', namespace: 'urn:calculator'),
      soapAction: 'urn:add',
      soap12: false,
      decode: _addResponseFromSoapXml,
    );
  }

  @override
  Future<int> multiply(
    int left,
    int right,
  ) {
    return _client.call<int>(
      body: _soapBuildRequest('Multiply',
          namespace: 'urn:calculator',
          children: [
            _SoapGeneratedEntry('a', left),
            _SoapGeneratedEntry('b', right)
          ],
          attributes: []),
      soapAction: 'urn:multiply',
      soap12: false,
      decode: (element) => (soapParseInt(soapElementText(element)) ?? 0),
    );
  }
}

XmlElement _addRequestToSoapXml(
  AddRequest value, {
  String? name,
  String? namespace,
}) {
  final builder = XmlBuilder();
  builder.element(name ?? 'Add', nest: () {
    if (namespace != null) {
      builder.attribute('xmlns', namespace);
    }
    _soapGeneratedWriteElement(builder, 'a', value.a);
    _soapGeneratedWriteElement(builder, 'b', value.b);
  });
  return builder.buildDocument().rootElement;
}

AddResponse _addResponseFromSoapXml(XmlElement element) {
  return AddResponse(
    value: (_soapGeneratedReadElement(element, 'result',
        (element) => (soapParseInt(soapElementText(element)) ?? 0)))!,
  );
}

final class _SoapGeneratedEntry {
  const _SoapGeneratedEntry(
    this.name,
    this.value,
  );

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
  builder.element(name, nest: () {
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
  });
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
    builder.element(name, nest: () {
      builder.xml(value.toXmlString());
    });
    return;
  }
  builder.element(name, nest: () {
    builder.text(_soapGeneratedFormat(value));
  });
}

String _soapGeneratedFormat(Object value) => soapFormatValue(value);
