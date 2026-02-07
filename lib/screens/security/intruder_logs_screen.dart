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
                  child: Stack(
                    children: [
                      Container(
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
                                        File(imagePath),
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
                      // 🗑️ Delete Button in Top-Right Corner
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () =>
                                _confirmDelete(context, log),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ),
                    ],
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
      builder: (_) => Dialog(
        backgroundColor: Colors.grey.shade900,
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
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '🚨 Delete Intruder Record',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 📸 Show the intruder image in real-time (reduced height)
                      if (imageExists)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.redAccent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.3),
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
                            color: Colors.grey.shade800,
                            border: Border.all(
                              color: Colors.redAccent,
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
                      
                      // 📋 Intruder Details
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Captured Intruder Image',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PIN Entered: $pin',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Time: ${time != null ? '${time.day}/${time.month}/${time.year} ${time.hour}:${time.minute.toString().padLeft(2, '0')}' : 'N/A'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      const Text(
                        'Are you sure you want to permanently delete this intruder record?',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.cyan),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final box = Hive.box('securityBox');
                        final List logs = box.get('intruderLogs', defaultValue: []);

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
                          
                          // Show deletion confirmation
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text('Intruder record deleted'),
                                ],
                              ),
                              backgroundColor: Colors.redAccent,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          
                          setState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
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
