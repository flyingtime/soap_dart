// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart' as code;
import 'package:source_gen/source_gen.dart';

import '../annotations/annotations.dart';

final _soapOperationChecker = TypeChecker.fromRuntime(SoapOperation);
final _soapFieldChecker = TypeChecker.fromRuntime(SoapField);
final _soapAttributeChecker = TypeChecker.fromRuntime(SoapAttribute);
final _soapModelChecker = TypeChecker.fromRuntime(SoapModel);

class SoapApiGenerator extends GeneratorForAnnotation<SoapApi> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@SoapApi can only be used on classes.',
        element: element,
      );
    }

    return _SoapApiGenerationContext(element, annotation).generate();
  }
}

final class _SoapApiGenerationContext {
  final ClassElement apiClass;
  final ConstantReader apiAnnotation;
  final _modelHelpers = <String, _ModelHelper>{};
  var _needsRequestBuilder = false;
  var _needsFormat = false;
  var _needsReadElement = false;
  var _needsReadList = false;

  _SoapApiGenerationContext(this.apiClass, this.apiAnnotation);

  String generate() {
    final specs = <code.Spec>[_apiImplementation()];

    for (final helper in _modelHelpers.values) {
      final elementName = _modelElementName(helper.classElement.thisType) ??
          helper.classElement.displayName;
      if (helper.needsToXml) {
        specs.add(_modelToXmlHelper(helper, elementName));
      }
      if (helper.needsFromXml) {
        specs.add(_modelFromXmlHelper(helper));
      }
    }

    specs.addAll(_sharedHelpers());

    final library = code.Library((builder) {
      builder.body.addAll(specs);
    });
    return '${library.accept(code.DartEmitter.scoped())}';
  }

  code.Class _apiImplementation() {
    final endpoint = apiAnnotation.peek('endpoint')?.stringValue;
    final namespace = apiAnnotation.peek('namespace')?.stringValue;
    final apiSoap12 = apiAnnotation.peek('soap12')?.boolValue ?? false;
    final className = apiClass.displayName;
    final implName = '_$className';

    return code.Class((builder) {
      builder
        ..name = implName
        ..modifier = code.ClassModifier.final$
        ..implements.add(_ref(className))
        ..fields.add(
          code.Field((field) {
            field
              ..name = '_client'
              ..type = _ref('SoapClient')
              ..modifier = code.FieldModifier.final$;
          }),
        )
        ..constructors.add(_apiConstructor(implName, endpoint));

      for (final method in apiClass.methods) {
        if (method.isStatic || method.isPrivate) {
          continue;
        }
        final annotationObject = _soapOperationChecker.firstAnnotationOfExact(
          method,
        );
        if (annotationObject == null) {
          continue;
        }
        builder.methods.add(
          _operationMethod(
            method,
            ConstantReader(annotationObject),
            defaultNamespace: namespace,
            defaultSoap12: apiSoap12,
          ),
        );
      }
    });
  }

  code.Constructor _apiConstructor(String implName, String? endpoint) {
    return code.Constructor((builder) {
      if (endpoint == null || endpoint.isEmpty) {
        builder.requiredParameters.add(
          code.Parameter((parameter) {
            parameter
              ..name = '_client'
              ..toThis = true;
          }),
        );
        return;
      }

      builder.optionalParameters.add(
        code.Parameter((parameter) {
          parameter
            ..name = 'client'
            ..type = _ref('SoapClient?');
        }),
      );
      builder.initializers.add(
        code.Code(
          '_client = client ?? SoapClient(${_literal(endpoint)})',
        ),
      );
    });
  }

