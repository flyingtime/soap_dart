import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'model.dart';

typedef WsdlImportResolver = FutureOr<String> Function(Uri uri);

final class WsdlParser {
  final WsdlImportResolver? importResolver;
  final http.Client? httpClient;
  final Set<Uri> _seen = {};

  WsdlParser({this.importResolver, this.httpClient});

  WsdlDocument parse(String source) => _parseXml(source);

  Future<WsdlDocument> parseFile(String path) async {
    final file = File(path);
    final baseUri = file.absolute.uri;
    final text = await file.readAsString();
    return parseWithImports(text, baseUri: baseUri);
  }

  Future<WsdlDocument> parseUri(Uri uri) async {
    final text = await _readUri(uri);
    return parseWithImports(text, baseUri: uri);
  }

  Future<WsdlDocument> parseWithImports(String source, {Uri? baseUri}) async {
    final root = _parseXml(source);
    var merged = root;

    for (final import in root.imports) {
      final location = import.location;
      if (location == null || location.isEmpty) {
        continue;
      }
      final imported = await _parseImportedDocument(location, baseUri);
      merged = merged.merge(imported);
    }

    final mergedSchemas = <XsdSchema>[];
    for (final schema in merged.schemas) {
      mergedSchemas.add(schema);
      for (final import in schema.imports) {
        final location = import.location;
        if (location == null || location.isEmpty) {
          continue;
        }
        mergedSchemas.add(await _parseImportedSchema(location, baseUri));
      }
      for (final include in schema.includes) {
        final location = include.location;
        if (location == null || location.isEmpty) {
          continue;
        }
        mergedSchemas.add(await _parseImportedSchema(location, baseUri));
      }
    }

    return WsdlDocument(
      name: merged.name,
      targetNamespace: merged.targetNamespace,
      namespaces: merged.namespaces,
      imports: merged.imports,
      schemas: mergedSchemas,
      messages: merged.messages,
      portTypes: merged.portTypes,
      bindings: merged.bindings,
      services: merged.services,
    );
  }

  WsdlDocument _parseXml(String source) {
    final document = XmlDocument.parse(source);
    final root = document.rootElement;
    final namespaces = _namespaces(root);
    final types = root.firstChildElement('types');
    final schemas = types == null
        ? <XsdSchema>[]
        : types.childElementsByLocalName('schema').map(_parseSchema).toList();

    return WsdlDocument(
      name: root.getAttribute('name'),
      targetNamespace: root.getAttribute('targetNamespace'),
      namespaces: namespaces,
      imports: root
          .childElementsByLocalName('import')
          .map(
            (element) => WsdlImport(
              namespace: element.getAttribute('namespace'),
              location: element.getAttribute('location'),
            ),
          )
          .toList(),
      schemas: schemas,
      messages:
          root.childElementsByLocalName('message').map(_parseMessage).toList(),
      portTypes: root
          .childElementsByLocalName('portType')
          .map(_parsePortType)
          .toList(),
      bindings:
          root.childElementsByLocalName('binding').map(_parseBinding).toList(),
      services:
          root.childElementsByLocalName('service').map(_parseService).toList(),
    );
  }

  Future<WsdlDocument> _parseImportedDocument(
      String location, Uri? baseUri) async {
    final uri = _resolveUri(location, baseUri);
    if (!_seen.add(uri)) {
      return const WsdlDocument();
    }
    final text = await _readUri(uri);
    return parseWithImports(text, baseUri: uri);
  }

  Future<XsdSchema> _parseImportedSchema(String location, Uri? baseUri) async {
    final uri = _resolveUri(location, baseUri);
    if (!_seen.add(uri)) {
      return const XsdSchema();
    }
    final text = await _readUri(uri);
    final root = XmlDocument.parse(text).rootElement;
    if (root.name.local == 'schema') {
      return _parseSchema(root);
    }
    final doc = await parseWithImports(text, baseUri: uri);
    return doc.schemas.isEmpty ? const XsdSchema() : doc.schemas.first;
  }

  Future<String> _readUri(Uri uri) async {
    final resolved = importResolver?.call(uri);
    if (resolved != null) {
      return await resolved;
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final client = httpClient ?? http.Client();
      final response = await client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Failed to load $uri: HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      return utf8.decode(response.bodyBytes);
    }
    return File.fromUri(uri).readAsString();
  }

