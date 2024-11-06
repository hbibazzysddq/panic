import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<void> handleLogAction(String logContent) async {
  try {
    // Cek permission storage terlebih dahulu
    PermissionStatus status = await Permission.storage.status;

    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        // Coba request MANAGE_EXTERNAL_STORAGE untuk Android 10+
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          throw Exception('Izin penyimpanan diperlukan untuk mengunduh log');
        }
      }
    }

    // Jika permission diberikan, lanjutkan dengan penyimpanan file
    String? selectedDirectory;

    try {
      selectedDirectory = await FilePicker.platform.getDirectoryPath();
    } catch (e) {
      // Jika FilePicker gagal, gunakan direktori download default
      final directory = await getExternalStorageDirectory();
      selectedDirectory = directory?.path;
    }

    if (selectedDirectory == null) {
      throw Exception('Tidak dapat mengakses direktori penyimpanan');
    }

    // Generate nama file dengan timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('$selectedDirectory/panic_button_log_$timestamp.txt');

    // Tulis file
    await file.writeAsString(logContent);

    print('Log berhasil disimpan di: ${file.path}');
  } catch (e) {
    print('Error saat menyimpan log: $e');
    rethrow;
  }
}