  code.Method _operationMethod(
    MethodElement method,
    ConstantReader operation, {
    required String? defaultNamespace,
    required bool defaultSoap12,
  }) {
    final futureType = _futureValueType(method);
    if (futureType == null) {
      throw InvalidGenerationSourceError(
        '@SoapOperation methods must return Future<T>.',
        element: method,
      );
    }

    final requestName =
        operation.peek('requestName')?.stringValue ?? method.displayName;
    final responseName = operation.peek('responseName')?.stringValue ??
        _modelElementName(futureType) ??
        '${method.displayName}Response';
    final namespace =
        operation.peek('namespace')?.stringValue ?? defaultNamespace;
    final action = operation.peek('action')?.stringValue;
    final soap12 = operation.peek('soap12')?.boolValue ?? defaultSoap12;
    final bodyExpression = _requestBodyExpression(
      method.parameters,
      requestName: requestName,
      namespace: namespace,
    );
    final decodeExpression = _decodeExpression(futureType, responseName);
    final returnType = _typeCode(futureType);

    return code.Method((builder) {
      builder
        ..name = method.displayName
        ..annotations.add(code.CodeExpression(code.Code('override')))
        ..returns = _ref(_typeCode(method.returnType))
        ..body = code.Code('''
return _client.call<$returnType>(
  body: $bodyExpression,
  soapAction: ${_literalOrNull(action)},
  soap12: $soap12,
  decode: $decodeExpression,
);
''');

      _addMethodParameters(builder, method);
    });
  }

  DartType? _futureValueType(MethodElement method) {
    final returnType = method.returnType;
    if (returnType is! InterfaceType || !returnType.isDartAsyncFuture) {
      return null;
    }
    if (returnType.typeArguments.isEmpty) {
      return null;
    }
    return returnType.typeArguments.single;
  }

  String _requestBodyExpression(
    List<ParameterElement> parameters, {
    required String requestName,
    required String? namespace,
  }) {
    if (parameters.isEmpty) {
      _needsRequestBuilder = true;
      return '_soapBuildRequest(${_literal(requestName)}, '
          'namespace: ${_literalOrNull(namespace)})';
    }

    if (parameters.length == 1) {
      final parameter = parameters.single;
      if (_isXmlElement(parameter.type)) {
        return parameter.displayName;
      }
      if (_isModelLike(parameter.type)) {
        final helper = _ensureModelHelper(parameter.type);
        _markModelToXml(parameter.type);
        return '${helper.toXmlName}(${parameter.displayName}, '
            'name: ${_literal(requestName)}, '
            'namespace: ${_literalOrNull(namespace)})';
      }
    }

    _needsRequestBuilder = true;
    final children = parameters
        .where((parameter) => !_fieldInfo(parameter).attribute)
        .map(
          (parameter) => '_SoapGeneratedEntry('
              '${_literal(_fieldInfo(parameter).name)}, '
              '${parameter.displayName})',
        )
        .join(', ');
    final attributes = parameters
        .where((parameter) => _fieldInfo(parameter).attribute)
        .map(
          (parameter) => '_SoapGeneratedEntry('
              '${_literal(_fieldInfo(parameter).name)}, '
              '${parameter.displayName})',
        )
        .join(', ');
    return '_soapBuildRequest('
        '${_literal(requestName)}, '
        'namespace: ${_literalOrNull(namespace)}, '
        'children: [$children], '
        'attributes: [$attributes])';
  }