  Uri _resolveUri(String location, Uri? baseUri) {
    final uri = Uri.parse(location);
    if (uri.scheme.isNotEmpty) {
      return uri;
    }
    if (baseUri == null) {
      return File(location).absolute.uri;
    }
    if (baseUri.scheme == 'file') {
      final basePath = File.fromUri(baseUri).parent.path;
      return File(p.normalize(p.join(basePath, location))).absolute.uri;
    }
    return baseUri.resolve(location);
  }

  XsdSchema _parseSchema(XmlElement element) {
    final targetNamespace = element.getAttribute('targetNamespace');
    return XsdSchema(
      targetNamespace: targetNamespace,
      namespaces: _namespaces(element),
      imports: element
          .childElementsByLocalName('import')
          .map(
            (item) => XsdSchemaImport(
              namespace: item.getAttribute('namespace'),
              location: item.getAttribute('schemaLocation'),
            ),
          )
          .toList(),
      includes: element
          .childElementsByLocalName('include')
          .map(
            (item) => XsdSchemaInclude(
              namespace: item.getAttribute('namespace'),
              location: item.getAttribute('schemaLocation'),
            ),
          )
          .toList(),
      simpleTypes: element
          .childElementsByLocalName('simpleType')
          .map((item) => _parseSimpleType(item, targetNamespace))
          .toList(),
      complexTypes: element
          .childElementsByLocalName('complexType')
          .map((item) => _parseComplexType(item, targetNamespace))
          .toList(),
      elements: element
          .childElementsByLocalName('element')
          .map(_parseElement)
          .toList(),
    );
  }

  XsdSimpleType _parseSimpleType(XmlElement element, String? targetNamespace) {
    final restriction = element.firstChildElement('restriction');
    final union = element.firstChildElement('union');
    return XsdSimpleType(
      name: element.getAttribute('name'),
      targetNamespace: targetNamespace,
      restriction: restriction == null ? null : _parseRestriction(restriction),
      union: union == null
          ? null
          : XsdUnion(
              memberTypes: (union.getAttribute('memberTypes') ?? '')
                  .split(RegExp(r'\s+'))
                  .where((value) => value.isNotEmpty)
                  .toList(),
            ),
    );
  }

  XsdRestriction _parseRestriction(XmlElement element) => XsdRestriction(
        base: element.getAttribute('base'),
        enumerations: element
            .childElementsByLocalName('enumeration')
            .map((item) => item.getAttribute('value'))
            .nonNulls
            .toList(),
        attributes: element
            .childElementsByLocalName('attribute')
            .map(_parseAttribute)
            .toList(),
      );

  XsdComplexType _parseComplexType(
      XmlElement element, String? targetNamespace) {
    final complexContent = element.firstChildElement('complexContent');
    final simpleContent = element.firstChildElement('simpleContent');
    return XsdComplexType(
      name: element.getAttribute('name'),
      abstract: _parseBool(element.getAttribute('abstract')) ?? false,
      documentation: element
          .firstChildElement('annotation')
          ?.firstChildElement('documentation')
          ?.innerText
          .trim(),
      targetNamespace: targetNamespace,
      allElements: element
              .firstChildElement('all')
              ?.childElementsByLocalName('element')
              .map(_parseElement)
              .toList() ??
          const [],
      sequence: _parseSequence(element.firstChildElement('sequence')),
      choice: _parseChoice(element.firstChildElement('choice')),
      complexContent:
          complexContent == null ? null : _parseComplexContent(complexContent),
      simpleContent:
          simpleContent == null ? null : _parseSimpleContent(simpleContent),
      attributes: element
          .childElementsByLocalName('attribute')
          .map(_parseAttribute)
          .toList(),
    );
  }

  XsdComplexContent _parseComplexContent(XmlElement element) {
    final extension = element.firstChildElement('extension');
    final restriction = element.firstChildElement('restriction');
    return XsdComplexContent(
      extension: extension == null ? null : _parseExtension(extension),
      restriction: restriction == null ? null : _parseRestriction(restriction),
    );
  }

