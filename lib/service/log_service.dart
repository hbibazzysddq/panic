// file: lib/services/log_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class LogService {
  Future<void> addLogEntry(String entry) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm:ss').format(now);
    final logEntry = "$timeStr: $entry";

    final prefs = await SharedPreferences.getInstance();
    List<String> currentLog = await getLogEntries(dateStr);
    currentLog.insert(0, logEntry);
    await prefs.setString('log_$dateStr', json.encode(currentLog));
  }

  Future<Map<String, List<String>>> loadAllLogEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    Map<String, List<String>> logEntries = {};

    for (final key in keys) {
      if (key.startsWith('log_')) {
        final dateStr = key.substring(4);
        final logJson = prefs.getString(key) ?? '[]';
        logEntries[dateStr] = List<String>.from(json.decode(logJson));
      }
    }

    return logEntries;
  }

  Future<List<String>> getLogEntries(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final logJson = prefs.getString('log_$date') ?? '[]';
    return List<String>.from(json.decode(logJson));
  }

  Future<File> exportLogToFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'timestamp_log_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file = File('${directory.path}/$fileName');

    final logEntries = await loadAllLogEntries();
    final buffer = StringBuffer();

    logEntries.forEach((date, entries) {
      buffer.writeln(date);
      entries.forEach((entry) {
        buffer.writeln('  $entry');
      });
      buffer.writeln();
    });

    await file.writeAsString(buffer.toString());
    return file;
  }
}
