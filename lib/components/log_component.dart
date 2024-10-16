import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../service/log_service.dart';

class LogComponent extends StatelessWidget {
  final Map<String, List<String>> logEntries;
  final LogService logService;

  const LogComponent({
    super.key,
    required this.logEntries,
    required this.logService,
  });

  void _exportLog(BuildContext context) async {
    try {
      final file = await logService.exportLogToFile();
      await Share.shareXFiles([XFile(file.path)], text: 'Timestamp Log');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export log: $e')),
      );
    }
  }

  void _downloadLog(BuildContext context) async {
    try {
      // Memilih lokasi untuk menyimpan file
      FilePickerResult? result = (await FilePicker.platform.saveFile(
        dialogTitle: 'Pilih lokasi untuk menyimpan log',
        fileName: 'timestamp_log.txt',
      )) as FilePickerResult?;

      if (result != null) {
        // Mendapatkan path dari file yang dipilih
        String? path = result.files.single.path;

        if (path != null) {
          // Menyimpan file di lokasi yang dipilih
          final file = await logService.exportLogToFile();
          await file.copy(path); // Menyalin file ke lokasi yang dipilih

          // Menampilkan pesan berhasil
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Log file saved at: $path')),
          );
        }
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download log: $e')),
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
            child: ListView(
              children: logEntries.entries.map((entry) {
                return ExpansionTile(
                  title: Text(entry.key),
                  children: entry.value
                      .map((logEntry) => ListTile(
                            title: Text(logEntry),
                          ))
                      .toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