  XsdSimpleContent _parseSimpleContent(XmlElement element) {
    final extension = element.firstChildElement('extension');
    final restriction = element.firstChildElement('restriction');
    return XsdSimpleContent(
      extension: extension == null ? null : _parseExtension(extension),
      restriction: restriction == null ? null : _parseRestriction(restriction),
    );
  }

  XsdExtension _parseExtension(XmlElement element) => XsdExtension(
        base: element.getAttribute('base'),
        sequence: _parseSequence(element.firstChildElement('sequence')),
        choice: _parseChoice(element.firstChildElement('choice')),
        attributes: element
            .childElementsByLocalName('attribute')
            .map(_parseAttribute)
            .toList(),
      );

  XsdSequence? _parseSequence(XmlElement? element) {
    if (element == null) {
      return null;
    }
    return XsdSequence(
      complexTypes: element
          .childElementsByLocalName('complexType')
          .map((item) => _parseComplexType(item, null))
          .toList(),
      elements: element
          .childElementsByLocalName('element')
          .map(_parseElement)
          .toList(),
      choices: element
          .childElementsByLocalName('choice')
          .map(_parseChoice)
          .nonNulls
          .toList(),
      any: element.childElementsByLocalName('any').map(_parseAny).toList(),
    );
  }

  XsdChoice? _parseChoice(XmlElement? element) {
    if (element == null) {
      return null;
    }
    return XsdChoice(
      complexTypes: element
          .childElementsByLocalName('complexType')
          .map((item) => _parseComplexType(item, null))
          .toList(),
      elements: element
          .childElementsByLocalName('element')
          .map(_parseElement)
          .toList(),
      any: element.childElementsByLocalName('any').map(_parseAny).toList(),
    );
  }

  XsdElement _parseElement(XmlElement element) => XsdElement(
        name: element.getAttribute('name'),
        ref: element.getAttribute('ref'),
        type: element.getAttribute('type'),
        minOccurs: _parseOccurs(element.getAttribute('minOccurs')),
        maxOccurs: element.getAttribute('maxOccurs'),
        nillable: _parseBool(element.getAttribute('nillable')) ?? false,
        complexType: element.firstChildElement('complexType') == null
            ? null
            : _parseComplexType(
                element.firstChildElement('complexType')!, null),
        simpleType: element.firstChildElement('simpleType') == null
            ? null
            : _parseSimpleType(element.firstChildElement('simpleType')!, null),
      );

  XsdAttribute _parseAttribute(XmlElement element) => XsdAttribute(
        name: element.getAttribute('name'),
        ref: element.getAttribute('ref'),
        type: element.getAttribute('type'),
        arrayType: element.getAttribute('arrayType') ??
            element.getAttribute('arrayType',
                namespace: 'http://schemas.xmlsoap.org/wsdl/'),
        minOccurs: _parseOccurs(element.getAttribute('minOccurs')),
        maxOccurs: element.getAttribute('maxOccurs'),
        nillable: _parseBool(element.getAttribute('nillable')) ?? false,
        use: element.getAttribute('use'),
      );

  XsdAny _parseAny(XmlElement element) => XsdAny(
        minOccurs: _parseOccurs(element.getAttribute('minOccurs')),
        maxOccurs: element.getAttribute('maxOccurs'),
      );

  WsdlMessage _parseMessage(XmlElement element) => WsdlMessage(
        name: element.getAttribute('name') ?? '',
        parts: element
            .childElementsByLocalName('part')
            .map(
              (part) => WsdlPart(
                name: part.getAttribute('name'),
                type: part.getAttribute('type'),
                element: part.getAttribute('element'),
              ),
            )
            .toList(),
      );

  WsdlPortType _parsePortType(XmlElement element) => WsdlPortType(
        name: element.getAttribute('name') ?? '',
        operations: element
            .childElementsByLocalName('operation')
            .map(_parseOperation)
            .toList(),
      );

  WsdlOperation _parseOperation(XmlElement element) => WsdlOperation(
        name: element.getAttribute('name') ?? '',
        documentation:
            element.firstChildElement('documentation')?.innerText.trim(),
        input: _parseIo(element.firstChildElement('input')),
        output: _parseIo(element.firstChildElement('output')),
        faults: element
            .childElementsByLocalName('fault')
            .map(_parseIo)
            .nonNulls
            .toList(),
      );

