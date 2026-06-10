/// Marks an abstract class as a SOAP API for build_runner generation.
class SoapApi {
  /// Optional endpoint override. When set, the generated implementation creates
  /// its own [SoapClient] from this endpoint if constructed with no client.
  final String? endpoint;

  /// Default XML namespace for request body elements.
  final String? namespace;

  /// Whether operations use SOAP 1.2 by default.
  final bool soap12;

  const SoapApi({this.endpoint, this.namespace, this.soap12 = false});
}

/// Marks an abstract method as a SOAP operation.
class SoapOperation {
  /// SOAPAction header value for SOAP 1.1, or action content type parameter for
  /// SOAP 1.2.
  final String? action;

  /// Request wrapper element name. Defaults to the Dart method name.
  final String? requestName;

  /// Response wrapper element name. Defaults to the return model annotation or
  /// `<methodName>Response`.
  final String? responseName;

  /// Operation-specific XML namespace.
  final String? namespace;

  /// Operation-specific SOAP version override.
  final bool? soap12;

  const SoapOperation({
    this.action,
    this.requestName,
    this.responseName,
    this.namespace,
    this.soap12,
  });
}

/// Marks a class as an XML model that can be serialized/deserialized by the
/// generated SOAP client.
class SoapModel {
  /// XML element name. Defaults to the class name.
  final String? name;

  const SoapModel({this.name});
}

/// Customizes XML mapping for a field or method parameter.
class SoapField {
  /// XML element or attribute name. Defaults to the Dart field/parameter name.
  final String? name;

  /// Maps this value as an XML attribute instead of a child element.
  final bool attribute;

  const SoapField({this.name, this.attribute = false});
}

/// Convenience annotation for XML attributes.
class SoapAttribute extends SoapField {
  const SoapAttribute({super.name}) : super(attribute: true);
}
