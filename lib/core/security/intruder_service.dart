import 'dart:io';

import 'package:camera/camera.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class IntruderService {
  /// Captures an intruder selfie using the front camera
  /// and stores the image path + timestamp in Hive
  static Future<void> captureIntruderSelfie() async {
    try {
      // 1️⃣ Get available cameras
      final cameras = await availableCameras();

      // 2️⃣ Select front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      // 3️⃣ Initialize camera controller
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await controller.initialize();

      // 4️⃣ Prepare file path
      final directory = await getApplicationDocumentsDirectory();
      final imagePath =
          '${directory.path}/intruder_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 5️⃣ Capture image
      final XFile picture = await controller.takePicture();
      final File imageFile = File(picture.path);
      await imageFile.copy(imagePath);

      // 6️⃣ Dispose camera
      await controller.dispose();

      // 7️⃣ Save log in Hive
      final box = Hive.box('securityBox');
      final List intruderLogs =
          box.get('intruderLogs', defaultValue: []);

      intruderLogs.add({
        'imagePath': imagePath,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await box.put('intruderLogs', intruderLogs);
    } catch (e) {
      // ❌ Fail silently (important for lock screen UX)
      print('IntruderService Error: $e');
    }
  }
}
