import 'dart:io';

import 'package:soap_dart/soap_dart.dart';
import 'package:test/test.dart';

void main() {
  test('generates Dart models and typed client methods', () async {
    final document =
        await WsdlParser().parseFile('test/fixtures/calculator.wsdl');
    final code = const WsdlDartGenerator().generate(document);

    expect(code, contains('final class Add implements SoapSerializable'));
    expect(
        code, contains('final class AddResponse implements SoapSerializable'));
    expect(code, contains('typedef Mode = String;'));
    expect(code, contains('static const Mode fast = "fast";'));
    expect(code, contains('final class CalculatorPortTypeClient'));
    expect(code, contains('Future<AddResponse> add('));
    expect(code, contains('Add request,'));
    expect(code, contains('soapAction: "http://example.com/calculator/Add"'));
  });

  test('generated code can be formatted by dart format', () async {
    final document =
        await WsdlParser().parseFile('test/fixtures/calculator.wsdl');
    final code = const WsdlDartGenerator().generate(document);
    final dir = await Directory.systemTemp.createTemp('soap_dart_codegen_');
    addTearDown(() async {
      await dir.delete(recursive: true);
    });
    final generated = File('${dir.path}/calculator.dart');
    await generated.writeAsString(code);

    final result = await Process.run('dart', ['format', generated.path]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('generates valid classes for empty complex types', () async {
    final document = WsdlParser().parse('''
<definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
    xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
    xmlns:tns="urn:empty"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    targetNamespace="urn:empty">
  <types>
    <xsd:schema targetNamespace="urn:empty">
      <xsd:element name="Ping" type="tns:PingType"/>
      <xsd:element name="PingResponse" type="tns:PingResponseType"/>
      <xsd:complexType name="PingType"/>
      <xsd:complexType name="PingResponseType">
        <xsd:sequence>
          <xsd:element name="message" type="xsd:string"/>
        </xsd:sequence>
      </xsd:complexType>
    </xsd:schema>
  </types>
  <message name="PingRequest">
    <part name="parameters" element="tns:Ping"/>
  </message>
  <message name="PingResponseMessage">
    <part name="parameters" element="tns:PingResponse"/>
  </message>
  <portType name="PingPortType">
    <operation name="Ping">
      <input message="tns:PingRequest"/>
      <output message="tns:PingResponseMessage"/>
    </operation>
  </portType>
  <binding name="PingBinding" type="tns:PingPortType">
    <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
    <operation name="Ping">
      <soap:operation soapAction="urn:empty/Ping"/>
      <input>
        <soap:body use="literal"/>
      </input>
      <output>
        <soap:body use="literal"/>
      </output>
    </operation>
  </binding>
</definitions>
''');
    final code = const WsdlDartGenerator().generate(document);

    expect(code, contains('final class PingType implements SoapSerializable'));
    expect(code, contains('const PingType();'));
    expect(code, contains('=> const PingType();'));
    expect(code, isNot(contains('const PingType({')));

    final dir = await Directory.systemTemp.createTemp('soap_dart_codegen_');
    addTearDown(() async {
      await dir.delete(recursive: true);
    });
    final generated = File('${dir.path}/empty.dart');
    await generated.writeAsString(code);

    final result = await Process.run('dart', ['format', generated.path]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
