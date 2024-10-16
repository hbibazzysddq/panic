import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class DeviceInfo {
  final String id;
  final LatLng location;
  DateTime lastActivity;
  bool isActive;

  Timer? inactivityTimer;

  DeviceInfo({
    required this.id,
    required this.location,
    required this.lastActivity,
    this.isActive = false,
  });

  String get displayId {
    if (id.startsWith('id-')) {
      return id.substring(3);
    }
    return id;
  }
}