  WsdlOperationIo? _parseIo(XmlElement? element) => element == null
      ? null
      : WsdlOperationIo(
          name: element.getAttribute('name'),
          message: element.getAttribute('message'),
        );

  WsdlBinding _parseBinding(XmlElement element) {
    final binding = element.childElements.firstWhereOrNull(
      (child) =>
          child.name.local == 'binding' &&
          (child.name.namespaceUri == soap11WsdlNamespace ||
              child.name.namespaceUri == soap12WsdlNamespace ||
              child.name.prefix == 'soap' ||
              child.name.prefix == 'soap12'),
    );
    return WsdlBinding(
      name: element.getAttribute('name') ?? '',
      type: element.getAttribute('type'),
      style: binding?.getAttribute('style'),
      transport: binding?.getAttribute('transport'),
      operations: element
          .childElementsByLocalName('operation')
          .map(_parseBindingOperation)
          .toList(),
    );
  }

  WsdlBindingOperation _parseBindingOperation(XmlElement element) {
    final soapOperation = element.childElements.firstWhereOrNull(
      (child) =>
          child.name.local == 'operation' &&
          (child.name.namespaceUri == soap11WsdlNamespace ||
              child.name.namespaceUri == soap12WsdlNamespace ||
              child.name.prefix == 'soap' ||
              child.name.prefix == 'soap12'),
    );
    final isSoap12 = soapOperation?.name.namespaceUri == soap12WsdlNamespace ||
        soapOperation?.name.prefix == 'soap12';
    return WsdlBindingOperation(
      name: element.getAttribute('name') ?? '',
      soapAction: soapOperation?.getAttribute('soapAction'),
      soap12: isSoap12,
      input: _parseBindingIo(element.firstChildElement('input')),
      output: _parseBindingIo(element.firstChildElement('output')),
      faults: element.childElementsByLocalName('fault').map(
        (fault) {
          final body = fault.childElements.firstWhereOrNull(
            (child) => child.name.local == 'body',
          );
          return WsdlBindingFault(
            name: fault.getAttribute('name'),
            body: _parseSoapBody(body),
          );
        },
      ).toList(),
    );
  }

  WsdlBindingIo? _parseBindingIo(XmlElement? element) {
    if (element == null) {
      return null;
    }
    final body = element.childElements.firstWhereOrNull(
      (child) => child.name.local == 'body',
    );
    return _parseSoapBody(body);
  }

  WsdlBindingIo? _parseSoapBody(XmlElement? element) => element == null
      ? null
      : WsdlBindingIo(
          parts: element.getAttribute('parts'),
          use: element.getAttribute('use'),
          namespace: element.getAttribute('namespace'),
        );

  WsdlService _parseService(XmlElement element) => WsdlService(
        name: element.getAttribute('name'),
        documentation:
            element.firstChildElement('documentation')?.innerText.trim(),
        ports:
            element.childElementsByLocalName('port').map(_parsePort).toList(),
      );

  WsdlPort _parsePort(XmlElement element) {
    final address = element.childElements.firstWhereOrNull(
      (child) => child.name.local == 'address',
    );
    return WsdlPort(
      name: element.getAttribute('name'),
      binding: element.getAttribute('binding'),
      address: address?.getAttribute('location'),
    );
  }
}

Map<String, String> _namespaces(XmlElement element) {
  final result = <String, String>{};
  for (final attr in element.attributes) {
    if (attr.name.local == 'xmlns' && attr.name.prefix == null) {
      result[''] = attr.value;
    } else if (attr.name.prefix == 'xmlns') {
      result[attr.name.local] = attr.value;
    }
  }
  return result;
}

int _parseOccurs(String? value) => value == null ? 1 : int.tryParse(value) ?? 1;

bool? _parseBool(String? value) {
  if (value == null) {
    return null;
  }
  return value == 'true' || value == '1';
}

extension _XmlElementSearch on XmlElement {
  Iterable<XmlElement> childElementsByLocalName(String localName) sync* {
    for (final child in childElements) {
      if (child.name.local == localName) {
        yield child;
      }
    }
  }

  XmlElement? firstChildElement(String localName) {
    for (final child in childElements) {
      if (child.name.local == localName) {
        return child;
      }
    }
    return null;
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T value) test) {
    for (final value in this) {
      if (test(value)) {
        return value;
      }
    }
    return null;
  }
}
