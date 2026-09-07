import 'package:flutter/material.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';

class PhysicalMetricsScreen extends StatefulWidget {
  const PhysicalMetricsScreen({super.key, required this.formKey});

  final GlobalKey<FormState> formKey;

  @override
  State<PhysicalMetricsScreen> createState() => _PhysicalMetricsScreenState();
}

class _PhysicalMetricsScreenState extends State<PhysicalMetricsScreen> {
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  String? _selectedBloodGroup;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _heightController = TextEditingController(text: auth.heightCm ?? '');
    _weightController = TextEditingController(text: auth.weightKg ?? '');
    _selectedBloodGroup = auth.bloodGroup;
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _syncToProvider() {
    final auth = context.read<AuthProvider>();
    auth.heightCm = _heightController.text.trim();
    auth.weightKg = _weightController.text.trim();
    auth.bloodGroup = _selectedBloodGroup;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: widget.formKey,
        onChanged: _syncToProvider,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(AppStrings.physicalMetricsTitle,
                style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            Text(AppStrings.physicalMetricsSubtitle,
                style: AppTextStyles.subtitle),
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
                children: [
                  CustomTextField(
                    label: 'Height (cm)',
                    hint: '175',
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    validator: Validators.height,
                    suffixIcon: const Icon(Icons.unfold_more,
                        color: AppColors.secondaryText, size: 20),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Weight (kg)',
                    hint: 'Select Weight',
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    validator: Validators.weight,
                    suffixIcon: const Icon(Icons.monitor_weight_outlined,
                        color: AppColors.secondaryText, size: 20),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Blood Group', style: AppTextStyles.inputLabel),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedBloodGroup,
                        hint: Text('Select Blood Group',
                            style: AppTextStyles.inputPlaceholder),
                        style: AppTextStyles.inputText,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
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
                        items: AppStrings.bloodGroups.map((g) {
                          return DropdownMenuItem(
                            value: g,
                            child: Text(g, style: AppTextStyles.inputText),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedBloodGroup = value);
                          _syncToProvider();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.infoBoxBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.primaryTeal, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your physical data is used exclusively to calculate BMI and customize nutritional recommendations. All data is encrypted.',
                      style: AppFonts.manrope(
                          fontSize: 12, color: AppColors.secondaryText),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
