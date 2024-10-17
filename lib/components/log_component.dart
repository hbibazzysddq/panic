import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../service/log_service.dart';

class LogComponent extends StatefulWidget {
  final LogService logService;

  const LogComponent({
    super.key,
    required this.logService,
    required Map<String, List<String>> logEntries,
  });

  @override
  // ignore: library_private_types_in_public_api
  _LogComponentState createState() => _LogComponentState();
}

class _LogComponentState extends State<LogComponent> {
  late Future<Map<String, List<String>>> _logEntriesFuture;

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() {
    setState(() {
      _logEntriesFuture = widget.logService.loadAllLogEntries();
    });
  }

  Future<String> _getSafeFilePath(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$fileName';
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.storage.isGranted) {
      return true;
    }

    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    // Untuk Android 11 ke atas, cek izin MANAGE_EXTERNAL_STORAGE
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    // Untuk Android 10 ke bawah, minta izin storage biasa
    var status = await Permission.storage.request();
    return status.isGranted;
  }

  void _exportLog(BuildContext context) async {
    try {
      final file = await widget.logService.exportLogToFile();
      await Share.shareXFiles([XFile(file.path)], text: 'Timestamp Log');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export log: $e')),
      );
    }
  }

  Future<void> _downloadLog(BuildContext context) async {
    try {
      print("Starting download process");

      // Request storage permission
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        print("Storage permission denied");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Storage permission is required to save the file')),
        );
        return;
      }

      // Let user pick save location
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        print("No directory selected");
        return;
      }

      final fileName =
          'panic_button_log_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('$selectedDirectory/$fileName');

      print("Attempting to write to file: ${file.path}");

      // Get log content
      final logContent = await widget.logService.getLogContent();

      // Write to file
      await file.writeAsString(logContent);

      print("File written successfully");

      // Verify file content
      final verificationContent = await file.readAsString();
      print("Verification: File content length: ${verificationContent.length}");

      if (verificationContent.isEmpty) {
        print("Warning: File is empty after writing");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Log file saved at: ${file.path}')),
      );
    } catch (e, stackTrace) {
      print('Error in _downloadLog: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save log: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          AppBar(
            title: Text('Timestamp Log'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _refreshLogs,
                tooltip: 'Refresh Logs',
              ),
              IconButton(
                icon: Icon(Icons.share),
                onPressed: () => _exportLog(context),
                tooltip: 'Export Log',
              ),
              IconButton(
                icon: Icon(Icons.download),
                onPressed: () => _downloadLog(context),
                tooltip: 'Download Log',
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<Map<String, List<String>>>(
              future: _logEntriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No log entries'));
                } else {
                  return ListView(
                    children: snapshot.data!.entries.map((entry) {
                      return ExpansionTile(
                        title: Text(entry.key),
                        children: entry.value
                            .map((logEntry) => ListTile(
                                  title: Text(logEntry),
                                ))
                            .toList(),
                      );
                    }).toList(),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