  String _decodeExpression(DartType type, String responseName) {
    responseName;
    if (_isVoid(type)) {
      return '(_) {}';
    }
    if (_isXmlElement(type)) {
      return '(element) => element';
    }
    if (_isModelLike(type)) {
      final helper = _ensureModelHelper(type);
      _markModelFromXml(type);
      return helper.fromXmlName;
    }
    return '(element) => ${_readScalarExpression(
      type,
      'soapElementText(element)',
    )}';
  }

  _ModelHelper _ensureModelHelper(DartType type) {
    final element = type.element;
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'SOAP model type ${_typeCode(type)} is not a class.',
        element: apiClass,
      );
    }
    final key = '${element.librarySource.uri}#${element.displayName}';
    return _modelHelpers.putIfAbsent(key, () {
      final helper = _ModelHelper(
        classElement: element,
        typeCode: element.displayName,
        toXmlName: '_${_lowerFirst(element.displayName)}ToSoapXml',
        fromXmlName: '_${_lowerFirst(element.displayName)}FromSoapXml',
      );
      for (final field in element.fields) {
        if (field.isStatic || field.isPrivate || field.isSynthetic) {
          continue;
        }
        final fieldInfo = _fieldInfo(field);
        helper.fields.add(
          _ModelField(
            name: field.displayName,
            xmlName: fieldInfo.name,
            type: field.type,
            attribute: fieldInfo.attribute,
          ),
        );
        if (_isModelLike(field.type)) {
          _ensureModelHelper(_iterableValueType(field.type) ?? field.type);
        }
      }
      return helper;
    });
  }

  void _markModelToXml(DartType type) {
    final valueType = _iterableValueType(type) ?? type;
    if (!_isModelLike(valueType)) {
      return;
    }
    final helper = _ensureModelHelper(valueType)..needsToXml = true;
    for (final field in helper.fields) {
      final fieldType = _iterableValueType(field.type) ?? field.type;
      if (_isModelLike(fieldType)) {
        _markModelToXml(fieldType);
      }
    }
  }

  void _markModelFromXml(DartType type) {
    final valueType = _iterableValueType(type) ?? type;
    if (!_isModelLike(valueType)) {
      return;
    }
    final helper = _ensureModelHelper(valueType)..needsFromXml = true;
    for (final field in helper.fields) {
      final fieldType = _iterableValueType(field.type) ?? field.type;
      if (_isModelLike(fieldType)) {
        _markModelFromXml(fieldType);
      }
    }
  }

  void _addMethodParameters(code.MethodBuilder builder, MethodElement method) {
    for (final parameter in method.parameters) {
      final spec = _parameterSpec(parameter);
      if (parameter.isRequiredPositional) {
        builder.requiredParameters.add(spec);
      } else {
        builder.optionalParameters.add(spec);
      }
    }
  }

  code.Parameter _parameterSpec(ParameterElement parameter) {
    return code.Parameter((builder) {
      builder
        ..name = parameter.displayName
        ..type = _ref(_typeCode(parameter.type))
        ..named = parameter.isNamed
        ..required = parameter.isRequiredNamed;
      final defaultValue = parameter.defaultValueCode;
      if (defaultValue != null) {
        builder.defaultTo = code.Code(defaultValue);
      }
    });
  }

  _FieldInfo _fieldInfo(Element element) {
    final attributeObject = _soapAttributeChecker.firstAnnotationOfExact(
      element,
    );
    if (attributeObject != null) {
      final reader = ConstantReader(attributeObject);
      return _FieldInfo(
        name: reader.peek('name')?.stringValue ?? element.displayName,
        attribute: true,
      );
    }
    final fieldObject = _soapFieldChecker.firstAnnotationOfExact(element);
    if (fieldObject != null) {
      final reader = ConstantReader(fieldObject);
      return _FieldInfo(
        name: reader.peek('name')?.stringValue ?? element.displayName,
        attribute: reader.peek('attribute')?.boolValue ?? false,
      );
    }
    return _FieldInfo(name: element.displayName, attribute: false);
  }

  String? _modelElementName(DartType type) {
    final element = type.element;
    if (element is! ClassElement) {
      return null;
    }
    final object = _soapModelChecker.firstAnnotationOfExact(element);
    if (object == null) {
      return element.displayName;
    }
    return ConstantReader(object).peek('name')?.stringValue ??
        element.displayName;
  }

  code.Method _modelToXmlHelper(_ModelHelper helper, String elementName) {
    final statements = <String>[
      'final builder = XmlBuilder();',
      'builder.element(name ?? ${_literal(elementName)}, nest: () {',
      '  if (namespace != null) {',
      "    builder.attribute('xmlns', namespace);",
      '  }',
    ];

    for (final field in helper.fields.where((field) => field.attribute)) {
      _needsFormat = true;
      statements.add('''
if (value.${field.name} != null) {
  builder.attribute(
    ${_literal(field.xmlName)},
    _soapGeneratedFormat(value.${field.name}!),
  );
}
''');
    }
    for (final field in helper.fields.where((field) => !field.attribute)) {
      if (_isIterable(field.type)) {
        final itemType = _iterableValueType(field.type)!;
        final writer = _writerFunction(itemType);
        statements.add('''
for (final item in value.${field.name}) {
  $writer(builder, ${_literal(field.xmlName)}, item);
}
''');
      } else {
        final writer = _writerFunction(field.type);
        statements.add(
          '$writer(builder, ${_literal(field.xmlName)}, value.${field.name});',
        );
      }
    }

    statements
      ..add('});')
      ..add('return builder.buildDocument().rootElement;');

    return code.Method((builder) {
      builder
        ..name = helper.toXmlName
        ..returns = _ref('XmlElement')
        ..requiredParameters.add(
          code.Parameter((parameter) {
            parameter
              ..name = 'value'
              ..type = _ref(helper.typeCode);
          }),
        )
        ..optionalParameters.addAll([
          code.Parameter((parameter) {
            parameter
              ..name = 'name'
              ..named = true
              ..type = _ref('String?');
          }),
          code.Parameter((parameter) {
            parameter
              ..name = 'namespace'
              ..named = true
              ..type = _ref('String?');
          }),
        ])
        ..body = code.Code(statements.join('\n'));
    });
  }

  code.Method _modelFromXmlHelper(_ModelHelper helper) {
    final statements = <String>['return ${helper.typeCode}('];
    for (final field in helper.fields) {
      statements.add('${field.name}: ${_fieldReadExpression(field)},');
    }
    statements.add(');');

    return code.Method((builder) {
      builder
        ..name = helper.fromXmlName
        ..returns = _ref(helper.typeCode)
        ..requiredParameters.add(
          code.Parameter((parameter) {
            parameter
              ..name = 'element'
              ..type = _ref('XmlElement');
          }),
        )
        ..body = code.Code(statements.join('\n'));
    });
  }

  String _writerFunction(DartType type) {
    if (_isModelLike(type)) {
      final helper = _ensureModelHelper(type);
      return '(builder, name, value) { '
          'if (value != null) { '
          'builder.xml(${helper.toXmlName}(value, name: name).toXmlString()); '
          '} '
          '}';
    }
    _needsFormat = true;
    return '_soapGeneratedWriteElement';
  }

  String _fieldReadExpression(_ModelField field) {
    if (field.attribute) {
      return _readScalarExpression(
        field.type,
        'element.getAttribute(${_literal(field.xmlName)})',
      );
    }

    if (_isIterable(field.type)) {
      final itemType = _iterableValueType(field.type)!;
      _needsReadList = true;
      return '_soapGeneratedReadList(element, ${_literal(field.xmlName)}, '
          '${_readerExpression(itemType)})';
    }

    _needsReadElement = true;
    final expression = '_soapGeneratedReadElement(element, '
        '${_literal(field.xmlName)}, ${_readerExpression(field.type)})';
    return _isNullable(field.type) ? expression : '($expression)!';
  }

  String _readerExpression(DartType type) {
    if (_isModelLike(type)) {
      return _ensureModelHelper(type).fromXmlName;
    }
    return '(element) => ${_readScalarExpression(
      type,
      'soapElementText(element)',
    )}';
  }

  String _readScalarExpression(DartType type, String source) {
    final nullable = _isNullable(type);
    final base = _nonNullableTypeCode(type);
    switch (base) {
      case 'String':
        return nullable ? source : '($source ?? \'\')';
      case 'int':
        return nullable
            ? 'soapParseInt($source)'
            : '(soapParseInt($source) ?? 0)';
      case 'double':
        return nullable
            ? 'soapParseDouble($source)'
            : '(soapParseDouble($source) ?? 0)';
      case 'bool':
        return nullable
            ? 'soapParseBool($source)'
            : '(soapParseBool($source) ?? false)';
      case 'DateTime':
        return nullable
            ? 'soapParseDateTime($source)'
            : '(soapParseDateTime($source) ?? '
                'DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))';
      case 'Duration':
        return nullable
            ? 'soapParseDuration($source)'
            : '(soapParseDuration($source) ?? Duration.zero)';
      case 'List<int>':
        return nullable
            ? 'soapParseBase64($source)'
            : '(soapParseBase64($source) ?? const <int>[])';
      default:
        return nullable ? source : '($source ?? \'\')';
    }
  }

  List<code.Spec> _sharedHelpers() {
    return [
      if (_needsRequestBuilder) ..._requestBuilderHelpers(),
      if (_needsReadElement) _readElementHelper(),
      if (_needsReadList) _readListHelper(),
      if (_needsFormat) ..._formatHelpers(),
    ];
  }

  List<code.Spec> _requestBuilderHelpers() {
    _needsFormat = true;
    return [
      code.Class((builder) {
        builder
          ..name = '_SoapGeneratedEntry'
          ..modifier = code.ClassModifier.final$
          ..fields.addAll([
            code.Field((field) {
              field
                ..name = 'name'
                ..type = _ref('String')
                ..modifier = code.FieldModifier.final$;
            }),
            code.Field((field) {
              field
                ..name = 'value'
                ..type = _ref('Object?')
                ..modifier = code.FieldModifier.final$;
            }),
          ])
          ..constructors.add(
            code.Constructor((constructor) {
              constructor.constant = true;
              constructor.requiredParameters.addAll([
                code.Parameter((parameter) {
                  parameter
                    ..name = 'name'
                    ..toThis = true;
                }),
                code.Parameter((parameter) {
                  parameter
                    ..name = 'value'
                    ..toThis = true;
                }),
              ]);
            }),
          );
      }),
      code.Method((builder) {
        builder
          ..name = '_soapBuildRequest'
          ..returns = _ref('XmlElement')
          ..requiredParameters.add(
            code.Parameter((parameter) {
              parameter
                ..name = 'name'
                ..type = _ref('String');
            }),
          )
          ..optionalParameters.addAll([
            code.Parameter((parameter) {
              parameter
                ..name = 'namespace'
                ..named = true
                ..type = _ref('String?');
            }),
            code.Parameter((parameter) {
              parameter
                ..name = 'children'
                ..named = true
                ..type = _ref('List<_SoapGeneratedEntry>')
                ..defaultTo = code.Code('const []');
            }),
            code.Parameter((parameter) {
              parameter
                ..name = 'attributes'
                ..named = true
                ..type = _ref('List<_SoapGeneratedEntry>')
                ..defaultTo = code.Code('const []');
            }),
          ])
          ..body = code.Code(r'''
final builder = XmlBuilder();
builder.element(name, nest: () {
  if (namespace != null) {
    builder.attribute('xmlns', namespace);
  }
  for (final attribute in attributes) {
    if (attribute.value != null) {
      builder.attribute(
        attribute.name,
        _soapGeneratedFormat(attribute.value!),
      );
    }
  }
  for (final child in children) {
    _soapGeneratedWriteElement(builder, child.name, child.value);
  }
});
return builder.buildDocument().rootElement;
''');
      }),
    ];
  }

  code.Method _readElementHelper() {
    return code.Method((builder) {
      builder
        ..name = '_soapGeneratedReadElement'
        ..types.add(_ref('T'))
        ..returns = _ref('T?')
        ..requiredParameters.addAll([
          code.Parameter((parameter) {
            parameter
              ..name = 'parent'
              ..type = _ref('XmlElement');
          }),
          code.Parameter((parameter) {
            parameter
              ..name = 'name'
              ..type = _ref('String');
          }),
          code.Parameter((parameter) {
            parameter
              ..name = 'read'
              ..type = _ref('T Function(XmlElement element)');
          }),
        ])
        ..body = code.Code('''
final child = parent.getElementByLocalName(name);
return child == null ? null : read(child);
''');
    });
  }

  code.Method _readListHelper() {
    return code.Method((builder) {
      builder
        ..name = '_soapGeneratedReadList'
        ..types.add(_ref('T'))
        ..returns = _ref('List<T>')
        ..requiredParameters.addAll([
          code.Parameter((parameter) {
            parameter
              ..name = 'parent'
              ..type = _ref('XmlElement');
          }),
          code.Parameter((parameter) {
            parameter
              ..name = 'name'
              ..type = _ref('String');
          }),
          code.Parameter((parameter) {
            parameter
              ..name = 'read'
              ..type = _ref('T Function(XmlElement element)');
          }),
        ])
        ..lambda = true
        ..body = code.Code(
          'parent.getElementsByLocalName(name).map(read).toList()',
        );
    });
  }

  List<code.Spec> _formatHelpers() {
    return [
      code.Method((builder) {
        builder
          ..name = '_soapGeneratedWriteElement'
          ..returns = _ref('void')
          ..requiredParameters.addAll([
            code.Parameter((parameter) {
              parameter
                ..name = 'builder'
                ..type = _ref('XmlBuilder');
            }),
            code.Parameter((parameter) {
              parameter
                ..name = 'name'
                ..type = _ref('String');
            }),
            code.Parameter((parameter) {
              parameter
                ..name = 'value'
                ..type = _ref('Object?');
            }),
          ])
          ..body = code.Code(r'''
if (value == null) return;
if (value is XmlElement) {
  builder.xml(value.toXmlString());
  return;
}
if (value is SoapAny) {
  builder.element(name, nest: () {
    builder.xml(value.toXmlString());
  });
  return;
}
builder.element(name, nest: () {
  builder.text(_soapGeneratedFormat(value));
});
''');
      }),
      code.Method((builder) {
        builder
          ..name = '_soapGeneratedFormat'
          ..returns = _ref('String')
          ..requiredParameters.add(
            code.Parameter((parameter) {
              parameter
                ..name = 'value'
                ..type = _ref('Object');
            }),
          )
          ..lambda = true
          ..body = code.Code('soapFormatValue(value)');
      }),
    ];
  }

  bool _isModelLike(DartType type) {
    final valueType = _iterableValueType(type) ?? type;
    if (_isScalar(valueType) ||
        _isVoid(valueType) ||
        _isXmlElement(valueType)) {
      return false;
    }
    if (_typeCode(valueType) == 'SoapAny') {
      return false;
    }
    return valueType.element is ClassElement;
  }

  bool _isScalar(DartType type) {
    final code = _nonNullableTypeCode(type);
    return code == 'String' ||
        code == 'int' ||
        code == 'double' ||
        code == 'bool' ||
        code == 'DateTime' ||
        code == 'Duration' ||
        code == 'List<int>';
  }

  bool _isXmlElement(DartType type) =>
      _nonNullableTypeCode(type) == 'XmlElement';

  bool _isVoid(DartType type) => _typeCode(type) == 'void';

  bool _isIterable(DartType type) =>
      type is InterfaceType &&
      (type.isDartCoreIterable || type.isDartCoreList) &&
      type.typeArguments.isNotEmpty;

  DartType? _iterableValueType(DartType type) =>
      _isIterable(type) ? (type as InterfaceType).typeArguments.single : null;

  bool _isNullable(DartType type) =>
      type.nullabilitySuffix == NullabilitySuffix.question;

  String _typeCode(DartType type) =>
      type.getDisplayString(withNullability: true);

  String _nonNullableTypeCode(DartType type) =>
      type.getDisplayString(withNullability: false);
}

final class _ModelHelper {
  final ClassElement classElement;
  final String typeCode;
  final String toXmlName;
  final String fromXmlName;
  final fields = <_ModelField>[];
  bool needsToXml = false;
  bool needsFromXml = false;

  _ModelHelper({
    required this.classElement,
    required this.typeCode,
    required this.toXmlName,
    required this.fromXmlName,
  });
}

final class _ModelField {
  final String name;
  final String xmlName;
  final DartType type;
  final bool attribute;

  const _ModelField({
    required this.name,
    required this.xmlName,
    required this.type,
    required this.attribute,
  });
}

final class _FieldInfo {
  final String name;
  final bool attribute;

  const _FieldInfo({required this.name, required this.attribute});
}

code.Reference _ref(String symbol) => code.Reference(symbol);

String _literal(String value) => _escapeString(value);

String _literalOrNull(String? value) =>
    value == null ? 'null' : _literal(value);

String _escapeString(String value) =>
    "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

String _lowerFirst(String value) => value.isEmpty
    ? value
    : value.substring(0, 1).toLowerCase() + value.substring(1);
