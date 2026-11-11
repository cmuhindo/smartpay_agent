import 'package:dio/dio.dart';
import '../models/customer.dart';
import 'api_client.dart';

class CustomerService {
  final Dio _dio = ApiClient().dio;

  Future<List<Customer>> search({String? q}) async {
    final response = await _dio.get('/agent/customers', queryParameters: {if (q != null && q.isNotEmpty) 'q': q});
    final data = response.data['data'] as List;
    return data.map((e) => Customer.fromJson(e)).toList();
  }

  Future<Customer> show(int id) async {
    final response = await _dio.get('/agent/customers/$id');
    return Customer.fromJson(response.data['data']);
  }

  /// [files] keys: id_front, id_back, customer_photo, proof_of_payment (paths, proof optional)
  Future<Customer> register({
    required String name,
    required String phoneNumber,
    required String gender,
    required String ninNumber,
    required String physicalAddress,
    required String country,
    required List<Guarantor> guarantors,
    required Map<String, String?> files,
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      'phone_number': phoneNumber,
      'gender': gender,
      'nin_number': ninNumber,
      'physical_address': physicalAddress,
      'country': country,
      for (var i = 0; i < guarantors.length; i++) ...{
        'guarantors[$i][name]': guarantors[i].name,
        'guarantors[$i][phone_number]': guarantors[i].phoneNumber,
        'guarantors[$i][relationship]': guarantors[i].relationship,
      },
      for (final entry in files.entries)
        if (entry.value != null) entry.key: await MultipartFile.fromFile(entry.value!),
    });

    final response = await _dio.post('/agent/customers', data: formData);
    return Customer.fromJson(response.data['data']);
  }

  Future<Customer> update({
    required int id,
    required String name,
    required String phoneNumber,
    required String gender,
    required String ninNumber,
    required String physicalAddress,
    required String country,
    required List<Guarantor> guarantors,
    required Map<String, String?> files, // only include keys the agent is replacing
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      'phone_number': phoneNumber,
      'gender': gender,
      'nin_number': ninNumber,
      'physical_address': physicalAddress,
      'country': country,
      for (var i = 0; i < guarantors.length; i++) ...{
        'guarantors[$i][name]': guarantors[i].name,
        'guarantors[$i][phone_number]': guarantors[i].phoneNumber,
        'guarantors[$i][relationship]': guarantors[i].relationship,
      },
      for (final entry in files.entries)
        if (entry.value != null) entry.key: await MultipartFile.fromFile(entry.value!),
    });

    final response = await _dio.post('/agent/customers/$id/update', data: formData);
    return Customer.fromJson(response.data['data']);
  }
}
