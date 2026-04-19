import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../models/order_model.dart';
import '../../onboarding/models/organisation_model.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _restaurantController = TextEditingController();
  final _meetingNotesController = TextEditingController();
  final _baseAmountController = TextEditingController();
  final _minThresholdController = TextEditingController();

  List<PickupPoint> _pickupPoints = [];
  PickupPoint? _selectedPickupPoint;
  bool _isLoadingPickupPoints = true;
  bool _isSubmitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPickupPoints();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _restaurantController.dispose();
    _meetingNotesController.dispose();
    _baseAmountController.dispose();
    _minThresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadPickupPoints() async {
    final organisationId = ref.read(authStateProvider).user?.organisation;
    if (organisationId == null) {
      setState(() {
        _loadError = 'Join an organisation before creating an order.';
        _isLoadingPickupPoints = false;
      });
      return;
    }

    try {
      final service = ref.read(organisationServiceProvider);
      final pickupPoints = await service.getPickupPoints(organisationId);
      if (!mounted) return;
      setState(() {
        _pickupPoints = pickupPoints;
        _selectedPickupPoint = pickupPoints.isNotEmpty
            ? pickupPoints.first
            : null;
        _isLoadingPickupPoints = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoadingPickupPoints = false;
      });
    }
  }

  Future<void> _submit() async {
    final organisationId = ref.read(authStateProvider).user?.organisation;
    if (!_formKey.currentState!.validate() ||
        organisationId == null ||
        _selectedPickupPoint == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final createdOrder = await ref
          .read(orderServiceProvider)
          .createOrder(
            organisationId: organisationId,
            pickupPointId: _selectedPickupPoint!.id,
            title: _titleController.text.trim(),
            restaurantName: _restaurantController.text.trim(),
            meetingNotes: _meetingNotesController.text.trim(),
            baseAmount: double.tryParse(_baseAmountController.text.trim()) ?? 0.0,
            minThresholdAmount: double.tryParse(_minThresholdController.text.trim()) ?? 0.0,
          );

      if (!mounted) return;
      Navigator.of(context).pop<Order>(createdOrder);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showFToast(
        context: context,
        title: const Text('Could not create order'),
        description: Text(e.toString()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final organisationName =
        ref.watch(authStateProvider).user?.organisationName ??
        'your organisation';
    final hasPickupPoints = _pickupPoints.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Order'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Container(
        color: AppColors.background,
        child: _isLoadingPickupPoints
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroCard(organisationName: organisationName),
                      const SizedBox(height: 20),
                      _SectionCard(
                        title: 'Order Details',
                        child: Column(
                          children: [
                            _AppTextField(
                              controller: _titleController,
                              label: 'Order title',
                              hint: 'Late-night burger run',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter a short title for the order.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _AppTextField(
                              controller: _restaurantController,
                              label: 'App/Service',
                              hint: 'Burger Club',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter the app or service name.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _AppTextField(
                              controller: _baseAmountController,
                              label: 'Your Order Amount',
                              hint: '450.00',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final parsed = double.tryParse(value?.trim() ?? '');
                                if (parsed == null || parsed < 0) {
                                  return 'Enter your initial order value.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _AppTextField(
                              controller: _minThresholdController,
                              label: 'Target Threshold (Min)',
                              hint: '1500.00',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final parsed = double.tryParse(value?.trim() ?? '');
                                if (parsed == null || parsed < 0) {
                                  return 'Enter the target threshold.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionCard(
                        title: 'Pickup Point',
                        child: _buildPickupPointSection(hasPickupPoints),
                      ),
                      const SizedBox(height: 20),
                      _SectionCard(
                        title: 'Notes',
                        child: _AppTextField(
                          controller: _meetingNotesController,
                          label: 'Pickup notes',
                          hint: 'Near the front gate, next to the benches',
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FButton(
                        onPress: !hasPickupPoints || _isSubmitting
                            ? null
                            : _submit,
                        child: Text(
                          _isSubmitting ? 'Creating...' : 'Create Order',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPickupPointSection(bool hasPickupPoints) {
    if (_loadError != null) {
      return _InlineNotice(
        title: 'Could not load pickup points',
        message: _loadError!,
      );
    }

    if (!hasPickupPoints) {
      return const _InlineNotice(
        title: 'No approved pickup points yet',
        message:
            'Your organisation needs to configure at least one pickup point before anyone can create an order.',
      );
    }

    return Column(
      children: _pickupPoints.map((point) {
        final isSelected = _selectedPickupPoint?.id == point.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => _selectedPickupPoint = point),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.secondary.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? AppColors.secondary
                      : AppColors.textSub.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    FIcons.mapPin,
                    color: isSelected ? AppColors.secondary : AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (point.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            point.description,
                            style: const TextStyle(color: AppColors.textSub),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppColors.secondary),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String organisationName;

  const _HeroCard({required this.organisationName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3D6), Color(0xFFFFE1A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create a shared order',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pickup will be limited to approved spots in $organisationName so the handoff stays predictable.',
            style: const TextStyle(color: AppColors.primary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final String title;
  final String message;

  const _InlineNotice({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1D39A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFF9A6B00)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: AppColors.textSub, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  const _AppTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.secondary),
        ),
      ),
    );
  }
}
