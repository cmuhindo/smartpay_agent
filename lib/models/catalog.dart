class PhoneCategoryOption {
  final int id;
  final String name;

  PhoneCategoryOption({required this.id, required this.name});

  factory PhoneCategoryOption.fromJson(Map<String, dynamic> json) =>
      PhoneCategoryOption(id: json['id'], name: json['name']);
}

class PhoneOption {
  final int id;
  final String name;
  final String? modelNumber;
  final double hpPrice;
  final double minimumPrice;
  final double maximumPrice;

  PhoneOption({
    required this.id,
    required this.name,
    this.modelNumber,
    required this.hpPrice,
    required this.minimumPrice,
    required this.maximumPrice,
  });

  factory PhoneOption.fromJson(Map<String, dynamic> json) => PhoneOption(
        id: json['id'],
        name: json['name'],
        modelNumber: json['model_number'],
        hpPrice: (json['hp_price'] ?? 0).toDouble(),
        minimumPrice: (json['minimum_price'] ?? 0).toDouble(),
        maximumPrice: (json['maximum_price'] ?? 0).toDouble(),
      );
}

class LoanPackageOption {
  final int id;
  final String packageName;
  final double minimumAmount;
  final double maximumAmount;
  final double profitMarkupPercentage;
  final double interest;
  final int totalCycles;
  final double initialDepositPercentage;
  final String billableCycleName; // days | weeks | months

  LoanPackageOption({
    required this.id,
    required this.packageName,
    required this.minimumAmount,
    required this.maximumAmount,
    required this.profitMarkupPercentage,
    required this.interest,
    required this.totalCycles,
    required this.initialDepositPercentage,
    required this.billableCycleName,
  });

  factory LoanPackageOption.fromJson(Map<String, dynamic> json) => LoanPackageOption(
        id: json['id'],
        packageName: json['package_name'],
        minimumAmount: (json['minimum_amount'] ?? 0).toDouble(),
        maximumAmount: (json['maximum_amount'] ?? 0).toDouble(),
        profitMarkupPercentage: (json['profit_markup_percentage'] ?? 0).toDouble(),
        interest: (json['interest'] ?? 0).toDouble(),
        totalCycles: json['total_cycles'] ?? 1,
        initialDepositPercentage: (json['initial_deposit_percentage'] ?? 0).toDouble(),
        billableCycleName: json['billable_cycle_name'] ?? 'months',
      );

  /// Mirrors LoanPackage::calculateBreakdown() server-side exactly.
  LoanBreakdown calculateBreakdown(double phonePrice) {
    final deposit = (initialDepositPercentage / 100) * phonePrice;
    final creditAmount = phonePrice - deposit;
    final markupAmount = (profitMarkupPercentage / 100) * creditAmount;
    final hirePurchasePrice = creditAmount + markupAmount;
    final totalInterest = (interest / 100) * totalCycles * hirePurchasePrice;
    final totalPayable = hirePurchasePrice + totalInterest;
    final numberOfInstallments = billableCycleName == 'days' ? totalCycles * 30 : totalCycles;
    final installmentAmount = totalPayable / (numberOfInstallments == 0 ? 1 : numberOfInstallments);

    return LoanBreakdown(
      deposit: deposit,
      totalPayable: totalPayable,
      numberOfInstallments: numberOfInstallments,
      installmentAmount: installmentAmount,
    );
  }
}

class LoanBreakdown {
  final double deposit;
  final double totalPayable;
  final int numberOfInstallments;
  final double installmentAmount;

  LoanBreakdown({
    required this.deposit,
    required this.totalPayable,
    required this.numberOfInstallments,
    required this.installmentAmount,
  });
}
