import 'package:flutter/material.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';

class AlmostThereScreen extends StatefulWidget {
  const AlmostThereScreen({super.key});

  @override
  State<AlmostThereScreen> createState() => _AlmostThereScreenState();
}

class _AlmostThereScreenState extends State<AlmostThereScreen> {
  late TextEditingController _allergiesController;
  late TextEditingController _customConditionsController;
  late Set<String> _selectedConditions;
  static const int _maxCustomLength = 200;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _allergiesController = TextEditingController(text: auth.allergies ?? '');
    _customConditionsController =
        TextEditingController(text: auth.customConditions ?? '');
    _selectedConditions = Set.from(auth.selectedConditions);
  }

  @override
  void dispose() {
    _allergiesController.dispose();
    _customConditionsController.dispose();
    super.dispose();
  }

  void _syncToProvider() {
    final auth = context.read<AuthProvider>();
    auth.allergies = _allergiesController.text.trim();
    auth.selectedConditions = _selectedConditions.toList();
    auth.customConditions = _customConditionsController.text.trim();
  }

  void _toggleCondition(String condition) {
    setState(() {
      if (_selectedConditions.contains(condition)) {
        _selectedConditions.remove(condition);
      } else {
        _selectedConditions.add(condition);
      }
    });
    _syncToProvider();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(AppStrings.almostThereTitle, style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          Text(AppStrings.almostThereSubtitle, style: AppTextStyles.subtitle),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allergies',
                  style: AppFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _allergiesController,
                  maxLines: 3,
                  style: AppTextStyles.inputText,
                  onChanged: (_) => _syncToProvider(),
                  decoration: InputDecoration(
                    hintText: 'e.g., Pollen, Penicillin, Peanuts, Latex...',
                    hintStyle: AppTextStyles.inputPlaceholder,
                    filled: true,
                    fillColor: AppColors.inputFill,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primaryTeal, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Separate items with commas',
                  style: AppFonts.manrope(
                      fontSize: 12, color: AppColors.placeholder),
                ),
                const SizedBox(height: 20),
                Text(
                  'Existing Conditions',
                  style: AppFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppStrings.predefinedConditions.map((condition) {
                    final isSelected = _selectedConditions.contains(condition);
                    return _ConditionChip(
                      label: condition,
                      isSelected: isSelected,
                      onTap: () => _toggleCondition(condition),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _customConditionsController,
                  builder: (context, value, _) {
                    final length = value.text.length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextFormField(
                          controller: _customConditionsController,
                          maxLength: _maxCustomLength,
                          style: AppTextStyles.inputText,
                          onChanged: (_) => _syncToProvider(),
                          decoration: InputDecoration(
                            hintText: 'Add other conditions...',
                            hintStyle: AppTextStyles.inputPlaceholder,
                            filled: true,
                            fillColor: AppColors.inputFill,
                            contentPadding: const EdgeInsets.all(16),
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.inputBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.inputBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.primaryTeal, width: 1.5),
                            ),
                          ),
                        ),
                        if (length > 150)
                          Text(
                            '$length/$_maxCustomLength',
                            style: AppFonts.manrope(
                              fontSize: 11,
                              color: length >= _maxCustomLength
                                  ? AppColors.error
                                  : AppColors.placeholder,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Expanded(
                  child: _BadgeBox(
                      icon: Icons.security,
                      text: 'HIPAA Compliant\nSecure Storage')),
              SizedBox(width: 12),
              Expanded(
                  child: _BadgeBox(
                      icon: Icons.verified_user_outlined,
                      text: 'Encrypted\nPersonal Data')),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTeal : AppColors.chipBackground,
          border: Border.all(
            color: isSelected ? AppColors.primaryTeal : AppColors.chipBorder,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.white : AppColors.darkText,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSelected ? Icons.check : Icons.add,
              size: 14,
              color: isSelected ? AppColors.white : AppColors.darkText,
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeBox extends StatelessWidget {
  const _BadgeBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoBoxBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryTeal, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
