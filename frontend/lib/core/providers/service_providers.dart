import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../../features/onboarding/data/organisation_service.dart';
import '../../features/orders/data/order_service.dart';

import '../../features/payments/data/wallet_service.dart';
import '../../features/support/data/support_service.dart';

final organisationServiceProvider = Provider<OrganisationService>((ref) {
  final dio = ref.watch(dioProvider);
  return OrganisationService(dio);
});

final orderServiceProvider = Provider<OrderService>((ref) {
  final dio = ref.watch(dioProvider);
  return OrderService(dio);
});

final walletServiceProvider = Provider<WalletService>((ref) {
  final dio = ref.watch(dioProvider);
  return WalletService(dio);
});

final supportServiceProvider = Provider<SupportService>((ref) {
  final dio = ref.watch(dioProvider);
  return SupportService(dio);
});
