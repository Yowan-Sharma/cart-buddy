import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/service_providers.dart';

class CreateTicketScreen extends ConsumerStatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'OTHER';
  bool _isLoading = false;

  final List<Map<String, String>> _categories = [
    {'value': 'PAYMENT_ISSUE', 'label': 'Payment Issue'},
    {'value': 'ITEM_MISMATCH', 'label': 'Item Mismatch'},
    {'value': 'DELIVERY', 'label': 'Delivery Issue'},
    {'value': 'QUALITY', 'label': 'Quality Complaint'},
    {'value': 'OTHER', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.length < 5 || desc.length < 20) {
      showFToast(context: context, title: const Text('Please provide more details'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = ref.read(supportServiceProvider);
      await service.createTicket(
        title: title,
        description: desc,
        category: _category,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showFToast(context: context, title: const Text('Failed to raise ticket'), description: Text(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Support Ticket'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _category == cat['value'];
                return GestureDetector(
                  onTap: () => setState(() => _category = cat['value']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.accent : Colors.grey[300]!),
                    ),
                    child: Text(
                      cat['label']!,
                      style: TextStyle(color: isSelected ? Colors.white : AppColors.primary, fontSize: 13),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            FTextField(
              label: const Text('Subject'),
              hint: 'Briefly describe the issue',
              control: FTextFieldControl.managed(controller: _titleController),
            ),
            const SizedBox(height: 16),
            FTextField(
              label: const Text('Description'),
              hint: 'Provide as much detail as possible...',
              maxLines: 5,
              control: FTextFieldControl.managed(controller: _descController),
            ),
            const SizedBox(height: 40),
            FButton(
              onPress: _isLoading ? null : _submit,
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Ticket'),
            ),
          ],
        ),
      ),
    );
  }
}
