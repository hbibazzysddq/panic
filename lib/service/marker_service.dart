import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import '../models/device_info.dart';

class MarkerService {
  Future<BitmapDescriptor> createCustomMarkerBitmap(
      Color color, double size) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;

    // Gambar lingkaran utama
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);

    // Gambar lingkaran dalam berwarna putih
    final centerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 4, centerPaint);

    // Gambar lingkaran kecil di tengah dengan warna asli
    canvas.drawCircle(Offset(size / 2, size / 2), size / 6, paint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Set<Marker> createMarkers(
      Map<String, DeviceInfo> devices,
      BitmapDescriptor activeMarkerIcon,
      BitmapDescriptor inactiveMarkerIcon,
      BitmapDescriptor gatewayMarkerIcon,
      Function(DeviceInfo) onTap) {
    return devices.values.map((device) {
      BitmapDescriptor icon;
      if (device.id.toLowerCase().contains('gateway')) {
        icon = gatewayMarkerIcon;
      } else {
        icon = device.isActive ? activeMarkerIcon : inactiveMarkerIcon;
      }

      return Marker(
        markerId: MarkerId(device.id),
        position: device.location,
        icon: icon,
        onTap: () => onTap(device),
      );
    }).toSet();
  }
}
