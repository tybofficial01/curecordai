import 'package:flutter/material.dart';

class Helpers {
  Helpers._();

  static String formatPhoneNumber(String countryCode, String number) {
    final cleaned = number.replaceAll(RegExp(r'[\s\-()]'), '');
    return '$countryCode$cleaned';
  }

  static void showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static void pushReplaceAll(BuildContext context, String routeName) {
    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
  }
}
