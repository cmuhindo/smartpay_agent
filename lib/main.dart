import 'package:flutter/material.dart';
import 'config.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/customers_list_screen.dart';

void main() {
  runApp(const SalesAgentApp());
}

class SalesAgentApp extends StatelessWidget {
  const SalesAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartPay HP - Sales Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brand500, primary: AppColors.brand500),
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data! ? const CustomersListScreen() : const LoginScreen();
      },
    );
  }
}
