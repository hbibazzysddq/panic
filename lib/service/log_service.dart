import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogService {
  Future<Map<String, List<String>>> loadAllLogEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    print("Total keys in SharedPreferences: ${keys.length}");

    Map<String, List<String>> logEntries = {};

    for (final key in keys) {
      if (key.startsWith('log_')) {
        final entries =
            List<String>.from(jsonDecode(prefs.getString(key) ?? '[]'));
        logEntries[key.substring(4)] = entries;
        print("Loaded ${entries.length} entries for $key");
      }
    }

    print("Total log entries: ${logEntries.length} dates");
    return logEntries;
  }

  Future<void> addLogEntry(String entry) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final key = 'log_$dateStr';
    List<String> entries = [];

    if (prefs.containsKey(key)) {
      entries = List<String>.from(jsonDecode(prefs.getString(key) ?? '[]'));
    }
    entries.add("${now.hour}:${now.minute}:${now.second} - $entry");

    await prefs.setString(key, jsonEncode(entries));
    print("Log entry added: $entry");
  }

  Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    return File('$path/panic_button_log.txt');
  }

  Future<List<String>> getLogEntriesFromFile() async {
    try {
      final file = await _getLogFile();
      String contents = await file.readAsString();
      return contents
          .split('\n')
          .where((line) => line.isNotEmpty)
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('Error reading log file: $e');
      return [];
    }
  }

  Future<String> getLogContent() async {
    final logEntries = await loadAllLogEntries();
    final buffer = StringBuffer();

    logEntries.forEach((date, entries) {
      buffer.writeln(date);
      for (var entry in entries) {
        buffer.writeln('  $entry');
      }
      buffer.writeln();
    });

    return buffer.toString();
  }

  Future<File> exportLogToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'panic_button_log_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');

      print('Exporting log to file: ${file.path}');

      final logEntries = await loadAllLogEntries();
      print('Loaded log entries: ${logEntries.length} dates');

      if (logEntries.isEmpty) {
        print('Warning: No log entries found');
        await file.writeAsString('No log entries found');
        return file;
      }

      final buffer = StringBuffer();

      logEntries.forEach((date, entries) {
        buffer.writeln(date);
        for (var entry in entries) {
          buffer.writeln('  $entry');
        }
        buffer.writeln();
      });

      final content = buffer.toString();
      print('Log content length: ${content.length} characters');

      await file.writeAsString(content);

      // Verify the file content after writing
      final verificationContent = await file.readAsString();
      print(
          'Verification: File content length after writing: ${verificationContent.length} characters');

      if (verificationContent.isEmpty) {
        print('Warning: File is empty after writing');
      } else {
        print('Log file successfully written');
      }

      return file;
    } catch (e, stackTrace) {
      print('Error exporting log file: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<String> getLogFilePath() async {
    final file = await _getLogFile();
    return file.path;
  }

  Future<void> migrateOldLogEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith('log_')) {
        final value = prefs.get(key);
        if (value is List) {
          await prefs.setString(key,
              json.encode(value.map((e) => e.toString()).toList().reversed));
        } else if (value is String && !_isJsonArray(value)) {
          await prefs.setString(key, json.encode([value]));
        }
      }
    }
  }

  bool _isJsonArray(String str) {
    try {
      final decoded = json.decode(str);
      return decoded is List;
    } catch (_) {
      return false;
    }
  }
}
