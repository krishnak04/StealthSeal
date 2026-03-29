import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class IntruderService {

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

      // Use a persistent directory (same as native implementation)
      final appDocDir = await getApplicationDocumentsDirectory();
      final intruderDir = Directory('${appDocDir.path}/intruder_logs');
      if (!await intruderDir.exists()) {
        await intruderDir.create(recursive: true);
      }
      
      final imagePath = '${intruderDir.path}/intruder_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final XFile picture = await cameraController.takePicture();
      await File(picture.path).copy(imagePath);

      await cameraController.dispose();

      debugPrint('✅ Intruder image captured: $imagePath');
      debugPrint('✅ Image file exists: ${await File(imagePath).exists()}');
      debugPrint('✅ Image file size: ${await File(imagePath).length()} bytes');

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
      debugPrint('✅ Intruder log saved to Hive');
    } catch (error) {

      debugPrint('❌ IntruderService Error: $error');
    }
  }
}
