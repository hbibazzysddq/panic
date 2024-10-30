import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

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
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final key = 'log_$dateStr';
    List<String> entries = [];

    if (prefs.containsKey(key)) {
      entries = List<String>.from(jsonDecode(prefs.getString(key) ?? '[]'));
    }
    entries.add("$timeStr - $entry");

    await prefs.setString(key, jsonEncode(entries));
    print("Log entry added: $entry");
  }

  Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/panic_button_log.txt');
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

    final sortedDates = logEntries.keys.toList()..sort();
    for (var date in sortedDates) {
      buffer.writeln('=== $date ===');
      final entries = logEntries[date]!;
      for (var entry in entries) {
        buffer.writeln('  $entry');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  // Export to TXT file
  Future<File> exportLogToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'panic_button_log_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');

      print('Exporting log to TXT file: ${file.path}');

      final logEntries = await loadAllLogEntries();
      print('Loaded log entries: ${logEntries.length} dates');

      if (logEntries.isEmpty) {
        print('Warning: No log entries found');
        await file.writeAsString('No log entries found');
        return file;
      }

      final buffer = StringBuffer();
      final sortedDates = logEntries.keys.toList()..sort();

      for (var date in sortedDates) {
        buffer.writeln('=== $date ===');
        final entries = logEntries[date]!;
        for (var entry in entries) {
          buffer.writeln('  $entry');
        }
        buffer.writeln();
      }

      final content = buffer.toString();
      await file.writeAsString(content);

      final verificationContent = await file.readAsString();
      if (verificationContent.isEmpty) {
        print('Warning: TXT file is empty after writing');
      } else {
        print('TXT file successfully written');
      }

      return file;
    } catch (e, stackTrace) {
      print('Error exporting TXT file: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Export to CSV file
  Future<File> exportLogToCSV() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'panic_button_log_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');

      print('Exporting log to CSV file: ${file.path}');

      final logEntries = await loadAllLogEntries();
      print('Loaded log entries: ${logEntries.length} dates');

      if (logEntries.isEmpty) {
        print('Warning: No log entries found');
        await file.writeAsString('Date,Time,Event\n');
        return file;
      }

      final buffer = StringBuffer();
      buffer.writeln('Date,Time,Event');

      final sortedDates = logEntries.keys.toList()..sort();

      for (var date in sortedDates) {
        final entries = logEntries[date]!;
        for (var entry in entries) {
          final parts = entry.split(' - ');
          if (parts.length == 2) {
            final time = parts[0];
            final event = parts[1].replaceAll(',', ';').replaceAll('"', "'");
            buffer.writeln('$date,$time,"$event"');
          }
        }
      }

      final content = buffer.toString();
      await file.writeAsString(content);

      final verificationContent = await file.readAsString();
      if (verificationContent.isEmpty) {
        print('Warning: CSV file is empty after writing');
      } else {
        print('CSV file successfully written');
      }

      return file;
    } catch (e, stackTrace) {
      print('Error exporting CSV file: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get file path
  Future<String> getLogFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Read CSV file
  Future<List<Map<String, String>>> readCSVFile(String filePath) async {
    try {
      final file = File(filePath);
      final contents = await file.readAsString();
      final lines = contents.split('\n');

      if (lines.isEmpty || lines[0].trim().isEmpty) {
        return [];
      }

      final headers = lines[0].trim().split(',');
      final results = <Map<String, String>>[];

      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;

        final values = _parseCSVLine(lines[i]);
        if (values.length == headers.length) {
          final map = <String, String>{};
          for (var j = 0; j < headers.length; j++) {
            map[headers[j]] = values[j];
          }
          results.add(map);
        }
      }

      return results;
    } catch (e) {
      print('Error reading CSV file: $e');
      return [];
    }
  }

  // Parse CSV line
  List<String> _parseCSVLine(String line) {
    final values = <String>[];
    bool inQuotes = false;
    StringBuffer currentValue = StringBuffer();

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        values.add(currentValue.toString().trim());
        currentValue.clear();
      } else {
        currentValue.write(char);
      }
    }

    values.add(currentValue.toString().trim());
    return values.map((v) => v.replaceAll('"', '')).toList();
  }

  // Clear old logs
  Future<void> clearOldLogs(int daysToKeep) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final keys =
          prefs.getKeys().where((key) => key.startsWith('log_')).toList();

      for (final key in keys) {
        final dateStr = key.substring(4); // Remove 'log_' prefix
        final date = DateTime.parse(dateStr);
        final difference = now.difference(date).inDays;

        if (difference > daysToKeep) {
          await prefs.remove(key);
          print('Removed old log: $key');
        }
      }
    } catch (e) {
      print('Error clearing old logs: $e');
    }
  }
}
