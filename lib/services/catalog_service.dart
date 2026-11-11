import 'package:dio/dio.dart';
import '../models/catalog.dart';
import 'api_client.dart';

class CatalogService {
  final Dio _dio = ApiClient().dio;

  Future<List<PhoneCategoryOption>> fetchCategories() async {
    final response = await _dio.get('/agent/phone-categories');
    return (response.data as List).map((e) => PhoneCategoryOption.fromJson(e)).toList();
  }

  Future<List<PhoneOption>> fetchPhonesByCategory(int categoryId) async {
    final response = await _dio.get('/agent/phone-categories/$categoryId/phones');
    return (response.data as List).map((e) => PhoneOption.fromJson(e)).toList();
  }

  Future<List<LoanPackageOption>> fetchLoanPackages() async {
    final response = await _dio.get('/agent/loan-packages');
    return (response.data as List).map((e) => LoanPackageOption.fromJson(e)).toList();
  }
}
