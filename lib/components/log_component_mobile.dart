import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

Future<void> handleLogAction(String logContent) async {
  // Meminta permission akses storage
  final status = await Permission.storage.request();

  if (status.isGranted) {
    // Memilih lokasi penyimpanan menggunakan FilePicker
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      // Menyimpan log ke file .txt di direktori yang dipilih oleh pengguna
      final file = File('$selectedDirectory/panic_button_log.txt');
      await file.writeAsString(logContent);

      // Feedback untuk pengguna bahwa file telah disimpan
      print('Log saved to: ${file.path}');
    } else {
      print('No directory selected');
    }
  } else {
    throw Exception('Storage permission denied');
  }
}
