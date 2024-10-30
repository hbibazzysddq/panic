import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  Future<bool> requestPermissions(BuildContext context) async {
    try {
      // Request multiple permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.manageExternalStorage,
        Permission.notification,
        Permission.location,
        Permission.locationAlways,
      ].request();

      bool allGranted = true;
      List<String> deniedPermissions = [];

      // Check each permission status
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          allGranted = false;
          deniedPermissions.add(_getPermissionName(permission));
        }
      });

      // If any permission is denied, show dialog
      if (!allGranted && context.mounted) {
        await _showPermissionDialog(context, deniedPermissions);
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Permission request error: $e');
      return false;
    }
  }

  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.storage:
        return 'Storage';
      case Permission.manageExternalStorage:
        return 'Manage Storage';
      case Permission.notification:
        return 'Notifications';
      case Permission.location:
        return 'Location';
      case Permission.locationAlways:
        return 'Background Location';
      default:
        return permission.toString();
    }
  }

  Future<void> _showPermissionDialog(
      BuildContext context, List<String> permissions) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              const Text('The following permissions are required:'),
              const SizedBox(height: 10),
              ...permissions.map((permission) => Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text('• $permission',
                        style: const TextStyle(fontSize: 14)),
                  )),
              const SizedBox(height: 10),
              const Text(
                  'Please enable these permissions in settings to continue.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
