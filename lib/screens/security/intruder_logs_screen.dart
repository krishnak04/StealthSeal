import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class IntruderLogsScreen extends StatefulWidget {
  const IntruderLogsScreen({super.key});

  @override
  State<IntruderLogsScreen> createState() => _IntruderLogsScreenState();
}

class _IntruderLogsScreenState extends State<IntruderLogsScreen> {
  @override
  Widget build(BuildContext context) {
    final box = Hive.box('securityBox');
    late String currentTime;
    late String currentDate;
    final List logs = box.get('intruderLogs', defaultValue: []);

    return Scaffold(
      appBar: AppBar(title: const Text('Intruder Logs')),
      body: logs.isEmpty
          ? const Center(
              child: Text(
                'No intruders detected',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final log = logs[index];

                final String? imagePath = log['imagePath'];
                final String reason =
                    log['reason'] ?? 'Captured Intruder Image';
                final String pin =
                    log['enteredPin']?.toString() ?? '***';
                final String timestamp =
                    log['timestamp'] ?? '';

                DateTime? time;
                try {

                  time = DateTime.parse(timestamp);
               currentDate =   DateFormat('dd/MM/yyyy').format(time);

              currentTime =  DateFormat('h:mm a').format(time);


                                 
                  debugPrint('Parsed time: $time');
                } catch (_) {
                  time = null;
                }

                final bool imageExists =
                    imagePath != null &&
                        File(imagePath).existsSync();

                return GestureDetector(
                  onTap: () => _showFullImage(
                    context,
                    imagePath,
                    reason,
                    pin,
                            currentTime,
                            currentDate,

                  ),
                  onLongPress: () =>
                      _confirmDelete(context, log),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade900,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius:
                                const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: imageExists
                                ? Image.file(
                                    File(imagePath!),
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.person_off,
                                      color: Colors.white54,
                                    ),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                reason,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                time != null
                                    ? '${time.day}/${time.month}/${time.year} '
                                      '${time.hour}:${time.minute.toString().padLeft(2, '0')}'
                                    : 'Time unavailable',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                'PIN: $pin',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
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
   String currentTime,
   String currentDate,
  ) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (imagePath != null &&
                  File(imagePath).existsSync())
                Image.file(File(imagePath)),
              const SizedBox(height: 10),
              Text(
                reason,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'PIN: $pin',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
           
                'Time : $currentDate , $currentTime'
                  ,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Intruder Record'),
        content: const Text(
          'Do you want to permanently delete this record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final box = Hive.box('securityBox');
              final List logs =
                  box.get('intruderLogs', defaultValue: []);

              if (log['imagePath'] != null) {
                final file = File(log['imagePath']);
                if (file.existsSync()) {
                  await file.delete();
                }
              }

              logs.remove(log);
              await box.put('intruderLogs', logs);

              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
