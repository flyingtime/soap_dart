import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'fault.dart';
import 'message.dart';

typedef SoapRequestHook = FutureOr<void> Function(http.Request request);
typedef SoapResponseHook = FutureOr<void> Function(http.Response response);

/// HTTP SOAP client used by generated and hand-written clients.
final class SoapClient {
  final Uri endpoint;
  final http.Client _httpClient;
  final String envelopeNamespace;
  final String? userAgent;
  final Map<String, String> namespaces;
  final SoapRequestHook? onRequest;
  final SoapResponseHook? onResponse;

  SoapClient(
    Object endpoint, {
    http.Client? httpClient,
    this.envelopeNamespace = soap11EnvelopeNamespace,
    this.userAgent = 'soap_dart',
    this.namespaces = const {},
    this.onRequest,
    this.onResponse,
  })  : endpoint = endpoint is Uri ? endpoint : Uri.parse(endpoint.toString()),
        _httpClient = httpClient ?? http.Client();

  Future<T> call<T>({
    required XmlElement body,
    required T Function(XmlElement bodyChild) decode,
    String? soapAction,
    bool soap12 = false,
    XmlElement? header,
    Map<String, String> headers = const {},
  }) async {
    final envelope = soapEnvelopeDocument(
      body: body,
      header: header,
      envelopeNamespace: soap12 ? soap12EnvelopeNamespace : envelopeNamespace,
      namespaces: namespaces,
    );
    final request = http.Request('POST', endpoint);
    request.bodyBytes = utf8.encode(envelope.toXmlString(pretty: false));
    request.headers.addAll(headers);
    request.headers.putIfAbsent(
      'content-type',
      () => soap12 ? _soap12ContentType(soapAction) : 'text/xml; charset=utf-8',
    );
    if (!soap12 && soapAction != null) {
      request.headers.putIfAbsent('SOAPAction', () => '"$soapAction"');
    }
    if (userAgent != null && userAgent!.isNotEmpty) {
      request.headers.putIfAbsent('user-agent', () => userAgent!);
    }

    await onRequest?.call(request);
    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    await onResponse?.call(response);

    final maybeFault = _tryParseFault(response.body);
    if (maybeFault != null) {
      throw maybeFault;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SoapHttpException(
        response.statusCode,
        response.reasonPhrase ?? '',
        response.body,
      );
    }

    final document = XmlDocument.parse(response.body);
    return decode(firstSoapBodyChild(document));
  }

  Future<XmlElement> callRaw({
    required XmlElement body,
    String? soapAction,
    bool soap12 = false,
    XmlElement? header,
    Map<String, String> headers = const {},
  }) {
    return call<XmlElement>(
      body: body,
      soapAction: soapAction,
      soap12: soap12,
      header: header,
      headers: headers,
      decode: (element) => element,
    );
  }

  void close() {
    _httpClient.close();
  }
}

String _soap12ContentType(String? action) {
  final suffix = action == null ? '' : '; action="$action"';
  return 'application/soap+xml; charset=utf-8$suffix';
}

SoapFault? _tryParseFault(String body) {
  try {
    return SoapFault.tryParse(body);
  } on Object {
    return null;
  }
}
