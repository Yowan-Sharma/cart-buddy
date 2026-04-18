import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class DeliveryPointSelectionScreen extends StatefulWidget {
  const DeliveryPointSelectionScreen({super.key});

  @override
  State<DeliveryPointSelectionScreen> createState() => _DeliveryPointSelectionScreenState();
}

class _DeliveryPointSelectionScreenState extends State<DeliveryPointSelectionScreen> {
  String? selectedPoint;

  // Mock list of delivery points based on university selection
  final List<Map<String, dynamic>> deliveryPoints = [
    {'name': 'Main Hostel Gate', 'icon': FIcons.house},
    {'name': 'Library Entrance', 'icon': FIcons.book},
    {'name': 'Department of CS', 'icon': FIcons.monitor},
    {'name': 'Central Cafeteria', 'icon': FIcons.coffee},
    {'name': 'University Gym', 'icon': FIcons.activity},
  ];

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: const Text('Delivery Point'),
        // backButton would be here but we're avoiding it due to API issues
      ),
      child: Container(
        color: AppColors.background,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pick a meetup spot',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a common point where you will receive your orders.',
              style: TextStyle(color: AppColors.textSub),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: deliveryPoints.length,
                itemBuilder: (context, index) {
                  final point = deliveryPoints[index];
                  final isSelected = selectedPoint == point['name'];
                  return GestureDetector(
                    onTap: () => setState(() => selectedPoint = point['name']),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.secondary.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.secondary : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            point['icon'],
                            size: 32,
                            color: isSelected ? AppColors.secondary : AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            point['name'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            FButton(
              onPress: selectedPoint == null
                  ? null
                  : () {
                      context.go('/');
                    },
              child: const Text('Finish Setup'),
            ),
          ],
        ),
      ),
    );
  }
}
