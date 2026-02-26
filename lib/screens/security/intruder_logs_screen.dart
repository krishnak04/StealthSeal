import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../core/theme/theme_config.dart';

class IntruderLogsScreen extends StatefulWidget {
  const IntruderLogsScreen({super.key});

  @override
  State<IntruderLogsScreen> createState() => _IntruderLogsScreenState();
}

class _IntruderLogsScreenState extends State<IntruderLogsScreen> {

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

                final bool imageExists = imagePath != null && File(imagePath).existsSync();
                final timeStr = time != null
                    ? '${time.day}/${time.month}/${time.year}, ${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'pm' : 'am'}'
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
                            child: imageExists
                                ? Image.file(
                                    File(imagePath),
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.person_off,
                                      color: ThemeConfig.textSecondary(context),
                                      size: 32,
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
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: ThemeConfig.cardColor(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imagePath != null && File(imagePath).existsSync())
                Image.file(File(imagePath)),
              const SizedBox(height: 10),
              Text(
                reason,
                style: TextStyle(color: ThemeConfig.errorColor(context), fontSize: 12),
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
                            child: Image.file(
                              File(imagePath),
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: ThemeConfig.surfaceColor(ctx),
                            border: Border.all(
                              color: ThemeConfig.errorColor(ctx),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 60,
                              color: Colors.white54,
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
                                    'Captured Intruder Image',
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
                        'Are you sure you want to permanently delete this intruder record?',
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
                            await file.delete();
                          }
                        }

                        logs.remove(log);
                        await securityBox.put('intruderLogs', logs);

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
