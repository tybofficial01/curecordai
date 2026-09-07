import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/illustration_header.dart';

class TellUsAboutYourselfScreen extends StatefulWidget {
  const TellUsAboutYourselfScreen({super.key, required this.formKey});

  final GlobalKey<FormState> formKey;

  @override
  State<TellUsAboutYourselfScreen> createState() =>
      _TellUsAboutYourselfScreenState();
}

class _TellUsAboutYourselfScreenState extends State<TellUsAboutYourselfScreen> {
  late TextEditingController _nameController;
  late TextEditingController _yearController;
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController = TextEditingController(text: auth.fullName ?? '');
    _yearController = TextEditingController(text: auth.yearOfBirth ?? '');
    _selectedGender = auth.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _syncToProvider() {
    final auth = context.read<AuthProvider>();
    auth.fullName = _nameController.text.trim();
    auth.yearOfBirth = _yearController.text.trim();
    auth.gender = _selectedGender;
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
            const IllustrationHeader(
              imagePath: AppStrings.successIllustrationAsset,
              height: 120,
            ),
            const SizedBox(height: 16),
            Text(AppStrings.tellUsAboutYourselfTitle,
                style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            Text(AppStrings.tellUsAboutYourselfSubtitle,
                style: AppTextStyles.subtitle),
            const SizedBox(height: 32),
            CustomTextField(
              label: 'Full Name *',
              hint: 'e.g. Esha Maryam',
              controller: _nameController,
              validator: Validators.fullName,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Year of Birth *',
              hint: 'e.g. 2004',
              controller: _yearController,
              keyboardType: TextInputType.number,
              validator: Validators.yearOfBirth,
              suffixIcon: const Icon(Icons.calendar_today_outlined,
                  color: AppColors.secondaryText, size: 20),
            ),
            const SizedBox(height: 16),
            Text('Gender *', style: AppTextStyles.inputLabel),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              hint:
                  Text('Select Gender', style: AppTextStyles.inputPlaceholder),
              style: AppTextStyles.inputText,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline,
                    color: AppColors.secondaryText, size: 20),
                filled: true,
                fillColor: AppColors.inputFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primaryTeal, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
              ),
              validator: (v) => v == null ? 'Please select a gender' : null,
              items: AppStrings.genderOptions.map((g) {
                return DropdownMenuItem(
                  value: g,
                  child: Text(g, style: AppTextStyles.inputText),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedGender = value);
                _syncToProvider();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
