import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../core/constants/app_colors.dart';

class OtpInputField extends StatelessWidget {
  const OtpInputField({
    super.key,
    required this.controller,
    required this.onCompleted,
    required this.onChanged,
    this.hasError = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return PinCodeTextField(
      appContext: context,
      length: 6,
      controller: controller,
      autoFocus: true,
      keyboardType: TextInputType.number,
      animationType: AnimationType.fade,
      enableActiveFill: true,
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        borderRadius: BorderRadius.circular(10),
        fieldHeight: 56,
        fieldWidth: 48,
        borderWidth: 1.5,
        activeFillColor: AppColors.white,
        inactiveFillColor: AppColors.white,
        selectedFillColor: AppColors.white,
        activeColor: hasError ? AppColors.error : AppColors.primaryTeal,
        inactiveColor: hasError ? AppColors.error : AppColors.otpBorderInactive,
        selectedColor: AppColors.otpBorderActive,
      ),
      onCompleted: onCompleted,
      onChanged: onChanged,
    );
  }
}
