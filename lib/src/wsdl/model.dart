const wsdlNamespace = 'http://schemas.xmlsoap.org/wsdl/';
const xsdSchemaNamespace = 'http://www.w3.org/2001/XMLSchema';
const soap11WsdlNamespace = 'http://schemas.xmlsoap.org/wsdl/soap/';
const soap12WsdlNamespace = 'http://schemas.xmlsoap.org/wsdl/soap12/';

final class WsdlDocument {
  final String? name;
  final String? targetNamespace;
  final Map<String, String> namespaces;
  final List<WsdlImport> imports;
  final List<XsdSchema> schemas;
  final List<WsdlMessage> messages;
  final List<WsdlPortType> portTypes;
  final List<WsdlBinding> bindings;
  final List<WsdlService> services;

  const WsdlDocument({
    this.name,
    this.targetNamespace,
    this.namespaces = const {},
    this.imports = const [],
    this.schemas = const [],
    this.messages = const [],
    this.portTypes = const [],
    this.bindings = const [],
    this.services = const [],
  });

  List<XsdSimpleType> get simpleTypes =>
      schemas.expand((schema) => schema.simpleTypes).toList(growable: false);

  List<XsdComplexType> get complexTypes =>
      schemas.expand((schema) => schema.complexTypes).toList(growable: false);

  List<XsdElement> get elements =>
      schemas.expand((schema) => schema.elements).toList(growable: false);

  WsdlDocument merge(WsdlDocument other) => WsdlDocument(
        name: name ?? other.name,
        targetNamespace: targetNamespace ?? other.targetNamespace,
        namespaces: {...other.namespaces, ...namespaces},
        imports: [...imports, ...other.imports],
        schemas: [...schemas, ...other.schemas],
        messages: [...messages, ...other.messages],
        portTypes: [...portTypes, ...other.portTypes],
        bindings: [...bindings, ...other.bindings],
        services: [...services, ...other.services],
      );
}

final class WsdlImport {
  final String? namespace;
  final String? location;

  const WsdlImport({this.namespace, this.location});
}

final class WsdlService {
  final String? name;
  final String? documentation;
  final List<WsdlPort> ports;

  const WsdlService({this.name, this.documentation, this.ports = const []});
}

final class WsdlPort {
  final String? name;
  final String? binding;
  final String? address;

  const WsdlPort({this.name, this.binding, this.address});
}

final class XsdSchema {
  final String? targetNamespace;
  final Map<String, String> namespaces;
  final List<XsdSchemaImport> imports;
  final List<XsdSchemaInclude> includes;
  final List<XsdSimpleType> simpleTypes;
  final List<XsdComplexType> complexTypes;
  final List<XsdElement> elements;

  const XsdSchema({
    this.targetNamespace,
    this.namespaces = const {},
    this.imports = const [],
    this.includes = const [],
    this.simpleTypes = const [],
    this.complexTypes = const [],
    this.elements = const [],
  });

  XsdSchema copyWith({
    String? targetNamespace,
    Map<String, String>? namespaces,
    List<XsdSchemaImport>? imports,
    List<XsdSchemaInclude>? includes,
    List<XsdSimpleType>? simpleTypes,
    List<XsdComplexType>? complexTypes,
    List<XsdElement>? elements,
  }) =>
      XsdSchema(
        targetNamespace: targetNamespace ?? this.targetNamespace,
        namespaces: namespaces ?? this.namespaces,
        imports: imports ?? this.imports,
        includes: includes ?? this.includes,
        simpleTypes: simpleTypes ?? this.simpleTypes,
        complexTypes: complexTypes ?? this.complexTypes,
        elements: elements ?? this.elements,
      );
}

final class XsdSchemaImport {
  final String? namespace;
  final String? location;

  const XsdSchemaImport({this.namespace, this.location});
}

final class XsdSchemaInclude {
  final String? namespace;
  final String? location;

  const XsdSchemaInclude({this.namespace, this.location});
}

final class XsdSimpleType {
  final String? name;
  final XsdRestriction? restriction;
  final XsdUnion? union;
  final String? targetNamespace;

  const XsdSimpleType({
    this.name,
    this.restriction,
    this.union,
    this.targetNamespace,
  });
}

final class XsdUnion {
  final List<String> memberTypes;

  const XsdUnion({this.memberTypes = const []});
}

final class XsdRestriction {
  final String? base;
  final List<String> enumerations;
  final List<XsdAttribute> attributes;

  const XsdRestriction({
    this.base,
    this.enumerations = const [],
    this.attributes = const [],
  });
}

final class XsdComplexType {
  final String? name;
  final bool abstract;
  final String? documentation;
  final XsdSequence? sequence;
  final XsdChoice? choice;
  final List<XsdElement> allElements;
  final XsdComplexContent? complexContent;
  final XsdSimpleContent? simpleContent;
  final List<XsdAttribute> attributes;
  final String? targetNamespace;

