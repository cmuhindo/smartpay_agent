import 'package:dio/dio.dart';
import '../models/loan.dart';
import 'api_client.dart';

class LoanService {
  final Dio _dio = ApiClient().dio;

  Future<List<Loan>> fetchLoans() async {
    final response = await _dio.get('/agent/loans');
    final data = response.data['data'] as List;
    return data.map((e) => Loan.fromJson(e)).toList();
  }

  Future<Loan> fetchLoan(int id) async {
    final response = await _dio.get('/agent/loans/$id');
    return Loan.fromJson(response.data['data']);
  }

  Future<Loan> createDraft({
    required int customerId,
    required int phoneId,
    required String imei,
    String? imei2,
    String? colour,
    required double phonePrice,
    required int loanPackageId,
  }) async {
    final response = await _dio.post('/agent/loans', data: {
      'customer_id': customerId,
      'phone_id': phoneId,
      'imei': imei,
      if (imei2 != null && imei2.isNotEmpty) 'imei2': imei2,
      if (colour != null && colour.isNotEmpty) 'colour': colour,
      'phone_price': phonePrice,
      'loan_package_id': loanPackageId,
    });
    return Loan.fromJson(response.data['data']);
  }

  Future<Loan> reviseDraft({
    required int loanId,
    required int phoneId,
    required String imei,
    String? imei2,
    String? colour,
    required double phonePrice,
    required int loanPackageId,
  }) async {
    final response = await _dio.post('/agent/loans/$loanId/update', data: {
      'phone_id': phoneId,
      'imei': imei,
      if (imei2 != null && imei2.isNotEmpty) 'imei2': imei2,
      if (colour != null && colour.isNotEmpty) 'colour': colour,
      'phone_price': phonePrice,
      'loan_package_id': loanPackageId,
    });
    return Loan.fromJson(response.data['data']);
  }

  Future<Loan> submit(int loanId) async {
    final response = await _dio.post('/agent/loans/$loanId/submit');
    return Loan.fromJson(response.data['data']);
  }

  /// Records a manual non-mobile-money deposit or historical attempt.
  /// This is not used for live Mobile Money collection.
  Future<Loan> collectDeposit({
    required int loanId,
    required double amount,
    required String channel,
    String? payerPhoneNumber,
    String? externalReference,
    required String attemptStatus,
  }) async {
    final response = await _dio.post('/agent/loans/$loanId/deposit', data: {
      'amount': amount,
      'channel': channel,
      if (payerPhoneNumber != null && payerPhoneNumber.isNotEmpty) 'payer_phone_number': payerPhoneNumber,
      if (externalReference != null && externalReference.isNotEmpty) 'external_reference': externalReference,
      'attempt_status': attemptStatus,
    });
    return Loan.fromJson(response.data['data']);
  }

  /// Starts a real MamboPay collection through the SmartPay backend.
  /// The backend replaces the client amount with the approved contract deposit.
  Future<Map<String, dynamic>> initiateDeposit({
    required int loanId,
    required double amount,
    required String payerPhoneNumber,
  }) async {
    final response = await _dio.post('/agent/loans/$loanId/deposit', data: {
      'amount': amount,
      'channel': 'mobile_money',
      'payer_phone_number': payerPhoneNumber,
    });

    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Polls the real MamboPay transaction status through SmartPay.
  Future<Map<String, dynamic>> depositStatus({
    required int loanId,
    required int paymentId,
  }) async {
    final response = await _dio.get('/agent/loans/$loanId/deposit/$paymentId/status');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<bool> initiateLock(int loanId) async {
    final response = await _dio.post('/agent/loans/$loanId/initiate-lock');
    return response.data['lock_succeeded'] ?? false;
  }

  Future<Loan> confirmHandover({
    required int loanId,
    required String phoneLockScreenPhotoPath,
    required String customerAppScreenPhotoPath,
    String? paymentReceiptPhotoPath,
    String? customerHoldingPhonePhotoPath,
  }) async {
    final formData = FormData.fromMap({
      'phone_lock_screen_photo': await MultipartFile.fromFile(phoneLockScreenPhotoPath),
      'customer_app_screen_photo': await MultipartFile.fromFile(customerAppScreenPhotoPath),
      if (paymentReceiptPhotoPath != null) 'payment_receipt_photo': await MultipartFile.fromFile(paymentReceiptPhotoPath),
      if (customerHoldingPhonePhotoPath != null)
        'customer_holding_phone_photo': await MultipartFile.fromFile(customerHoldingPhonePhotoPath),
    });

    final response = await _dio.post('/agent/loans/$loanId/confirm-handover', data: formData);
    return Loan.fromJson(response.data['data']);
  }
}
