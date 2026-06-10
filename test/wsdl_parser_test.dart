import 'dart:io';

import 'package:soap_dart/soap_dart.dart';
import 'package:test/test.dart';

void main() {
  test('parses WSDL definitions, schema, and SOAP bindings', () async {
    final document =
        await WsdlParser().parseFile('test/fixtures/calculator.wsdl');

    expect(document.name, 'Calculator');
    expect(document.targetNamespace, 'http://example.com/calculator');
    expect(document.schemas, hasLength(1));
    expect(document.elements.map((element) => element.name),
        containsAll(['Add', 'AddResponse']));
    expect(document.simpleTypes.single.name, 'Mode');
    expect(document.messages, hasLength(2));
    expect(document.portTypes.single.operations.single.name, 'Add');
    expect(document.bindings.single.operations.single.soapAction,
        'http://example.com/calculator/Add');
    expect(document.services.single.ports.single.address,
        'http://example.com/calculator');
  });

  test('merges imported schema files', () async {
    final dir = await Directory.systemTemp.createTemp('soap_dart_wsdl_');
    addTearDown(() async {
      await dir.delete(recursive: true);
    });

    await File('${dir.path}/types.xsd').writeAsString('''
<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:types">
  <xsd:complexType name="ImportedType">
    <xsd:sequence>
      <xsd:element name="value" type="xsd:string"/>
    </xsd:sequence>
  </xsd:complexType>
</xsd:schema>
''');
    await File('${dir.path}/service.wsdl').writeAsString('''
<definitions xmlns="http://schemas.xmlsoap.org/wsdl/" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <types>
    <xsd:schema>
      <xsd:import namespace="urn:types" schemaLocation="types.xsd"/>
    </xsd:schema>
  </types>
</definitions>
''');

    final document = await WsdlParser().parseFile('${dir.path}/service.wsdl');

    expect(document.complexTypes.map((type) => type.name),
        contains('ImportedType'));
  });
}
