import 'package:dio/dio.dart';
import '../models/wallet_model.dart';

class WalletService {
  final Dio _dio;

  WalletService(this._dio);

  Future<WalletModel> getMyWallet() async {
    final response = await _dio.get('payments/wallet/me/');
    return WalletModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> withdrawFunds(double amount) async {
    await _dio.post('payments/wallet/withdraw/', data: {'amount': amount});
  }
}
