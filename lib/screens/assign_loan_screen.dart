import 'package:flutter/material.dart';
import '../config.dart';
import '../models/customer.dart';
import '../models/catalog.dart';
import '../models/loan.dart';
import '../services/catalog_service.dart';
import '../services/loan_service.dart';
import 'loan_detail_screen.dart';

class AssignLoanScreen extends StatefulWidget {
  final Customer customer;
  final Loan? existingLoan; // non-null = editing a draft/declined loan instead of creating new

  const AssignLoanScreen({super.key, required this.customer, this.existingLoan});

  @override
  State<AssignLoanScreen> createState() => _AssignLoanScreenState();
}

class _AssignLoanScreenState extends State<AssignLoanScreen> {
  final _catalogService = CatalogService();
  final _loanService = LoanService();

  final _imeiController = TextEditingController();
  final _imei2Controller = TextEditingController();
  final _colourController = TextEditingController();
  final _priceController = TextEditingController();

  List<PhoneCategoryOption> _categories = [];
  List<PhoneOption> _phones = [];
  List<LoanPackageOption> _packages = [];

  PhoneCategoryOption? _selectedCategory;
  PhoneOption? _selectedPhone;
  LoanPackageOption? _selectedPackage;

  LoanBreakdown? _breakdown;
  String? _priceError;
  bool _loadingCatalog = true;
  bool _loadingPhones = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _priceController.addListener(_recalculate);

