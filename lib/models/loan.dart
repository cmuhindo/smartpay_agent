class LoanCustomer {
  final int id;
  final String name;
  final String phoneNumber;

  LoanCustomer({required this.id, required this.name, required this.phoneNumber});

  factory LoanCustomer.fromJson(Map<String, dynamic> json) =>
      LoanCustomer(id: json['id'], name: json['name'] ?? '', phoneNumber: json['phone_number'] ?? '');
}

class LoanPhoneUnit {
  final int id;
  final int phoneId;
  final String imei;
  final String? imei2;
  final String? colour;
  final String phoneName;
  final String? modelNumber;

  LoanPhoneUnit({
    required this.id,
    required this.phoneId,
    required this.imei,
    this.imei2,
    this.colour,
    required this.phoneName,
    this.modelNumber,
  });

  factory LoanPhoneUnit.fromJson(Map<String, dynamic> json) => LoanPhoneUnit(
        id: json['id'],
        phoneId: json['phone_id'],
        imei: json['imei'] ?? '',
        imei2: json['imei2'],
        colour: json['colour'],
        phoneName: json['phone_name'] ?? '',
        modelNumber: json['model_number'],
      );
}

class ScheduleRow {
  final int installmentNo;
  final String dueDate;
  final double amountDue;
  final double amountPaid;
  final String status;

  ScheduleRow({required this.installmentNo, required this.dueDate, required this.amountDue, required this.amountPaid, required this.status});

  factory ScheduleRow.fromJson(Map<String, dynamic> json) => ScheduleRow(
        installmentNo: json['installment_no'],
        dueDate: json['due_date'],
        amountDue: (json['amount_due'] ?? 0).toDouble(),
        amountPaid: (json['amount_paid'] ?? 0).toDouble(),
        status: json['status'] ?? 'pending',
      );
}

class DepositAttempt {
  final int id;
  final double amount;
  final String channel;
  final String status;
  final String? payerPhoneNumber;
  final String createdAt;

  DepositAttempt({required this.id, required this.amount, required this.channel, required this.status, this.payerPhoneNumber, required this.createdAt});

  factory DepositAttempt.fromJson(Map<String, dynamic> json) => DepositAttempt(
        id: json['id'],
        amount: (json['amount'] ?? 0).toDouble(),
        channel: json['channel'] ?? '',
        status: json['status'] ?? '',
        payerPhoneNumber: json['payer_phone_number'],
        createdAt: json['created_at'] ?? '',
      );
}

class LockAttempt {
  final int id;
  final bool success;
  final String? reason;
  final String? reference;
  final String createdAt;

  LockAttempt({required this.id, required this.success, this.reason, this.reference, required this.createdAt});

  factory LockAttempt.fromJson(Map<String, dynamic> json) => LockAttempt(
        id: json['id'],
        success: json['success'] ?? false,
        reason: json['reason'],
        reference: json['reference'],
        createdAt: json['created_at'] ?? '',
      );
}

class Loan {
  final int id;
  final String contractNo;
  final String status; // draft|submitted_for_approval|approved|declined|deposit_paid|active|defaulted|completed
  final double phonePrice;
  final double depositAmount;
  final double installmentAmount;
  final String paymentFrequency;
  final int numberOfInstallments;
  final double totalPayable;
  final double? balance;
  final String? declineReason;
  final int? loanPackageId;
  final LoanCustomer customer;
  final LoanPhoneUnit phoneUnit;
  final List<ScheduleRow> schedule;
  final List<DepositAttempt> depositAttempts;
  final List<LockAttempt> lockAttempts;

  Loan({
    required this.id,
    required this.contractNo,
    required this.status,
    required this.phonePrice,
    required this.depositAmount,
    required this.installmentAmount,
    required this.paymentFrequency,
    required this.numberOfInstallments,
    required this.totalPayable,
    this.balance,
    this.declineReason,
    this.loanPackageId,
    required this.customer,
    required this.phoneUnit,
    this.schedule = const [],
    this.depositAttempts = const [],
    this.lockAttempts = const [],
  });

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
        id: json['id'],
        contractNo: json['contract_no'] ?? '',
        status: json['status'] ?? 'draft',
        phonePrice: (json['phone_price'] ?? 0).toDouble(),
        depositAmount: (json['deposit_amount'] ?? 0).toDouble(),
        installmentAmount: (json['installment_amount'] ?? 0).toDouble(),
        paymentFrequency: json['payment_frequency'] ?? '',
        numberOfInstallments: json['number_of_installments'] ?? 0,
        totalPayable: (json['total_payable'] ?? 0).toDouble(),
        balance: json['balance'] != null ? (json['balance']).toDouble() : null,
        declineReason: json['decline_reason'],
        loanPackageId: json['loan_package'] != null ? json['loan_package']['id'] : null,
        customer: LoanCustomer.fromJson(json['customer']),
        phoneUnit: LoanPhoneUnit.fromJson(json['phone_unit']),
        schedule: (json['schedule'] as List? ?? []).map((e) => ScheduleRow.fromJson(e)).toList(),
        depositAttempts: (json['deposit_attempts'] as List? ?? []).map((e) => DepositAttempt.fromJson(e)).toList(),
        lockAttempts: (json['lock_attempts'] as List? ?? []).map((e) => LockAttempt.fromJson(e)).toList(),
      );

  String get statusLabel => status.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
}
