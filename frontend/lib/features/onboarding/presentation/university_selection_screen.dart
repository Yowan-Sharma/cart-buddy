import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../models/organisation_model.dart';
import "../../../core/providers/auth_provider.dart";

class UniversitySelectionScreen extends ConsumerStatefulWidget {
  const UniversitySelectionScreen({super.key});

  @override
  ConsumerState<UniversitySelectionScreen> createState() => _UniversitySelectionScreenState();
}

class _UniversitySelectionScreenState extends ConsumerState<UniversitySelectionScreen> {
  Organisation? _selectedUniversity;
  List<Organisation> _universities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUniversities();
  }

  Future<void> _fetchUniversities() async {
    try {
      final orgService = ref.read(organisationServiceProvider);
      var fetched = await orgService.getOrganisations();
      
      // Seed fallback universities if backend returns empty list
      if (fetched.isEmpty) {
        fetched = [
          Organisation(id: 1, name: 'Thapar Institute of Engineering and Technology', location: 'Patiala'),
          Organisation(id: 2, name: 'BITS Pilani', location: 'Pilani'),
          Organisation(id: 3, name: 'BITS Hyderabad', location: 'Hyderabad'),
          Organisation(id: 4, name: 'BITS Goa', location: 'Goa'),
        ];
      }

      setState(() {
        _universities = fetched;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        // Even on error, show seed data for testing
        _universities = [
          Organisation(id: 1, name: 'Thapar Institute of Engineering and Technology', location: 'Patiala'),
          Organisation(id: 2, name: 'BITS Pilani', location: 'Pilani'),
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) => FScaffold(
          header: const FHeader(title: Text('Select University')),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Where do you study?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This helps us find orders near your campus.',
                  style: TextStyle(color: AppColors.textSub),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _universities.isEmpty
                          ? const Center(
                              child: Text(
                                'No universities available',
                                style: TextStyle(color: AppColors.textSub),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _universities.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final university = _universities[index];
                                final isSelected = _selectedUniversity?.id == university.id;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedUniversity = university;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.accent.withOpacity(0.1) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? AppColors.accent : AppColors.textSub.withOpacity(0.2),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          FIcons.mapPin,
                                          color: isSelected ? AppColors.accent : AppColors.primary,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                university.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected ? AppColors.accent : AppColors.primary,
                                                ),
                                              ),
                                              Text(
                                                university.location,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSub,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(FIcons.check, color: AppColors.accent),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
                const SizedBox(height: 24),
                FButton(
                  onPress: _selectedUniversity == null
                      ? null
                      : () async {
                          try {
                            final orgService = ref.read(organisationServiceProvider);
                            await orgService.joinOrganisation(_selectedUniversity!.id);
                            
                            // Refresh user profile to update the organisation state
                            await ref.read(authStateProvider.notifier).refreshUser();

                            if (context.mounted) {
                              showFToast(
                                context: context,
                                title: const Text('University selected successfully'),
                              );
                            }
                            // Router will automatically redirect to home now that user has an organisation
                          } catch (e) {
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => FDialog(
                                  title: const Text('Selection Failed'),
                                  body: Text(e.toString()),
                                  actions: [
                                    FButton(
                                      onPress: () => Navigator.pop(context),
                                      child: const Text('Try Again'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension ListSize<T> on List<T> {
  int get size => length;
}
