import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../../features/onboarding/data/organisation_service.dart';
import '../../features/orders/data/order_service.dart';

final organisationServiceProvider = Provider<OrganisationService>((ref) {
  final dio = ref.watch(dioProvider);
  return OrganisationService(dio);
});

final orderServiceProvider = Provider<OrderService>((ref) {
  final dio = ref.watch(dioProvider);
  return OrderService(dio);
});
