import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:soap_dart/soap_dart.dart';
import 'package:test/test.dart';

import 'fixtures/annotated_api.dart';

void main() {
  test('generated annotation client sends SOAP and maps model responses',
      () async {
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close();
    });

    unawaited(
      server.forEach((request) async {
        final body = await utf8.decoder.bind(request).join();
        requests.add(body);
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
        if (body.contains('<Add')) {
          request.response.write('''
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <AddResponse><result>9</result></AddResponse>
  </soap:Body>
</soap:Envelope>
''');
        } else {
          request.response.write('''
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <MultiplyResponse>12</MultiplyResponse>
  </soap:Body>
</soap:Envelope>
''');
        }
        await request.response.close();
      }),
    );

    final client = SoapClient('http://127.0.0.1:${server.port}/soap');
    addTearDown(client.close);
    final api = CalculatorApi(client);

    final add = await api.add(const AddRequest(a: 4, b: 5));
    final multiply = await api.multiply(3, 4);

    expect(add.value, 9);
    expect(multiply, 12);
    expect(requests.first, contains('<Add'));
    expect(requests.first, contains('<a>4</a>'));
    expect(requests.first, contains('<b>5</b>'));
    expect(requests.last, contains('<Multiply'));
    expect(requests.last, contains('<a>3</a>'));
    expect(requests.last, contains('<b>4</b>'));
  });
}