  const XsdComplexType({
    this.name,
    this.abstract = false,
    this.documentation,
    this.sequence,
    this.choice,
    this.allElements = const [],
    this.complexContent,
    this.simpleContent,
    this.attributes = const [],
    this.targetNamespace,
  });
}

final class XsdSimpleContent {
  final XsdExtension? extension;
  final XsdRestriction? restriction;

  const XsdSimpleContent({this.extension, this.restriction});
}

final class XsdComplexContent {
  final XsdExtension? extension;
  final XsdRestriction? restriction;

  const XsdComplexContent({this.extension, this.restriction});
}

final class XsdExtension {
  final String? base;
  final XsdSequence? sequence;
  final XsdChoice? choice;
  final List<XsdAttribute> attributes;

  const XsdExtension({
    this.base,
    this.sequence,
    this.choice,
    this.attributes = const [],
  });
}

final class XsdSequence {
  final List<XsdComplexType> complexTypes;
  final List<XsdElement> elements;
  final List<XsdChoice> choices;
  final List<XsdAny> any;

  const XsdSequence({
    this.complexTypes = const [],
    this.elements = const [],
    this.choices = const [],
    this.any = const [],
  });
}

final class XsdChoice {
  final List<XsdComplexType> complexTypes;
  final List<XsdElement> elements;
  final List<XsdAny> any;

  const XsdChoice({
    this.complexTypes = const [],
    this.elements = const [],
    this.any = const [],
  });
}

final class XsdAttribute {
  final String? name;
  final String? ref;
  final String? type;
  final String? arrayType;
  final int minOccurs;
  final String? maxOccurs;
  final bool nillable;
  final String? use;

  const XsdAttribute({
    this.name,
    this.ref,
    this.type,
    this.arrayType,
    this.minOccurs = 1,
    this.maxOccurs,
    this.nillable = false,
    this.use,
  });
}

final class XsdElement {
  final String? name;
  final String? ref;
  final String? type;
  final int minOccurs;
  final String? maxOccurs;
  final bool nillable;
  final XsdComplexType? complexType;
  final XsdSimpleType? simpleType;

  const XsdElement({
    this.name,
    this.ref,
    this.type,
    this.minOccurs = 1,
    this.maxOccurs,
    this.nillable = false,
    this.complexType,
    this.simpleType,
  });

  bool get isMany =>
      maxOccurs == 'unbounded' || (int.tryParse(maxOccurs ?? '') ?? 1) > 1;
}

final class XsdAny {
  final int minOccurs;
  final String? maxOccurs;

  const XsdAny({this.minOccurs = 1, this.maxOccurs});
}

final class WsdlMessage {
  final String name;
  final List<WsdlPart> parts;

  const WsdlMessage({required this.name, this.parts = const []});
}

final class WsdlPart {
  final String? name;
  final String? type;
  final String? element;

  const WsdlPart({this.name, this.type, this.element});
}

final class WsdlPortType {
  final String name;
  final List<WsdlOperation> operations;

  const WsdlPortType({required this.name, this.operations = const []});
}

final class WsdlOperation {
  final String name;
  final String? documentation;
  final WsdlOperationIo? input;
  final WsdlOperationIo? output;
  final List<WsdlOperationIo> faults;

  const WsdlOperation({
    required this.name,
    this.documentation,
    this.input,
    this.output,
    this.faults = const [],
  });
}

final class WsdlOperationIo {
  final String? name;
  final String? message;

  const WsdlOperationIo({this.name, this.message});
}

final class WsdlBinding {
  final String name;
  final String? type;
  final String? style;
  final String? transport;
  final List<WsdlBindingOperation> operations;

  const WsdlBinding({
    required this.name,
    this.type,
    this.style,
    this.transport,
    this.operations = const [],
  });
}

final class WsdlBindingOperation {
  final String name;
  final String? soapAction;
  final bool soap12;
  final WsdlBindingIo? input;
  final WsdlBindingIo? output;
  final List<WsdlBindingFault> faults;

  const WsdlBindingOperation({
    required this.name,
    this.soapAction,
    this.soap12 = false,
    this.input,
    this.output,
    this.faults = const [],
  });
}

final class WsdlBindingFault {
  final String? name;
  final WsdlBindingIo? body;

  const WsdlBindingFault({this.name, this.body});
}

final class WsdlBindingIo {
  final String? parts;
  final String? use;
  final String? namespace;

  const WsdlBindingIo({this.parts, this.use, this.namespace});
}

String trimNamespace(String value) {
  final index = value.indexOf(':');
  return index == -1 ? value : value.substring(index + 1);
}

String? trimNamespaceOrNull(String? value) =>
    value == null ? null : trimNamespace(value);
