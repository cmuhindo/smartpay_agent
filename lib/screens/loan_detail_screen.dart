import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config.dart';
import '../models/loan.dart';
import '../services/loan_service.dart';
import '../services/customer_service.dart';
import 'assign_loan_screen.dart';
import 'customer_form_screen.dart';

class LoanDetailScreen extends StatefulWidget {
  final int loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final _loanService = LoanService();
  final _customerService = CustomerService();
  final _picker = ImagePicker();

  Loan? _loan;
  bool _loading = true;
  String? _message;
  bool _messageIsError = false;

  final _depositAmountController = TextEditingController();
  final _depositPhoneController = TextEditingController();
  final _depositRefController = TextEditingController();
  String _depositChannel = 'mobile_money';

  final Map<String, String?> _handoverPhotos = {
    'phone_lock_screen_photo': null,
    'customer_app_screen_photo': null,
    'payment_receipt_photo': null,
    'customer_holding_phone_photo': null,
  };
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final loan = await _loanService.fetchLoan(widget.loanId);
      if (!mounted) return;
      _depositAmountController.text = loan.depositAmount.toStringAsFixed(0);
      setState(() {
        _loan = loan;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    setState(() {
      _message = msg;
      _messageIsError = isError;
    });
  }

  bool get _hasSuccessfulLock => _loan?.lockAttempts.any((a) => a.success) ?? false;

  Future<void> _editCustomer() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerFormScreen(customerId: _loan!.customer.id)));
  }

  Future<void> _editLoan() async {
    final customer = await _customerService.show(_loan!.customer.id);
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AssignLoanScreen(customer: customer, existingLoan: _loan)),
    );
    if (result != null) _load();
  }

  Future<void> _submitForApproval() async {
    setState(() => _actionBusy = true);
    try {
      await _loanService.submit(_loan!.id);
      _showMessage('Loan submitted for approval.');
      _load();
    } catch (e) {
      _showMessage('Could not submit. Please try again.', isError: true);
    } finally {
      setState(() => _actionBusy = false);
    }
  }

  Future<void> _recordManualDeposit() async {
    final amount = double.tryParse(_depositAmountController.text);
    if (amount == null || amount <= 0) {
      _showMessage('The approved deposit amount is invalid.', isError: true);
      return;
    }

    setState(() => _actionBusy = true);
    try {
      await _loanService.collectDeposit(
        loanId: _loan!.id,
        amount: amount,
        channel: _depositChannel,
        payerPhoneNumber: _depositPhoneController.text.trim(),
        externalReference: _depositRefController.text.trim(),
        attemptStatus: 'success',
      );
      _showMessage('Manual payment recorded. You can now initiate the phone lock.');
      _load();
    } catch (e) {
      _showMessage('Could not record the manual payment.', isError: true);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _initiateMobileMoney() async {
    final amount = double.tryParse(_depositAmountController.text);
    final phone = _depositPhoneController.text.trim();
    if (amount == null || amount <= 0) {
      _showMessage('The approved deposit amount is invalid.', isError: true);
      return;
    }
    if (phone.isEmpty) {
      _showMessage('Enter the customer’s Mobile Money phone number.', isError: true);
      return;
    }

    setState(() => _actionBusy = true);
    try {
      final result = await _loanService.initiateDeposit(
        loanId: _loan!.id,
        amount: amount,
        payerPhoneNumber: phone,
      );
      final paymentId = (result['payment_id'] as num?)?.toInt();
      var status = (result['status'] ?? '').toString().toUpperCase();

      if (status == 'SUCCESS') {
        _showMessage('Deposit confirmed. You can now initiate the phone lock.');
        await _load();
        return;
      }

      if (paymentId == null) {
        _showMessage(result['message']?.toString() ?? 'MamboPay did not return a payment reference.', isError: true);
        return;
      }

      _showMessage('Mobile Money prompt sent. Ask the customer to enter their PIN.');
      for (var attempt = 0; attempt < 10; attempt++) {
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        final current = await _loanService.depositStatus(
          loanId: _loan!.id,
          paymentId: paymentId,
        );
        status = (current['status'] ?? '').toString().toUpperCase();
        if (status == 'SUCCESS') {
          _showMessage('Deposit confirmed. You can now initiate the phone lock.');
          await _load();
          return;
        }
        if (status == 'FAILED' || status == 'ERROR' || status == 'REJECTED' || status == 'CANCELLED') {
          _showMessage(current['message']?.toString() ?? 'Mobile Money payment failed.', isError: true);
          return;
        }
      }

      _showMessage('Payment is still pending. Refresh this loan later to check the final status.');
      await _load();
    } catch (e) {
      _showMessage('Could not initiate or check the Mobile Money payment.', isError: true);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _initiateLock() async {
    setState(() => _actionBusy = true);
    try {
      final succeeded = await _loanService.initiateLock(_loan!.id);
      _showMessage(succeeded ? 'Device lock initiated successfully. You can now confirm handover.' : 'Phone lock failed. Check the history and retry.');
      _load();
    } catch (e) {
      _showMessage('Could not initiate the production phone lock.', isError: true);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _pickHandoverPhoto(String key) async {
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
    if (file != null) setState(() => _handoverPhotos[key] = file.path);
  }

  Future<void> _confirmHandover() async {
    if (_handoverPhotos['phone_lock_screen_photo'] == null || _handoverPhotos['customer_app_screen_photo'] == null) {
      _showMessage('Lock screen and customer app photos are both required.', isError: true);
      return;
    }

    setState(() => _actionBusy = true);
    try {
      await _loanService.confirmHandover(
        loanId: _loan!.id,
        phoneLockScreenPhotoPath: _handoverPhotos['phone_lock_screen_photo']!,
        customerAppScreenPhotoPath: _handoverPhotos['customer_app_screen_photo']!,
        paymentReceiptPhotoPath: _handoverPhotos['payment_receipt_photo'],
        customerHoldingPhonePhotoPath: _handoverPhotos['customer_holding_phone_photo'],
      );
      _showMessage('Loan is now active. Phone handed over to the customer.');
      _load();
    } catch (e) {
      _showMessage('Could not confirm handover.', isError: true);
    } finally {
      setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_loan == null) return const Scaffold(body: Center(child: Text('Loan not found.')));

    final loan = _loan!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.ink950, foregroundColor: Colors.white, title: Text(loan.contractNo)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(loan.customer.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.brand500.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
                        child: Text(loan.statusLabel, style: const TextStyle(color: AppColors.brand600, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  Text('${loan.phoneUnit.phoneName} · IMEI ${loan.phoneUnit.imei}', style: const TextStyle(color: AppColors.ink500, fontSize: 12)),
                  const Divider(height: 20),
                  _kv('Phone Price', 'UGX ${loan.phonePrice.toStringAsFixed(0)}'),
                  _kv('Deposit', 'UGX ${loan.depositAmount.toStringAsFixed(0)}'),
                  _kv('Installment', 'UGX ${loan.installmentAmount.toStringAsFixed(0)} / ${loan.paymentFrequency}'),
                  if (loan.balance != null) _kv('Balance', 'UGX ${loan.balance!.toStringAsFixed(0)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_message != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _messageIsError ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_message!, style: TextStyle(color: _messageIsError ? AppColors.rose500 : AppColors.brand600, fontSize: 13)),
              ),

            if (loan.status == 'draft') ...[
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _actionBusy ? null : _submitForApproval,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.ink950),
                    child: const Text('Submit For Approval'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _editLoan, child: const Text('Edit')),
              ]),
            ],

            if (loan.status == 'submitted_for_approval')
              _infoBanner('Waiting on the approvals team to review this loan.', AppColors.amber500),

            if (loan.status == 'declined') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('This loan was declined', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.rose500)),
                    const SizedBox(height: 4),
                    Text(loan.declineReason ?? '', style: const TextStyle(color: AppColors.rose500)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: FilledButton(onPressed: _editLoan, style: FilledButton.styleFrom(backgroundColor: AppColors.ink950), child: const Text('Edit & Resubmit'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton(onPressed: _editCustomer, child: const Text('Edit KYC'))),
                    ]),
                  ],
                ),
              ),
            ],

            if (loan.status == 'approved') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Collect Initial Deposit', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Mobile Money uses the live MamboPay collection service. The customer must approve the prompt with their PIN.',
                        style: TextStyle(fontSize: 12, color: AppColors.ink500)),
                    const SizedBox(height: 10),
                    TextField(controller: _depositAmountController, readOnly: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Approved deposit amount', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _depositChannel,
                      decoration: const InputDecoration(labelText: 'Channel', border: OutlineInputBorder(), isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'bank', child: Text('Bank')),
                        DropdownMenuItem(value: 'card', child: Text('Card')),
                      ],
                      onChanged: (v) => setState(() => _depositChannel = v ?? 'mobile_money'),
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: _depositPhoneController, decoration: const InputDecoration(labelText: "Payer's Phone Number", border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 8),
                    TextField(controller: _depositRefController, decoration: const InputDecoration(labelText: 'Reference (optional)', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 12),
                    if (_depositChannel == 'mobile_money')
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _actionBusy ? null : _initiateMobileMoney,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.brand500),
                          child: const Text('Initiate Mobile Money'),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _actionBusy ? null : _recordManualDeposit,
                          child: const Text('Record Manual Payment'),
                        ),
                      ),
                  ],
                ),
              ),
              if (loan.depositAttempts.isNotEmpty) ...[
                const SizedBox(height: 12),
                _attemptHistoryCard('Attempt History', loan.depositAttempts.map((a) => _AttemptRow(
                      label: '${a.channel} · ${a.payerPhoneNumber ?? "—"}',
                      value: 'UGX ${a.amount.toStringAsFixed(0)}',
                      success: a.status == 'success',
                    ))),
              ],
            ],

            if (loan.status == 'deposit_paid') ...[
              if (!_hasSuccessfulLock) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Initiate Phone Lock', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Enrolls the device with the lock provider. A failed attempt can be retried.',
                          style: TextStyle(fontSize: 12, color: AppColors.ink500)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _actionBusy ? null : _initiateLock,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.brand500),
                          child: const Text('Initiate Phone Lock'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (loan.lockAttempts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _attemptHistoryCard('Lock Attempt History', loan.lockAttempts.map((a) => _AttemptRow(
                        label: a.reason ?? (a.success ? 'Enrolled' : 'Failed'),
                        value: a.success ? 'Success' : 'Failed',
                        success: a.success,
                      ))),
                ],
              ] else ...[
                _infoBanner('Device locked successfully. Confirm handover below to activate the loan.', AppColors.brand600),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Confirm Handover', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Lock screen and customer app photos are required. Receipt and customer photos are optional.',
                          style: TextStyle(fontSize: 12, color: AppColors.ink500)),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.4,
                        children: [
                          _handoverPhotoTile('phone_lock_screen_photo', 'Lock Screen *'),
                          _handoverPhotoTile('customer_app_screen_photo', 'Customer App *'),
                          _handoverPhotoTile('payment_receipt_photo', 'Receipt (optional)'),
                          _handoverPhotoTile('customer_holding_phone_photo', 'Customer Holding Phone (optional)'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _actionBusy ? null : _confirmHandover,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.ink950),
                          child: const Text('Confirm Handover & Activate Loan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            if (['active', 'defaulted', 'completed'].contains(loan.status)) ...[
              if (loan.status == 'active') _infoBanner('This loan is active.', AppColors.brand600),
              if (loan.status == 'defaulted') _infoBanner('The phone is currently locked - payment coverage has lapsed.', AppColors.rose500),
              if (loan.status == 'completed') _infoBanner('This loan is fully paid off.', AppColors.ink500),
              const SizedBox(height: 8),
              const Text('Loan Schedule', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...loan.schedule.map((row) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('#${row.installmentNo}  ${row.dueDate}', style: const TextStyle(fontSize: 12, color: AppColors.ink500)),
                        Text('UGX ${row.amountPaid.toStringAsFixed(0)} / ${row.amountDue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.ink300.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                          child: Text(row.status == 'pending' ? 'Unpaid' : row.status, style: const TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: AppColors.ink500, fontSize: 13)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );

  Widget _infoBanner(String text, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: color, fontSize: 13)),
      );

  Widget _attemptHistoryCard(String title, Iterable<_AttemptRow> rows) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(r.label, style: const TextStyle(fontSize: 12, color: AppColors.ink700))),
                      Text(r.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: r.success ? AppColors.brand600 : AppColors.rose500)),
                    ],
                  ),
                )),
          ],
        ),
      );

  Widget _handoverPhotoTile(String key, String label) {
    final path = _handoverPhotos[key];
    return GestureDetector(
      onTap: () => _pickHandoverPhoto(key),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.ink300.withOpacity(0.4))),
        clipBehavior: Clip.antiAlias,
        child: path != null
            ? Image.file(File(path), fit: BoxFit.cover)
            : Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_a_photo, color: AppColors.ink500, size: 20),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontSize: 10, color: AppColors.ink500), textAlign: TextAlign.center),
                ]),
              ),
      ),
    );
  }
}

class _AttemptRow {
  final String label;
  final String value;
  final bool success;
  _AttemptRow({required this.label, required this.value, required this.success});
}
