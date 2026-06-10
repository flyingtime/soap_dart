import 'package:flutter/material.dart';
import 'package:soap_dart/soap_dart.dart';

import 'calculator_api.dart';
import 'country_client.dart' as wsdl;
import 'country_info_api.dart';
import 'mock_calculator_service.dart';

void main() {
  runApp(const SoapDartExampleApp());
}

class SoapDartExampleApp extends StatelessWidget {
  const SoapDartExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'soap_dart example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late final CalculatorSoapHarness _harness;
  final _aController = TextEditingController(text: '4');
  final _bController = TextEditingController(text: '5');
  var _busy = false;
  String _result = 'No request sent';
  String _soapRequests = '';

  @override
  void initState() {
    super.initState();
    _harness = createCalculatorSoapHarness();
  }

  @override
  void dispose() {
    _aController.dispose();
    _bController.dispose();
    super.dispose();
  }

  Future<void> _callAdd() async {
    await _runCall(() async {
      final response = await _harness.api.add(
        AddRequest(a: _read(_aController), b: _read(_bController)),
      );
      return 'Add result: ${response.value}';
    });
  }

  Future<void> _callMultiply() async {
    await _runCall(() async {
      final response = await _harness.api.multiply(
        _read(_aController),
        _read(_bController),
      );
      return 'Multiply result: $response';
    });
  }

  Future<void> _callCountryInfoApi() async {
    setState(() {
      _busy = true;
      _result = 'Calling annotation CountryInfoApi...';
    });

    final requests = <String>[];
    final soapClient = SoapClient(
      countryInfoEndpoint,
      onRequest: (request) {
        requests.add(request.body);
      },
    );
    final api = CountryInfoApi(soapClient);

    try {
      final continentsResponse = await api.listOfContinentsByName();
      final countriesResponse = await api.listOfCountryNamesByName();
      final continentNames =
          (continentsResponse.listOfContinentsByNameResult?.tContinent ??
                  const <Continent>[])
              .map(
                (continent) =>
                    _nameOrCode(name: continent.sName, code: continent.sCode),
              )
              .where((name) => name.isNotEmpty)
              .join(', ');
      final countryNames =
          (countriesResponse
                      .listOfCountryNamesByNameResult
                      ?.tCountryCodeAndName ??
                  const <CountryCodeAndName>[])
              .map(
                (country) =>
                    _codeAndName(code: country.sISOCode, name: country.sName),
              )
              .where((name) => name.isNotEmpty)
              .take(8)
              .join(', ');

      setState(() {
        _result = _countryInfoResult(
          'CountryInfoApi',
          continentNames: continentNames,
          countryNames: countryNames,
        );
        _soapRequests = requests.join('\n\n');
      });
    } on Object catch (error) {
      setState(() {
        _result = 'Error: $error';
        _soapRequests = requests.join('\n\n');
      });
    } finally {
      soapClient.close();
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _callCountryInfoPortTypeClient() async {
    setState(() {
      _busy = true;
      _result = 'Calling WSDL CountryInfoPortTypeClient...';
    });

    final requests = <String>[];
    final soapClient = SoapClient(
      countryInfoEndpoint,
      onRequest: (request) {
        requests.add(request.body);
      },
    );
    final api = wsdl.CountryInfoPortTypeClient(soapClient);

    try {
      final continentsResponse = await api.listOfContinentsByName(
        const wsdl.ListOfContinentsByNameType(),
      );
      final countriesResponse = await api.listOfCountryNamesByName(
        const wsdl.ListOfCountryNamesByNameType(),
      );
      final continentNames =
          (continentsResponse.listOfContinentsByNameResult?.tContinent ??
                  const <wsdl.Continent>[])
              .map(
                (continent) =>
                    _nameOrCode(name: continent.sName, code: continent.sCode),
              )
              .where((name) => name.isNotEmpty)
              .join(', ');
      final countryNames =
          (countriesResponse
                      .listOfCountryNamesByNameResult
                      ?.tCountryCodeAndName ??
                  const <wsdl.CountryCodeAndName>[])
              .map(
                (country) =>
                    _codeAndName(code: country.sISOCode, name: country.sName),
              )
              .where((name) => name.isNotEmpty)
              .take(8)
              .join(', ');

      setState(() {
        _result = _countryInfoResult(
          'CountryInfoPortTypeClient',
          continentNames: continentNames,
          countryNames: countryNames,
        );
        _soapRequests = requests.join('\n\n');
      });
    } on Object catch (error) {
      setState(() {
        _result = 'Error: $error';
        _soapRequests = requests.join('\n\n');
      });
    } finally {
      soapClient.close();
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _runCall(Future<String> Function() call) async {
    setState(() {
      _busy = true;
      _result = 'Calling SOAP service...';
    });
    try {
      final result = await call();
      setState(() {
        _result = result;
        _soapRequests = _harness.requests.isEmpty ? '' : _harness.requests.last;
      });
    } on Object catch (error) {
      setState(() {
        _result = 'Error: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  int _read(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  String _countryInfoResult(
    String clientName, {
    required String continentNames,
    required String countryNames,
  }) => [
    clientName,
    continentNames.isEmpty
        ? 'No continents returned.'
        : 'Continents: $continentNames',
    countryNames.isEmpty
        ? 'No countries returned.'
        : 'Countries: $countryNames',
  ].join('\n');

  String _nameOrCode({String? name, String? code}) {
    final nameValue = name?.trim() ?? '';
    if (nameValue.isNotEmpty) return nameValue;
    return code?.trim() ?? '';
  }

  String _codeAndName({String? code, String? name}) {
    final codeValue = code?.trim() ?? '';
    final nameValue = name?.trim() ?? '';
    if (codeValue.isEmpty) return nameValue;
    if (nameValue.isEmpty) return codeValue;
    return '$codeValue: $nameValue';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('soap_dart Flutter example')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Generated SOAP calculator',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _aController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'A',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _bController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'B',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _callAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _callMultiply,
                  icon: const Icon(Icons.close),
                  label: const Text('Multiply'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _callCountryInfoApi,
                  icon: const Icon(Icons.run_circle),
                  label: const Text('CountryInfoApi'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _callCountryInfoPortTypeClient,
                  icon: const Icon(Icons.public),
                  label: const Text('CountryInfoPortTypeClient'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(_result, style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            Text('SOAP request XML', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _soapRequests.isEmpty
                      ? 'Send a request to see XML.'
                      : _soapRequests,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
