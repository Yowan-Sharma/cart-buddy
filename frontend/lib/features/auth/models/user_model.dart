class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String gender;
  final int? organisation;
  final String? organisationName;

  final String? bankAccountNumber;
  final String? ifscCode;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.gender,
    this.organisation,
    this.organisationName,
    this.bankAccountNumber,
    this.ifscCode,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phone: json['phone'].toString(),
      gender: json['gender'] ?? '',
      organisation: json['organisation'],
      organisationName: json['organisation_name'],
      bankAccountNumber: json['bank_account_number'],
      ifscCode: json['ifsc_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': int.tryParse(phone) ?? 0,
      'gender': gender,
      'organisation': organisation,
      'organisation_name': organisationName,
      'bank_account_number': bankAccountNumber,
      'ifsc_code': ifscCode,
    };
  }
}
