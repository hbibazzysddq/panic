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

    print('Found ${keys.length} keys in SharedPreferences');

    List<String> sortedKeys = keys
        .where((key) => key.startsWith('log_'))
        .toList()
      ..sort((a, b) => b.compareTo(a));

    print('Found ${sortedKeys.length} log keys');

    for (final key in sortedKeys) {
      final value = prefs.get(key);
      List<String> entries = [];
      if (value is String) {
        try {
          entries = List<String>.from(json.decode(value));
          print('Decoded ${entries.length} entries for key: $key');
        } catch (e) {
          print('Error decoding entries for key $key: $e');
          entries = [value];
        }
      } else if (value is List) {
        entries = value.map((e) => e.toString()).toList();
        print('Converted ${entries.length} list entries for key: $key');
      }
      entries = entries.reversed.toList();
      logEntries[key.substring(4)] = entries;
    }

    print('Total log entries: ${logEntries.length} dates');
    return logEntries;
  }

  Future<void> addLogEntry(String entry) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm:ss').format(now);
    final logEntry = "$timeStr: $entry";

    final prefs = await SharedPreferences.getInstance();
    final key = 'log_$dateStr';
    List<String> entries = [];

    final existingValue = prefs.get(key);
    if (existingValue != null) {
      if (existingValue is String) {
        try {
          entries = List<String>.from(json.decode(existingValue));
        } catch (e) {
          entries = [existingValue];
        }
      } else if (existingValue is List) {
        entries = existingValue.map((e) => e.toString()).toList();
      }
    }

    entries.insert(0, logEntry); // Insert new entry at the beginning
    await prefs.setString(key, json.encode(entries));

    // Also write to file for backup
    final file = await _getLogFile();
    await file.writeAsString('$dateStr $logEntry\n', mode: FileMode.append);
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
