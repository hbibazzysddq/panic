import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../service/log_service.dart';
import '../service/auth_service.dart';

// Conditional imports
import 'log_component_web.dart' if (dart.library.io) 'log_component_mobile.dart'
    as platform;

class LogComponent extends StatefulWidget {
  final LogService logService;
  final AuthService authService;

  const LogComponent({
    Key? key,
    required this.logService,
    required this.authService,
    required Map<String, List<String>> logEntries,
  }) : super(key: key);

  @override
  _LogComponentState createState() => _LogComponentState();
}

class _LogComponentState extends State<LogComponent> {
  late Future<Map<String, List<String>>> _logEntriesFuture;
  late AuthService _authService;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService;
    _refreshLogs();
  }

  void _refreshLogs() {
    setState(() {
      _logEntriesFuture = widget.logService.loadAllLogEntries();
    });
  }

  void _handleLogAction(BuildContext context) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final logContent = await widget.logService.getLogContent();
      if (logContent.isEmpty) {
        throw Exception('No log entries to export');
      }

      // Handle log action (download or share) based on platform
      await platform.handleLogAction(logContent);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Log downloaded and saved successfully'),
        ),
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

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi Logout'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Apakah Anda yakin ingin keluar?'),
                Text('Anda harus login kembali untuk mengakses aplikasi.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Logout'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _authService.logout();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        );
      },
    );
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
                icon: Icon(kIsWeb ? Icons.download : Icons.download),
                onPressed:
                    _isProcessing ? null : () => _handleLogAction(context),
                tooltip: kIsWeb ? 'Download Log' : 'Download Log',
              ),
              IconButton(
                icon: Icon(Icons.exit_to_app),
                onPressed: () => _showLogoutConfirmation(context),
                tooltip: 'Logout',
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
