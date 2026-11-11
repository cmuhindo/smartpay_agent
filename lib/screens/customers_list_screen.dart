import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../models/customer.dart';
import '../services/auth_service.dart';
import '../services/customer_service.dart';
import 'customer_form_screen.dart';
import 'assign_loan_screen.dart';
import 'loans_list_screen.dart';
import 'login_screen.dart';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final _customerService = CustomerService();
  final _authService = AuthService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Customer> _customers = [];
  bool _loading = true;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _authService.currentUserName().then((name) => setState(() => _userName = name));
    _load();
  }

  Future<void> _load({String? q}) async {
    setState(() => _loading = true);
    try {
      final customers = await _customerService.search(q: q);
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(q: value));
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.ink950,
        foregroundColor: Colors.white,
        title: Text(_userName.isEmpty ? 'My Customers' : 'Hi, $_userName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'My Loans',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoansListScreen())),
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand500,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerFormScreen()));
          _load(q: _searchController.text);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Register Customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or phone…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? const Center(child: Text('No customers found.', style: TextStyle(color: AppColors.ink500)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _customers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final c = _customers[index];
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(c.phoneNumber),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerFormScreen(customerId: c.id)));
                                    _load(q: _searchController.text);
                                  } else if (value == 'assign') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => AssignLoanScreen(customer: c)));
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'assign', child: Text('Assign Phone Loan')),
                                  PopupMenuItem(value: 'edit', child: Text('Edit KYC')),
                                ],
                              ),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssignLoanScreen(customer: c))),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
