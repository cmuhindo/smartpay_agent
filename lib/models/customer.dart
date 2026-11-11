class Guarantor {
  String name;
  String phoneNumber;
  String relationship;

  Guarantor({this.name = '', this.phoneNumber = '', this.relationship = ''});

  factory Guarantor.fromJson(Map<String, dynamic> json) => Guarantor(
        name: json['name'] ?? '',
        phoneNumber: json['phone_number'] ?? '',
        relationship: json['relationship'] ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'phone_number': phoneNumber, 'relationship': relationship};
}

class Customer {
  final int id;
  final String name;
  final String phoneNumber;
  final String? gender;
  final String? ninNumber;
  final String? physicalAddress;
  final String? country;
  final String? idFrontUrl;
  final String? idBackUrl;
  final String? customerPhotoUrl;
  final String? proofOfPaymentUrl;
  final List<Guarantor> guarantors;

  Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.gender,
    this.ninNumber,
    this.physicalAddress,
    this.country,
    this.idFrontUrl,
    this.idBackUrl,
    this.customerPhotoUrl,
    this.proofOfPaymentUrl,
    this.guarantors = const [],
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'],
        name: json['name'] ?? '',
        phoneNumber: json['phone_number'] ?? '',
        gender: json['gender'],
        ninNumber: json['nin_number'],
        physicalAddress: json['physical_address'],
        country: json['country'],
        idFrontUrl: json['id_front_url'],
        idBackUrl: json['id_back_url'],
        customerPhotoUrl: json['customer_photo_url'],
        proofOfPaymentUrl: json['proof_of_payment_url'],
        guarantors: (json['guarantors'] as List? ?? []).map((g) => Guarantor.fromJson(g)).toList(),
      );
}
