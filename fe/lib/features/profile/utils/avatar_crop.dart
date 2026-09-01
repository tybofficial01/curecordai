import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../core/theme/app_theme.dart';

/// Opens the platform-native crop UI (circular preview, 1:1 aspect ratio)
/// for the image at [sourcePath]. Returns the cropped file path, or null if
/// the user cancelled.
Future<String?> cropAvatarImage(
  BuildContext context,
  String sourcePath, {
  required String title,
}) async {
  final cropped = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: title,
        toolbarColor: AppTheme.primary,
        toolbarWidgetColor: Colors.white,
        cropStyle: CropStyle.circle,
        lockAspectRatio: true,
      ),
      IOSUiSettings(
        title: title,
        cropStyle: CropStyle.circle,
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
      ),
    ],
  );
  return cropped?.path;
}
