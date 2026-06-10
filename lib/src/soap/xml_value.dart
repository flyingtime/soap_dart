import 'dart:convert';

import 'package:xml/xml.dart';

/// Converts a Dart object to an XML element.
typedef SoapXmlWriter<T> = XmlElement Function(T value);

/// Converts an XML element to a Dart object.
typedef SoapXmlReader<T> = T Function(XmlElement element);

/// A value that can render itself as a SOAP body child element.
abstract interface class SoapSerializable {
  XmlElement toXmlElement({String? name, String? namespace});
}

/// Raw XML payload for services that use `xsd:anyType` or unknown extension
/// points.
final class SoapAny {
  final List<XmlNode> nodes;

  const SoapAny(this.nodes);

  factory SoapAny.fromElement(XmlElement element) =>
      SoapAny(element.children.map((node) => node.copy()).toList());

  factory SoapAny.fromXml(String xml) =>
      SoapAny(XmlDocumentFragment.parse(xml).children.toList());

  String toXmlString() => nodes.map((node) => node.toXmlString()).join();
}

XmlElement soapTextElement(
  String name,
  Object? value, {
  String? namespace,
  Map<String, String> attributes = const {},
}) {
  final builder = XmlBuilder();
  builder.element(name, namespace: namespace, namespaces: const {}, nest: () {
    for (final entry in attributes.entries) {
      builder.attribute(entry.key, entry.value);
    }
    if (value != null) {
      builder.text(soapFormatValue(value));
    }
  });
  return builder.buildDocument().rootElement;
}

String soapFormatValue(Object value) {
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is Duration) {
    return formatXsdDuration(value);
  }
  if (value is bool) {
    return value ? 'true' : 'false';
  }
  if (value is List<int>) {
    return base64Encode(value);
  }
  return value.toString();
}

String? soapElementText(XmlElement? element) {
  if (element == null) {
    return null;
  }
  final value = element.innerText.trim();
  return value.isEmpty ? null : value;
}

bool? soapParseBool(String? value) {
  if (value == null) {
    return null;
  }
  return value == 'true' || value == '1';
}

int? soapParseInt(String? value) => value == null ? null : int.parse(value);

double? soapParseDouble(String? value) =>
    value == null ? null : double.parse(value);

List<int>? soapParseBase64(String? value) =>
    value == null ? null : base64Decode(value);

DateTime? soapParseDateTime(String? value) =>
    value == null ? null : DateTime.parse(value);

Duration? soapParseDuration(String? value) =>
    value == null ? null : parseXsdDuration(value);

String formatXsdDuration(Duration duration) {
  final sign = duration.isNegative ? '-' : '';
  var micros = duration.abs().inMicroseconds;
  final days = micros ~/ Duration.microsecondsPerDay;
  micros %= Duration.microsecondsPerDay;
  final hours = micros ~/ Duration.microsecondsPerHour;
  micros %= Duration.microsecondsPerHour;
  final minutes = micros ~/ Duration.microsecondsPerMinute;
  micros %= Duration.microsecondsPerMinute;
  final seconds = micros / Duration.microsecondsPerSecond;

  final buffer = StringBuffer('${sign}P');
  if (days != 0) {
    buffer.write('${days}D');
  }
  if (hours != 0 || minutes != 0 || seconds != 0 || days == 0) {
    buffer.write('T');
    if (hours != 0) {
      buffer.write('${hours}H');
    }
    if (minutes != 0) {
      buffer.write('${minutes}M');
    }
    if (seconds != 0 || (hours == 0 && minutes == 0)) {
      final text = seconds == seconds.truncateToDouble()
          ? seconds.toInt().toString()
          : seconds.toString();
      buffer.write('${text}S');
    }
  }
  return buffer.toString();
}

Duration parseXsdDuration(String value) {
  final match = RegExp(
    r'^(-)?P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?'
    r'(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$',
  ).firstMatch(value);
  if (match == null) {
    throw FormatException('Invalid xsd:duration', value);
  }
  final years = int.tryParse(match.group(2) ?? '') ?? 0;
  final months = int.tryParse(match.group(3) ?? '') ?? 0;
  final days = int.tryParse(match.group(4) ?? '') ?? 0;
  final hours = int.tryParse(match.group(5) ?? '') ?? 0;
  final minutes = int.tryParse(match.group(6) ?? '') ?? 0;
  final seconds = double.tryParse(match.group(7) ?? '') ?? 0;

  // XSD year/month durations are calendar-relative. Keep runtime simple and
  // deterministic by using common approximations.
  final result = Duration(
    days: years * 365 + months * 30 + days,
    hours: hours,
    minutes: minutes,
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );
  return match.group(1) == '-' ? -result : result;
}

extension SoapXmlElementSearch on XmlElement {
  XmlElement? getElementByLocalName(String localName) {
    for (final child in childElements) {
      if (child.name.local == localName) {
        return child;
      }
    }
    return null;
  }

  Iterable<XmlElement> getElementsByLocalName(String localName) sync* {
    for (final child in childElements) {
      if (child.name.local == localName) {
        yield child;
      }
    }
  }
}
