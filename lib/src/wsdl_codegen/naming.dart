const dartKeywords = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

String dartClassName(String value) {
  final words = _words(value);
  final result = words.map(_capitalize).join();
  if (result.isEmpty) {
    return 'GeneratedType';
  }
  final safe = _startsWithDigit(result) ? 'Type$result' : result;
  return dartKeywords.contains(safe) ? '${safe}Type' : safe;
}

String dartFieldName(String value) {
  final className = dartClassName(value);
  final result =
      className.substring(0, 1).toLowerCase() + className.substring(1);
  return dartKeywords.contains(result) ? '${result}Value' : result;
}

String dartMethodName(String value) => dartFieldName(value);

String enumConstantName(String value) {
  final result = dartFieldName(value);
  return result.isEmpty ? 'value' : result;
}

List<String> _words(String value) {
  final trimmed = value.contains(':') ? value.split(':').last : value;
  final withNumberBoundaries = trimmed.replaceAllMapped(
    RegExp(r'([A-Za-z])(\d)([A-Za-z]?)'),
    (match) => '${match.group(1)} ${match.group(2)} ${match.group(3)}',
  );
  return withNumberBoundaries
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList();
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  if (value.length == 1) {
    return value.toUpperCase();
  }
  return value.substring(0, 1).toUpperCase() + value.substring(1);
}

bool _startsWithDigit(String value) =>
    value.isNotEmpty && RegExp(r'^\d').hasMatch(value);
