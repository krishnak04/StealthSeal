import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class IntruderLogsScreen extends StatefulWidget {
  const IntruderLogsScreen({super.key});

  @override
  State<IntruderLogsScreen> createState() => _IntruderLogsScreenState();
}

class _IntruderLogsScreenState extends State<IntruderLogsScreen> {
  @override
  Widget build(BuildContext context) {
    // Open the box (ensure it's already opened in main or handle async if needed)
    final box = Hive.box('securityBox');
    final List logs = box.get('intruderLogs', defaultValue: []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intruder Logs'),
      ),
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final log = logs[index];
                final String imagePath = log['imagePath'];
                final String time = log['timestamp'];

                return GestureDetector(
                  onTap: () => _showFullImage(context, imagePath, time),
                  // Added the delete functionality here
                  onLongPress: () => _confirmDelete(context, imagePath, log),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade900,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.file(
                              File(imagePath),
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            time.split('T').first,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
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
    String imagePath,
    String timestamp,
  ) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.file(File(imagePath)),
              const SizedBox(height: 10),
              const Text(
                'Captured automatically after multiple failed PIN attempts.',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Time: $timestamp',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    String imagePath,
    dynamic log,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Intruder Image'),
        content: const Text(
          'Do you want to permanently delete this intruder record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              // 1️⃣ Delete image file
              final file = File(imagePath);
              if (file.existsSync()) {
                await file.delete();
              }

              // 2️⃣ Remove log from Hive
              final box = Hive.box('securityBox');
              final List logs = box.get('intruderLogs', defaultValue: []);

              // Remove the specific log entry
              logs.removeWhere(
                  (element) => element['timestamp'] == log['timestamp']);

              // Save the updated list back to Hive
              await box.put('intruderLogs', logs);

              if (mounted) {
                Navigator.pop(context); // Close dialog
                setState(() {}); // Refresh UI
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Intruder record deleted')),
                );
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