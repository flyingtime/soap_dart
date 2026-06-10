import 'package:soap_dart/soap_dart.dart';

part 'calculator_api.g.dart';

@SoapApi(namespace: 'urn:calculator')
abstract class CalculatorApi {
  factory CalculatorApi(SoapClient client) = _CalculatorApi;

  @SoapOperation(
    action: 'urn:add',
    requestName: 'Add',
    responseName: 'AddResponse',
  )
  Future<AddResponse> add(AddRequest request);

  @SoapOperation(
    action: 'urn:multiply',
    requestName: 'Multiply',
    responseName: 'MultiplyResponse',
  )
  Future<int> multiply(
    @SoapField(name: 'a') int left,
    @SoapField(name: 'b') int right,
  );
}

@SoapModel(name: 'Add')
class AddRequest {
  final int a;
  final int b;

  const AddRequest({required this.a, required this.b});
}

@SoapModel(name: 'AddResponse')
class AddResponse {
  @SoapField(name: 'result')
  final int value;

  const AddResponse({required this.value});
}
