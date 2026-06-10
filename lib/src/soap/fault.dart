import 'package:xml/xml.dart';

import 'message.dart';
import 'xml_value.dart';

/// SOAP fault returned by a service.
final class SoapFault implements Exception {
  final String? code;
  final String? reason;
  final String? actor;
  final String? detail;

  const SoapFault({this.code, this.reason, this.actor, this.detail});

  factory SoapFault.fromElement(XmlElement fault) {
    final code = fault.getElementByLocalName('faultcode')?.innerText.trim() ??
        fault
            .getElementByLocalName('Code')
            ?.getElementByLocalName('Value')
            ?.innerText
            .trim();
    final reason =
        fault.getElementByLocalName('faultstring')?.innerText.trim() ??
            fault
                .getElementByLocalName('Reason')
                ?.getElementByLocalName('Text')
                ?.innerText
                .trim();
    final actor = fault.getElementByLocalName('faultactor')?.innerText.trim();
    final detailElement = fault.getElementByLocalName('detail') ??
        fault.getElementByLocalName('Detail');
    return SoapFault(
      code: code,
      reason: reason,
      actor: actor,
      detail: detailElement?.children.map((node) => node.toXmlString()).join(),
    );
  }

  static SoapFault? tryParse(String xmlText) {
    final document = XmlDocument.parse(xmlText);
    final body = soapBodyElement(document);
    final fault = body.childElements
        .where((element) => element.name.local == 'Fault')
        .firstOrNull;
    return fault == null ? null : SoapFault.fromElement(fault);
  }

  @override
  String toString() {
    final parts = [
      if (code != null && code!.isNotEmpty) code,
      if (reason != null && reason!.isNotEmpty) reason,
    ];
    return parts.isEmpty ? 'SOAP fault' : 'SOAP fault: ${parts.join(': ')}';
  }
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

/// HTTP error for a SOAP request that did not return a SOAP fault body.
final class SoapHttpException implements Exception {
  final int statusCode;
  final String reasonPhrase;
  final String body;

  const SoapHttpException(this.statusCode, this.reasonPhrase, this.body);

  @override
  String toString() => 'HTTP $statusCode $reasonPhrase: $body';
}
