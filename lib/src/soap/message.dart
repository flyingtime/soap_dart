import 'package:xml/xml.dart';

import 'xml_value.dart';

const soap11EnvelopeNamespace = 'http://schemas.xmlsoap.org/soap/envelope/';
const soap12EnvelopeNamespace = 'http://www.w3.org/2003/05/soap-envelope';
const xsdNamespace = 'http://www.w3.org/2001/XMLSchema';
const xsiNamespace = 'http://www.w3.org/2001/XMLSchema-instance';

/// Builds a SOAP envelope document around a body payload.
XmlDocument soapEnvelopeDocument({
  required XmlElement body,
  XmlElement? header,
  String envelopeNamespace = soap11EnvelopeNamespace,
  Map<String, String> namespaces = const {},
}) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="utf-8"');
  builder.element('soap:Envelope', nest: () {
    builder.attribute('xmlns:soap', envelopeNamespace);
    builder.attribute('xmlns:xsi', xsiNamespace);
    builder.attribute('xmlns:xsd', xsdNamespace);
    for (final entry in namespaces.entries) {
      final prefix = entry.key.isEmpty ? 'xmlns' : 'xmlns:${entry.key}';
      builder.attribute(prefix, entry.value);
    }
    if (header != null) {
      builder.element('soap:Header', nest: () {
        builder.xml(header.toXmlString());
      });
    }
    builder.element('soap:Body', nest: () {
      builder.xml(body.toXmlString());
    });
  });
  return builder.buildDocument();
}

XmlElement soapBodyElement(XmlDocument document) {
  for (final element in document.descendants.whereType<XmlElement>()) {
    if (element.name.local == 'Body' &&
        (element.name.namespaceUri == soap11EnvelopeNamespace ||
            element.name.namespaceUri == soap12EnvelopeNamespace ||
            element.name.prefix == 'soap' ||
            element.name.prefix == 'SOAP-ENV' ||
            element.name.prefix == 'env')) {
      return element;
    }
  }
  throw const FormatException('SOAP Body element not found');
}

XmlElement? soapHeaderElement(XmlDocument document) {
  for (final element in document.descendants.whereType<XmlElement>()) {
    if (element.name.local == 'Header') {
      return element;
    }
  }
  return null;
}

XmlElement firstSoapBodyChild(XmlDocument document) {
  final body = soapBodyElement(document);
  final child = body.childElements.firstOrNull;
  if (child == null) {
    throw const FormatException('SOAP Body has no child element');
  }
  return child;
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}

XmlElement soapSerializableToElement(
  Object? value, {
  required String name,
  String? namespace,
}) {
  if (value is SoapSerializable) {
    return value.toXmlElement(name: name, namespace: namespace);
  }
  return soapTextElement(name, value, namespace: namespace);
}
