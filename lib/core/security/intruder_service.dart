import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

/// Captures and logs intruder selfies on repeated failed PIN attempts.
///
/// Uses the front camera to take a photo and stores metadata
/// (image path, timestamp, reason, entered PIN) in Hive.
/// Fails silently to avoid disrupting the lock screen UX.
class IntruderService {
  /// Captures an intruder selfie and persists metadata to Hive.
  ///
  /// [reason] describes why the capture was triggered.
  /// [enteredPin] is the PIN that was entered (masked by default).
  static Future<void> captureIntruderSelfie({
    String reason = 'Captured Intruder Image',
    String? enteredPin,
  }) async {
    try {
      final cameras = await availableCameras();

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      final cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await cameraController.initialize();

      final directory = await getApplicationDocumentsDirectory();
      final imagePath =
          '${directory.path}/intruder_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final XFile picture = await cameraController.takePicture();
      await File(picture.path).copy(imagePath);

      await cameraController.dispose();

      // Save capture metadata to Hive intruder logs
      final securityBox = Hive.box('securityBox');
      final List intruderLogs =
          securityBox.get('intruderLogs', defaultValue: []);

      intruderLogs.add({
        'imagePath': imagePath,
        'timestamp': DateTime.now().toIso8601String(),
        'reason': reason,
        'enteredPin': enteredPin ?? '***',
      });

      await securityBox.put('intruderLogs', intruderLogs);
    } catch (error) {
      // Fail silently to avoid lock-screen crash
      debugPrint('IntruderService Error: $error');
    }
  }
}
