import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';
import 'assign_loan_screen.dart';

class CustomerFormScreen extends StatefulWidget {
  final int? customerId; // null = register new, otherwise edit existing

  const CustomerFormScreen({super.key, this.customerId});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _customerService = CustomerService();
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ninController = TextEditingController();
  final _addressController = TextEditingController();
  final _countryController = TextEditingController(text: 'Uganda');
  String _gender = 'male';

  final List<Guarantor> _guarantors = [Guarantor(), Guarantor()];
  final List<TextEditingController> _guarantorNameCtrls = [TextEditingController(), TextEditingController()];
  final List<TextEditingController> _guarantorPhoneCtrls = [TextEditingController(), TextEditingController()];
  final List<TextEditingController> _guarantorRelCtrls = [TextEditingController(), TextEditingController()];

  // Local file paths for newly picked photos.
  final Map<String, String?> _newPhotos = {'id_front': null, 'id_back': null, 'customer_photo': null, 'proof_of_payment': null};
  // Existing photo URLs, when editing.
  Map<String, String?> _existingPhotoUrls = {};

  bool _loading = false;
  bool _initialLoading = false;
  String? _error;

  bool get isEdit => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _initialLoading = true);
    final customer = await _customerService.show(widget.customerId!);
    _nameController.text = customer.name;
    _phoneController.text = customer.phoneNumber;
    _ninController.text = customer.ninNumber ?? '';
    _addressController.text = customer.physicalAddress ?? '';
    _countryController.text = customer.country ?? 'Uganda';
    _gender = customer.gender ?? 'male';
    _existingPhotoUrls = {
      'id_front': customer.idFrontUrl,
      'id_back': customer.idBackUrl,
      'customer_photo': customer.customerPhotoUrl,
      'proof_of_payment': customer.proofOfPaymentUrl,
    };
    for (var i = 0; i < customer.guarantors.length && i < 2; i++) {
      _guarantorNameCtrls[i].text = customer.guarantors[i].name;
      _guarantorPhoneCtrls[i].text = customer.guarantors[i].phoneNumber;
      _guarantorRelCtrls[i].text = customer.guarantors[i].relationship;
    }
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<void> _pickPhoto(String key) async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (choice == null) return;

    final file = await _picker.pickImage(source: choice, imageQuality: 80);
    if (file != null) setState(() => _newPhotos[key] = file.path);
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    _guarantors[0] = Guarantor(name: _guarantorNameCtrls[0].text, phoneNumber: _guarantorPhoneCtrls[0].text, relationship: _guarantorRelCtrls[0].text);
    _guarantors[1] = Guarantor(name: _guarantorNameCtrls[1].text, phoneNumber: _guarantorPhoneCtrls[1].text, relationship: _guarantorRelCtrls[1].text);

    if (!isEdit && _newPhotos.values.take(3).any((v) => v == null)) {
      setState(() {
        _loading = false;
        _error = 'ID front, ID back, and customer photo are all required.';
      });
      return;
    }

    try {
      final customer = isEdit
          ? await _customerService.update(
              id: widget.customerId!,
              name: _nameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              gender: _gender,
              ninNumber: _ninController.text.trim(),
              physicalAddress: _addressController.text.trim(),
              country: _countryController.text.trim(),
              guarantors: _guarantors,
              files: _newPhotos,
            )
          : await _customerService.register(
              name: _nameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              gender: _gender,
              ninNumber: _ninController.text.trim(),
              physicalAddress: _addressController.text.trim(),
              country: _countryController.text.trim(),
              guarantors: _guarantors,
              files: _newPhotos,
            );

      if (!mounted) return;

      if (isEdit) {
        Navigator.pop(context);
      } else {
        // Straight into assigning a loan, mirroring the web flow.
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AssignLoanScreen(customer: customer)));
      }
    } catch (e) {
      debugPrint('[CustomerForm] Save error: $e');
      setState(() {
        _loading = false;
        _error = _describeError(e);
      });
    }
  }

  String _describeError(Object e) {
    if (e is DioException) {
      debugPrint('[CustomerForm] Status: ${e.response?.statusCode}');
      debugPrint('[CustomerForm] Body: ${e.response?.data}');

      final data = e.response?.data;
      if (data is Map) {
        // Laravel validation errors: {"message": "...", "errors": {"field": ["msg"]}}
        if (data['errors'] is Map) {
          final errors = data['errors'] as Map;
          final firstField = errors.keys.first;
          final firstMessage = (errors[firstField] as List).first;
          return '$firstField: $firstMessage';
        }
        if (data['message'] != null) {
          return data['message'].toString();
        }
      }
      if (e.response?.statusCode == 401) return 'Session expired - please log out and log back in.';
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        return 'Request timed out - the photos may be too large or the connection too slow.';
      }
      return 'Server error (${e.response?.statusCode ?? 'no connection'}).';
    }
    return 'Unexpected error: $e';
  }

  Widget _photoTile(String key, String label) {
    final localPath = _newPhotos[key];
    final existingUrl = _existingPhotoUrls[key];

    return GestureDetector(
      onTap: () => _pickPhoto(key),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.ink300.withOpacity(0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: localPath != null
            ? Image.file(File(localPath), fit: BoxFit.cover)
            : existingUrl != null
                ? Image.network(existingUrl, fit: BoxFit.cover)
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_a_photo, color: AppColors.ink500),
                        const SizedBox(height: 4),
                        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.ink500), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.ink950,
        foregroundColor: Colors.white,
        title: Text(isEdit ? 'Edit Customer' : 'Register Customer'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: AppColors.rose500, fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],
          const Text('Personal Details', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _gender = v ?? 'male'),
          ),
          const SizedBox(height: 10),
          TextField(controller: _ninController, decoration: const InputDecoration(labelText: 'NIN Number', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _addressController, maxLines: 2, decoration: const InputDecoration(labelText: 'Physical Address', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _countryController, decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          const Text('KYC Documents', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('ID front, ID back, and customer photo are required. Proof of payment is optional.',
              style: TextStyle(fontSize: 12, color: AppColors.ink500)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _photoTile('id_front', 'ID Front'),
              _photoTile('id_back', 'ID Back'),
              _photoTile('customer_photo', 'Customer Photo'),
              _photoTile('proof_of_payment', 'Proof of Payment'),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Guarantors (2 required)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (var i = 0; i < 2; i++) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  Align(alignment: Alignment.centerLeft, child: Text('Guarantor ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  const SizedBox(height: 8),
                  TextField(controller: _guarantorNameCtrls[i], decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: _guarantorPhoneCtrls[i], decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: _guarantorRelCtrls[i], decoration: const InputDecoration(labelText: 'Relationship', border: OutlineInputBorder(), isDense: true)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.ink950, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isEdit ? 'Save Changes' : 'Register & Continue to Loan'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
