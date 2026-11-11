import 'package:flutter/material.dart';
import '../config.dart';
import '../models/loan.dart';
import '../services/loan_service.dart';
import 'loan_detail_screen.dart';

class LoansListScreen extends StatefulWidget {
  const LoansListScreen({super.key});

  @override
  State<LoansListScreen> createState() => _LoansListScreenState();
}

class _LoansListScreenState extends State<LoansListScreen> {
  final _loanService = LoanService();
  List<Loan> _loans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final loans = await _loanService.fetchLoans();
      if (!mounted) return;
      setState(() {
        _loans = loans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    return switch (status) {
      'active' || 'approved' || 'deposit_paid' => AppColors.brand600,
      'defaulted' || 'declined' => AppColors.rose500,
      'submitted_for_approval' => AppColors.amber500,
      _ => AppColors.ink500,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.ink950, foregroundColor: Colors.white, title: const Text('My Loans')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loans.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No loans yet.', style: TextStyle(color: AppColors.ink500))))])
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _loans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final loan = _loans[index];
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          title: Text(loan.customer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${loan.contractNo} · ${loan.phoneUnit.phoneName}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _statusColor(loan.status).withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
                            child: Text(loan.statusLabel, style: TextStyle(color: _statusColor(loan.status), fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan.id)));
                            _load();
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
