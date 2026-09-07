import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

class PhoneInputField extends StatelessWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    required this.onCountryChanged,
    this.errorText,
    this.initialCountryCode = 'PK',
  });

  final TextEditingController controller;
  final ValueChanged<String> onCountryChanged;
  final String? errorText;
  final String initialCountryCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phone Number', style: AppTextStyles.inputLabel),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(
                  color: errorText != null
                      ? AppColors.error
                      : AppColors.inputBorder,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CountryCodePicker(
                onChanged: (code) => onCountryChanged(code.dialCode ?? '+92'),
                initialSelection: initialCountryCode,
                showFlag: true,
                showDropDownButton: true,
                showFlagDialog: true,
                alignLeft: false,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: AppFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkText,
                ),
                dialogTextStyle: AppFonts.manrope(
                  fontSize: 14,
                  color: AppColors.darkText,
                ),
                searchDecoration: InputDecoration(
                  hintText: 'Search country...',
                  hintStyle: AppFonts.manrope(color: AppColors.placeholder),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 56,
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  style: AppTextStyles.inputText,
                  decoration: InputDecoration(
                    hintText: '000-000-0000',
                    hintStyle: AppTextStyles.inputPlaceholder,
                    filled: true,
                    fillColor: AppColors.inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: errorText != null
                            ? AppColors.error
                            : AppColors.inputBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: errorText != null
                            ? AppColors.error
                            : AppColors.inputBorder,
                      ),
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
                ),
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(errorText!,
              style: AppFonts.manrope(fontSize: 12, color: AppColors.error)),
        ],
      ],
    );
  }
}
