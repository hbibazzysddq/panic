// file: lib/components/map_component.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/device_info.dart';

class MapComponent extends StatelessWidget {
  final Map<String, DeviceInfo> devices;
  final Function(GoogleMapController) onMapCreated;
  final Function() fitBounds;
  final Function(DeviceInfo) showDeviceInfo;
  final LatLng defaultCenter;
  final Set<Marker> markers;

  const MapComponent({
    super.key,
    required this.devices,
    required this.onMapCreated,
    required this.fitBounds,
    required this.showDeviceInfo,
    required this.defaultCenter,
    required this.markers,
    required Map<String, BitmapDescriptor?> markerIcons,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: onMapCreated,
          mapType: MapType.satellite,
          markers: markers,
          initialCameraPosition: CameraPosition(
            target: defaultCenter,
            zoom: 15,
          ),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
        Positioned(
          right: 10,
          bottom: 90,
          child: FloatingActionButton(
            onPressed: fitBounds,
            tooltip: 'Fit all markers',
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            child: const Icon(Icons.center_focus_strong),
          ),
        ),
      ],
    );
  }
}
