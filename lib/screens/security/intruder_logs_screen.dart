import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../../core/theme/theme_config.dart';

class IntruderLogsScreen extends StatefulWidget {
  const IntruderLogsScreen({super.key});

  @override
  State<IntruderLogsScreen> createState() => _IntruderLogsScreenState();
}

class _IntruderLogsScreenState extends State<IntruderLogsScreen> {
  static const platform = MethodChannel('com.stealthseal.app/applock');
  
  @override
  void initState() {
    super.initState();
    _syncIntruderLogsFromNative();
  }

  Future<void> _syncIntruderLogsFromNative() async {
    try {
      final result = await platform.invokeMethod('getIntruderLogs');
      if (result is List) {
        final securityBox = Hive.box('securityBox');

        final List nativeLogsRaw = result.map((log) => Map<String, dynamic>.from(log as Map)).toList();

        final List existingLogs = (securityBox.get('intruderLogs', defaultValue: []) as List)
          .map((log) => Map<String, dynamic>.from(log as Map))
          .toList();

        final List mergedLogs = [...existingLogs];

        final existingPaths = existingLogs.map((l) => l['imagePath']).toSet();
        for (var nativeLog in nativeLogsRaw) {
          final imagePath = nativeLog['imagePath'];
          if (imagePath != null && !existingPaths.contains(imagePath)) {
            mergedLogs.add(nativeLog);
            debugPrint(' Added new log from locked app: $imagePath');
          }
        }

        mergedLogs.sort((a, b) {
          try {
            final timeA = DateTime.parse(a['timestamp']?.toString() ?? '');
            final timeB = DateTime.parse(b['timestamp']?.toString() ?? '');
            return timeB.compareTo(timeA);
          } catch (_) {
            return 0;
          }
        });

        if (mergedLogs.isNotEmpty) {
          await securityBox.put('intruderLogs', mergedLogs);
          debugPrint(' Merged intruder logs: ${mergedLogs.length} total (${nativeLogsRaw.length} from locked app, ${existingLogs.length} main app)');
        }
        
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Warning: Failed to sync intruder logs from native: $e');
    }
  }

  Future<void> _removeLogFromNative(String imagePath, String timestamp) async {
    try {
      
      await platform.invokeMethod('removeIntruderLog', {
        'imagePath': imagePath,
        'timestamp': timestamp,
      });
      debugPrint(' Removed log from native: $imagePath');
    } catch (e) {
      debugPrint('Warning: Failed to remove from native logs: $e');
    }
  }

  Widget _buildImageWidget(String imagePath, BuildContext context) {
    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint(' Error loading image: $error');
            return Center(
              child: Icon(
                Icons.broken_image,
                color: ThemeConfig.textSecondary(context),
                size: 32,
              ),
            );
          },
        );
      } else {
        debugPrint(' Image file not found: $imagePath');
        return Center(
          child: Icon(
            Icons.image_not_supported,
            color: ThemeConfig.textSecondary(context),
            size: 32,
          ),
        );
      }
    } catch (e) {
      debugPrint(' Error building image widget: $e');
      return Center(
        child: Icon(
          Icons.error,
          color: ThemeConfig.textSecondary(context),
          size: 32,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final securityBox = Hive.box('securityBox');
    final List logs = securityBox.get('intruderLogs', defaultValue: []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intruder Logs'),
        backgroundColor: ThemeConfig.appBarBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: ThemeConfig.backgroundColor(context),
      body: logs.isEmpty
          ? Center(
              child: Text(
                'No intruders detected',
                style: TextStyle(color: ThemeConfig.textSecondary(context)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final String? imagePath = log['imagePath'];
                final String reason = log['reason'] ?? 'Failed Attempt';
                final String pin = log['enteredPin']?.toString() ?? '***';
                final String timestamp = log['timestamp'] ?? '';

                DateTime? time;
                try {
                  time = DateTime.parse(timestamp);
                } catch (_) {
                  time = null;
                }

                bool imageExists = false;
                if (imagePath != null && imagePath.isNotEmpty) {
                  final file = File(imagePath);
                  imageExists = file.existsSync();
                  
                  if (!imageExists) {
                    debugPrint(' Image file not found: $imagePath');
                  }
                }

                final timeStr = time != null
                   ? () {
                         final t = time!; 
                         final hour12 = t.hour > 12
                         ? t.hour - 12
                         : (t.hour == 0 ? 12 : t.hour);
                         final period = t.hour >= 12 ? 'pm' : 'am';
                         return '${t.day}/${t.month}/${t.year}, '
                         '${hour12.toString().padLeft(2, '0')}:'
                         '${t.minute.toString().padLeft(2, '0')}:'
                         '${t.second.toString().padLeft(2, '0')} $period';
                        }()
                : 'Time unavailable';

                return GestureDetector(
                  onTap: () => _showFullImage(context, imagePath, reason, pin, timeStr),
                  onLongPress: () => _confirmDelete(context, log),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ThemeConfig.surfaceColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [

                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 80,
                            height: 80,
                            color: ThemeConfig.inputBackground(context),
                            child: imageExists && imagePath != null
                                ? _buildImageWidget(imagePath, context)
                                : Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.image_not_supported,
                                          color: ThemeConfig.textSecondary(context),
                                          size: 28,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'No Image',
                                          style: TextStyle(
                                            color: ThemeConfig.textSecondary(context),
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reason,
                                style: TextStyle(
                                  color: ThemeConfig.textPrimary(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 12, color: ThemeConfig.textSecondary(context)),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      color: ThemeConfig.textSecondary(context),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.lock, size: 12, color: ThemeConfig.textSecondary(context)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PIN: $pin',
                                    style: TextStyle(
                                      color: ThemeConfig.textSecondary(context),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: ThemeConfig.errorColor(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showFullImage(
    BuildContext context,
    String? imagePath,
    String reason,
    String pin,
    String timeStr,
  ) {
    final bool imageExists = imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync();
    
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: ThemeConfig.cardColor(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageExists)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: ThemeConfig.inputBackground(context),
                    ),
                    child: _buildImageWidget(imagePath, context),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: ThemeConfig.inputBackground(context),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: ThemeConfig.textSecondary(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image not available',
                          style: TextStyle(
                            color: ThemeConfig.textSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  reason,
                  style: TextStyle(color: ThemeConfig.errorColor(context), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'PIN: $pin',
                  style: TextStyle(color: ThemeConfig.textSecondary(context), fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  'Time: $timeStr',
                  style: TextStyle(color: ThemeConfig.textSecondary(context), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    dynamic log,
  ) {
    final String? imagePath = log['imagePath'];
    final bool imageExists = imagePath != null && File(imagePath).existsSync();
    final String pin = log['enteredPin']?.toString() ?? '***';
    final String timestamp = log['timestamp'] ?? '';

    DateTime? time;
    try {
      time = DateTime.parse(timestamp);
    } catch (_) {
      time = null;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ThemeConfig.cardColor(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 350,
            maxHeight: 550,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Delete Intruder Record',
                  style: TextStyle(
                    color: ThemeConfig.errorColor(ctx),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      if (imageExists)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ThemeConfig.errorColor(ctx),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ThemeConfig.errorColor(ctx).withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: double.infinity,
                              height: 150,
                              child: _buildImageWidget(imagePath, ctx),
                            ),
                          ),
                        )
                      else
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: ThemeConfig.surfaceColor(ctx),
                            border: Border.all(
                              color: ThemeConfig.errorColor(ctx),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: ThemeConfig.textSecondary(ctx),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Image not available',
                                  style: TextStyle(
                                    color: ThemeConfig.textSecondary(ctx),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThemeConfig.errorColor(ctx).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ThemeConfig.errorColor(ctx).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  color: ThemeConfig.errorColor(ctx),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Intruder Record Details',
                                    style: TextStyle(
                                      color: ThemeConfig.errorColor(ctx),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PIN Entered: $pin',
                              style: TextStyle(
                                color: ThemeConfig.textSecondary(ctx),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Time: ${time != null ? '${time.day}/${time.month}/${time.year} ${time.hour}:${time.minute.toString().padLeft(2, '0')}' : 'N/A'}',
                              style: TextStyle(
                                color: ThemeConfig.textSecondary(ctx),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      Text(
                        'This will permanently delete this intruder record and image. This action cannot be undone.',
                        style: TextStyle(
                          color: ThemeConfig.textSecondary(ctx),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: ThemeConfig.accentColor(ctx)),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final securityBox = Hive.box('securityBox');
                        final List logs = securityBox.get('intruderLogs', defaultValue: []);

                        if (log['imagePath'] != null) {
                          final file = File(log['imagePath']);
                          if (file.existsSync()) {
                            try {
                              await file.delete();
                              debugPrint(' Deleted intruder image: ${log['imagePath']}');
                            } catch (e) {
                              debugPrint(' Error deleting image file: $e');
                            }
                          }
                        }

                        logs.remove(log);
                        await securityBox.put('intruderLogs', logs);

                        if (log['imagePath'] != null && log['timestamp'] != null) {
                          await _removeLogFromNative(log['imagePath'], log['timestamp']);
                        }

                        if (context.mounted) {
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 12),
                                  const Text('Intruder record deleted'),
                                ],
                              ),
                              backgroundColor: ThemeConfig.errorColor(context),
                              duration: const Duration(seconds: 2),
                            ),
                          );

                          setState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConfig.errorColor(ctx),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