    if (widget.existingLoan != null) {
      final loan = widget.existingLoan!;
      _imeiController.text = loan.phoneUnit.imei;
      _imei2Controller.text = loan.phoneUnit.imei2 ?? '';
      _colourController.text = loan.phoneUnit.colour ?? '';
      _priceController.text = loan.phonePrice.toStringAsFixed(0);
    }
  }

  bool get isEditMode => widget.existingLoan != null;

  Future<void> _loadCatalog() async {
    try {
      final categories = await _catalogService.fetchCategories();
      final packages = await _catalogService.fetchLoanPackages();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _packages = packages;
        _loadingCatalog = false;
        if (isEditMode && widget.existingLoan!.loanPackageId != null) {
          _selectedPackage = packages.firstWhere(
            (p) => p.id == widget.existingLoan!.loanPackageId,
            orElse: () => packages.first,
          );
          _recalculate();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCatalog = false);
    }
  }

  Future<void> _onCategoryChanged(PhoneCategoryOption? category) async {
    setState(() {
      _selectedCategory = category;
      _selectedPhone = null;
      _phones = [];
      _breakdown = null;
      _loadingPhones = true;
    });
    if (category == null) {
      setState(() => _loadingPhones = false);
      return;
    }
    try {
      final phones = await _catalogService.fetchPhonesByCategory(category.id);
      if (!mounted) return;
      setState(() {
        _phones = phones;
        _loadingPhones = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPhones = false);
    }
  }

  void _recalculate() {
    setState(() {
      _priceError = null;
      _breakdown = null;

      final price = double.tryParse(_priceController.text);
      if (_selectedPhone == null || _selectedPackage == null || price == null || price <= 0) return;

      if (price < _selectedPhone!.minimumPrice || price > _selectedPhone!.maximumPrice) {
        _priceError = 'This phone\'s price must be between ${_selectedPhone!.minimumPrice.toStringAsFixed(0)} and ${_selectedPhone!.maximumPrice.toStringAsFixed(0)}.';
        return;
      }
      if (price < _selectedPackage!.minimumAmount || price > _selectedPackage!.maximumAmount) {
        _priceError = 'The selected package only allows prices between ${_selectedPackage!.minimumAmount.toStringAsFixed(0)} and ${_selectedPackage!.maximumAmount.toStringAsFixed(0)}.';
        return;
      }

      _breakdown = _selectedPackage!.calculateBreakdown(price);
    });
  }

  Future<void> _submit() async {
    if (_selectedPhone == null || _selectedPackage == null || _breakdown == null || _imeiController.text.trim().isEmpty) {
      setState(() => _error = 'Complete all required fields before saving.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final loan = isEditMode
          ? await _loanService.reviseDraft(
              loanId: widget.existingLoan!.id,
              phoneId: _selectedPhone!.id,
              imei: _imeiController.text.trim(),
              imei2: _imei2Controller.text.trim(),
              colour: _colourController.text.trim(),
              phonePrice: double.parse(_priceController.text),
              loanPackageId: _selectedPackage!.id,
            )
          : await _loanService.createDraft(
              customerId: widget.customer.id,
              phoneId: _selectedPhone!.id,
              imei: _imeiController.text.trim(),
              imei2: _imei2Controller.text.trim(),
              colour: _colourController.text.trim(),
              phonePrice: double.parse(_priceController.text),
              loanPackageId: _selectedPackage!.id,
            );

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan.id)));
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Could not save the loan. Check the IMEI isn\'t already in use and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.ink950, foregroundColor: Colors.white, title: Text(isEditMode ? 'Edit Loan' : 'Assign Phone Loan')),
      body: _loadingCatalog
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: AppColors.ink500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.customer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(widget.customer.phoneNumber, style: const TextStyle(color: AppColors.ink500, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.rose500, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Phone Details', style: TextStyle(fontWeight: FontWeight.w700)),
                if (isEditMode) ...[
                  const SizedBox(height: 4),
                  const Text('Re-select the phone type and package below - IMEI, colour, and price are pre-filled.',
                      style: TextStyle(fontSize: 12, color: AppColors.ink500)),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<PhoneCategoryOption>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Phone Type', border: OutlineInputBorder()),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: _onCategoryChanged,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<PhoneOption>(
                  value: _selectedPhone,
                  decoration: InputDecoration(
                    labelText: 'Phone Name',
                    border: const OutlineInputBorder(),
                    suffixIcon: _loadingPhones ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                  ),
                  items: _phones.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                  onChanged: (p) => setState(() {
                    _selectedPhone = p;
                    _recalculate();
                  }),
                ),
                if (_selectedPhone?.modelNumber != null) ...[
                  const SizedBox(height: 6),
                  Text('Model Number: ${_selectedPhone!.modelNumber}', style: const TextStyle(color: AppColors.ink500, fontSize: 12)),
                ],
                const SizedBox(height: 10),
                TextField(controller: _imeiController, decoration: const InputDecoration(labelText: 'IMEI 1', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _imei2Controller, decoration: const InputDecoration(labelText: 'IMEI 2 (optional)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _colourController, decoration: const InputDecoration(labelText: 'Colour', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                const Text('Loan Package & Price', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                DropdownButtonFormField<LoanPackageOption>(
                  value: _selectedPackage,
                  decoration: const InputDecoration(labelText: 'Loan Package', border: OutlineInputBorder()),
                  items: _packages.map((p) => DropdownMenuItem(value: p, child: Text(p.packageName))).toList(),
                  onChanged: (p) => setState(() {
                    _selectedPackage = p;
                    _recalculate();
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Phone Price (UGX)', border: OutlineInputBorder()),
                ),
                if (_priceError != null) ...[
                  const SizedBox(height: 6),
                  Text(_priceError!, style: const TextStyle(color: AppColors.rose500, fontSize: 12)),
                ],
                if (_breakdown != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Loan Summary', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _summaryRow('Initial Deposit', _breakdown!.deposit),
                        _summaryRow('Installment Amount', _breakdown!.installmentAmount),
                        _summaryRow('Number of Installments', _breakdown!.numberOfInstallments.toDouble(), isCount: true),
                        _summaryRow('Total Payable', _breakdown!.totalPayable),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: (_breakdown == null || _submitting) ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.ink950, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEditMode ? 'Save Changes' : 'Save as Draft'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isCount = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.ink500)),
            Text(isCount ? value.toInt().toString() : 'UGX ${value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
