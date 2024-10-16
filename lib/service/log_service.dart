import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogService {
  Future<Map<String, List<String>>> loadAllLogEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    Map<String, List<String>> logEntries = {};

    // Loop over the keys that start with 'log_'
    for (final key in keys) {
      if (key.startsWith('log_')) {
        final logJson =
            prefs.getString(key) ?? '[]'; // Safeguard with empty list if null
        logEntries[key.substring(4)] = List<String>.from(json.decode(logJson));
      }
    }

    // Ensure the function returns an empty map if no log entries found
    return logEntries.isEmpty ? {} : logEntries;
  }

  Future<void> addLogEntry(String entry) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm:ss').format(now);
    final logEntry = "$timeStr: $entry";

    final file = await _getLogFile();
    await file.writeAsString('$logEntry\n', mode: FileMode.append);
  }

  Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    return File('$path/log.txt');
  }

  Future<List<String>> getLogEntriesFromFile() async {
    try {
      final file = await _getLogFile();
      String contents = await file.readAsString();
      return contents.split('\n').where((line) => line.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
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

  Future<String> getLogFilePath() async {
    final file = await _getLogFile();
    return file.path;
  }
}
