import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:soap_dart/soap_dart.dart';
import 'package:test/test.dart';

void main() {
  test('builds SOAP envelopes and parses faults', () {
    final body = soapTextElement('Ping', 'hello');
    final envelope = soapEnvelopeDocument(
      body: body,
      namespaces: const {'tns': 'urn:test'},
    ).toXmlString();

    expect(envelope, contains('soap:Envelope'));
    expect(envelope, contains('xmlns:tns="urn:test"'));
    expect(envelope, contains('<Ping>hello</Ping>'));

    final fault = SoapFault.tryParse('''
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <soap:Fault>
      <faultcode>soap:Client</faultcode>
      <faultstring>Bad request</faultstring>
      <detail><error code="bad"/></detail>
    </soap:Fault>
  </soap:Body>
</soap:Envelope>
''');

    expect(fault, isNotNull);
    expect(fault!.code, 'soap:Client');
    expect(fault.reason, 'Bad request');
    expect(fault.detail, contains('error'));
  });

  test('performs SOAP HTTP round trip', () async {
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close();
    });
    unawaited(
      server.forEach((request) async {
        requests.add(await utf8.decoder.bind(request).join());
        expect(request.headers.value('SOAPAction'), '"urn:add"');
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType('text', 'xml', charset: 'utf-8')
          ..write('''
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <AddResponse><result>7</result></AddResponse>
  </soap:Body>
</soap:Envelope>
''');
        await request.response.close();
      }),
    );

    final client = SoapClient('http://127.0.0.1:${server.port}/soap');
    addTearDown(client.close);

    final requestBody =
        XmlDocument.parse('<Add><a>3</a><b>4</b></Add>').rootElement;

    final response = await client.call<int>(
      body: requestBody,
      soapAction: 'urn:add',
      decode: (element) =>
          soapParseInt(
              soapElementText(element.getElementByLocalName('result'))) ??
          0,
    );

    expect(response, 7);
    expect(requests.single, contains('<Add>'));
    expect(requests.single, contains('<a>3</a>'));
  });
}
