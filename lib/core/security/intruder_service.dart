import 'dart:io';

import 'package:camera/camera.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class IntruderService {
  /// Capture intruder selfie and store metadata safely
  static Future<void> captureIntruderSelfie({
    String reason = 'Captured Intruder Image',
    String? enteredPin,
  }) async {
    try {
      final cameras = await availableCameras();

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await controller.initialize();

      final directory = await getApplicationDocumentsDirectory();
      final imagePath =
          '${directory.path}/intruder_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final XFile picture = await controller.takePicture();
      await File(picture.path).copy(imagePath);

      await controller.dispose();

      // ✅ SAVE FULL METADATA
      final box = Hive.box('securityBox');
      final List logs = box.get('intruderLogs', defaultValue: []);

      logs.add({
        'imagePath': imagePath,
        'timestamp': DateTime.now().toIso8601String(),
        'reason': reason,
        'enteredPin': enteredPin ?? '***',
      });

      await box.put('intruderLogs', logs);
    } catch (e) {
      // Fail silently to avoid lock-screen crash
      print('IntruderService Error: $e');
    }
  }
}
