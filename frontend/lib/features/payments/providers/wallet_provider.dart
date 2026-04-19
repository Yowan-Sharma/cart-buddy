import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/service_providers.dart';
import '../models/wallet_model.dart';

final walletBalanceProvider = FutureProvider<WalletModel>((ref) async {
  return ref.watch(walletServiceProvider).getMyWallet();
});
