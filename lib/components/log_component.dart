import 'dart:convert';
import 'dart:io';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../service/log_service.dart';

class LogComponent extends StatefulWidget {
  final LogService logService;

  const LogComponent({
    Key? key,
    required this.logService,
    required Map<String, List<String>> logEntries,
  }) : super(key: key);

  @override
  _LogComponentState createState() => _LogComponentState();
}

class _LogComponentState extends State<LogComponent> {
  late Future<Map<String, List<String>>> _logEntriesFuture;
  bool _isProcessing = false;

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

  Future<bool> _requestStoragePermission() async {
    if (!kIsWeb) {
      if (await Permission.storage.isGranted) return true;
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.manageExternalStorage.request().isGranted)
        return true;
      return await Permission.storage.request().isGranted;
    }
    return true;
  }

  void _handleLogAction(BuildContext context) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final logContent = await widget.logService.getLogContent();
      if (logContent.isEmpty) {
        throw Exception('No log entries to export');
      }

      if (kIsWeb) {
        _downloadLogWeb(logContent);
      } else {
        await _shareLogMobile(logContent);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                kIsWeb ? 'Log file downloaded' : 'Log shared successfully')),
      );
    } catch (e) {
      print('Error handling log action: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process log: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _downloadLogWeb(String logContent) {
    final bytes = utf8.encode(logContent);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "panic_button_log.txt")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _shareLogMobile(String logContent) async {
    if (!await _requestStoragePermission()) {
      throw Exception('Storage permission denied');
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/panic_button_log.txt');
    await file.writeAsString(logContent);
    await Share.shareXFiles([XFile(file.path)], text: 'Timestamp Log');
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
                icon: Icon(kIsWeb ? Icons.download : Icons.share),
                onPressed:
                    _isProcessing ? null : () => _handleLogAction(context),
                tooltip: kIsWeb ? 'Download Log' : 'Share Log',
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
