import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/features/site_survey/presentation/survey_image.dart';
import 'package:solar_sales/features/site_survey/presentation/widgets/signature_pad.dart';

/// Shared camera / gallery / signature / GPS flows for survey forms.
class SurveyCapture {
  SurveyCapture._();

  static Future<ImageSource?> chooseImageSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  static Future<Uint8List?> pickPreparedImage(
    BuildContext context, {
    ImageSource? source,
  }) async {
    final chosen = source ?? await chooseImageSource(context);
    if (chosen == null) return null;
    try {
      final picked = await ImagePicker().pickImage(
        source: chosen,
        imageQuality: 85,
      );
      if (picked == null) return null;
      final prepared = await prepareSurveyImage(await picked.readAsBytes());
      return prepared.$1;
    } catch (error) {
      if (context.mounted) {
        showAppMessage(context, 'Could not add photo: $error', isError: true);
      }
      return null;
    }
  }

  static Future<Uint8List?> captureSignature(
    BuildContext context, {
    required String title,
  }) async {
    final padKey = GlobalKey<SignaturePadState>();
    final bytes = await showDialog<Uint8List>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 360, child: SignaturePad(key: padKey)),
        actions: [
          TextButton(
            onPressed: () => padKey.currentState?.clear(),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final png = await padKey.currentState?.export();
              if (!context.mounted) return;
              if (png == null) {
                showAppMessage(context, 'Please draw a signature first', isError: true);
                return;
              }
              Navigator.pop(context, png);
            },
            child: const Text('Use signature'),
          ),
        ],
      ),
    );
    if (bytes == null) return null;
    try {
      final prepared = await prepareSurveyImage(bytes);
      return prepared.$1;
    } catch (error) {
      if (context.mounted) {
        showAppMessage(context, 'Could not save signature: $error', isError: true);
      }
      return null;
    }
  }

  static Future<Map<String, dynamic>?> captureLocation(BuildContext context) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          showAppMessage(
            context,
            'Turn on location services to capture the site',
            isError: true,
          );
        }
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          showAppMessage(
            context,
            permission == LocationPermission.deniedForever
                ? 'Location permission is permanently denied. Enable it in app settings.'
                : 'Location permission is needed to capture the site',
            isError: true,
          );
        }
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
      };
    } catch (error) {
      if (context.mounted) {
        showAppMessage(context, 'Could not capture location: $error', isError: true);
      }
      return null;
    }
  }
}
