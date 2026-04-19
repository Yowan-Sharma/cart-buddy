class WalletModel {
  final double balance;
  final DateTime updatedAt;

  WalletModel({
    required this.balance,
    required this.updatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      balance: double.parse(json['balance'].toString()),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
