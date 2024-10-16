import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../service/log_service.dart';

class LogComponent extends StatelessWidget {
  final Map<String, List<String>> logEntries;
  final LogService logService;

  const LogComponent({
    Key? key,
    required this.logEntries,
    required this.logService,
  }) : super(key: key);

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
