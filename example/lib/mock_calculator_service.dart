import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soap_dart/soap_dart.dart';

import 'calculator_api.dart';

class CalculatorSoapHarness {
  final CalculatorApi api;
  final List<String> requests;

  const CalculatorSoapHarness({required this.api, required this.requests});
}

CalculatorSoapHarness createCalculatorSoapHarness() {
  final requests = <String>[];
  final httpClient = MockClient((request) async {
    final body = request.body;
    requests.add(body);

    final document = XmlDocument.parse(body);
    final payload = soapBodyElement(document).childElements.first;
    final a = _readInt(payload, 'a');
    final b = _readInt(payload, 'b');

    if (payload.name.local == 'Multiply') {
      return _soapResponse('<MultiplyResponse>${a * b}</MultiplyResponse>');
    }
    return _soapResponse(
      '<AddResponse><result>${a + b}</result></AddResponse>',
    );
  });

  final client = SoapClient(
    'https://example.invalid/soap',
    httpClient: httpClient,
  );
  return CalculatorSoapHarness(api: CalculatorApi(client), requests: requests);
}

int _readInt(XmlElement parent, String name) {
  final text = soapElementText(parent.getElementByLocalName(name));
  return int.tryParse(text ?? '') ?? 0;
}

http.Response _soapResponse(String body) {
  return http.Response(
    '''
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    $body
  </soap:Body>
</soap:Envelope>
''',
    200,
    headers: const {'content-type': 'text/xml; charset=utf-8'},
  );
}
