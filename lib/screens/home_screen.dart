import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:ui' as ui;

import 'dart:convert';
import 'package:intl/intl.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const LatLng _defaultCenter = LatLng(-8.6776782, 115.2611143);
  static const Duration _inactivityThreshold = Duration(minutes: 1);
  final Map<String, DeviceInfo> _devices = {};
  int _activeDevices = 0;
  DateTime _lastUpdateTime = DateTime.now();

  Map<String, List<String>> _logEntries = {};

  GoogleMapController? _mapController;
  Timer? _dataFetchTimer;
  BitmapDescriptor? _activeMarkerIcon;
  BitmapDescriptor? _inactiveMarkerIcon;
  BitmapDescriptor? _gatewayMarkerIcon;
  BitmapDescriptor? _activeMarkerIconLarge;
  BitmapDescriptor? _inactiveMarkerIconLarge;
  BitmapDescriptor? _gatewayMarkerIconLarge;

  bool get isAndroid => Theme.of(context).platform == TargetPlatform.android;

  final Map<String, LatLng> _manualCoordinates = {
    'id-1': LatLng(-8.679730, 115.260544),
    'id-2': LatLng(-8.679722, 115.261389),
    'Gateway 1': LatLng(-8.679722, 115.261667),
    'id-3': LatLng(-8.679444, 115.262222),
    'id-4': LatLng(-8.678611, 115.262500),
    'id-5': LatLng(-8.677222, 115.262500),
    'id-6': LatLng(-8.676389, 115.262222),
    'id-7': LatLng(-8.675556, 115.261944),
    'id-8': LatLng(-8.675556, 115.260833),
    'Gateway 2': LatLng(-8.675833, 115.260833),
    'id-9': LatLng(-8.676111, 115.260833),
    'id-10': LatLng(-8.677222, 115.260556),
    'id-11': LatLng(-8.677222, 115.260000),
    'id-12': LatLng(-8.678056, 115.261944),
    'id-13': LatLng(-8.678056, 115.260556),
    'id-14': LatLng(-8.678056, 115.259722),
    'id-15': LatLng(-8.676389, 115.261944),
    'id-16': LatLng(-8.676667, 115.261111),
  };

  void _startPeriodicDeviceCheck() {
    Timer.periodic(Duration(seconds: 15), (timer) {
      final now = DateTime.now();
      bool statusChanged = false;

      _devices.forEach((id, device) {
        if (device.isActive &&
            now.difference(device.lastActivity) > _inactivityThreshold) {
          device.isActive = false;
          statusChanged = true;
          _addLogEntry(
              "Panic Button ${device.displayId} deactivated due to inactivity");
          print("Panic Button $id deactivated due to inactivity");
        }
      });

      if (statusChanged) {
        setState(() {
          _updateActiveDeviceCount();
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _createMarkerIcons();
    _initializeDevices();
    _startDataFetchTimer();
    _startPeriodicDeviceCheck(); // Add this line
  }

  void _initializeDevices() {
    _manualCoordinates.forEach((id, location) {
      _devices[id] = DeviceInfo(
        id: id,
        location: location,
        lastActivity: DateTime.now().subtract(Duration(seconds: 5)),
        isActive: false,
      );
    });
    _updateActiveDeviceCount();
  }

  @override
  void dispose() {
    _dataFetchTimer?.cancel();
    _mapController?.dispose();
    _devices.values.forEach((device) => device.inactivityTimer?.cancel());
    super.dispose();
  }

  Future<void> _createMarkerIcons() async {
    _activeMarkerIcon = await _createCustomMarkerBitmap(Colors.red, 24);
    _inactiveMarkerIcon = await _createCustomMarkerBitmap(Colors.green, 24);
    _gatewayMarkerIcon = await _createCustomMarkerBitmap(Colors.purple, 24);

    _activeMarkerIconLarge = await _createCustomMarkerBitmap(Colors.red, 48);
    _inactiveMarkerIconLarge =
        await _createCustomMarkerBitmap(Colors.green, 48);
    _gatewayMarkerIconLarge =
        await _createCustomMarkerBitmap(Colors.purple, 48);

    setState(() {});
  }

  Future<BitmapDescriptor> _createCustomMarkerBitmap(
      Color color, double size) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);

    final centerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 4, centerPaint);

    canvas.drawCircle(Offset(size / 2, size / 2), size / 6, paint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _startDataFetchTimer() {
    _dataFetchTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _fetchDataFromServer();
    });
  }

  void _updateActiveDeviceCount() {
    setState(() {
      _activeDevices =
          _devices.values.where((device) => device.isActive).length;
    });
    print("Active Panic Button count: $_activeDevices");
    _devices.forEach((id, device) {
      print(
          "Panic button $id - Active: ${device.isActive}, Last activity: ${device.lastActivity}");
    });
  }

  Future<void> _fetchDataFromServer() async {
    try {
      final response =
          await http.get(Uri.parse('http://202.157.187.108:3000/data'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Received data: $data");
        _updateDeviceInfo(data);
        setState(() {
          _lastUpdateTime = DateTime.now();
        });
        print("Data processed at $_lastUpdateTime");
      } else {
        print('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  void _updateDeviceInfo(dynamic data) {
    final now = DateTime.now();
    bool statusChanged = false;

    if (data is List && data.isNotEmpty) {
      for (var item in data) {
        if (item is Map<String, dynamic>) {
          final String deviceId = item['end_device_ids']['device_id'];
          if (_devices.containsKey(deviceId) &&
              !deviceId.toLowerCase().contains('gateway')) {
            final DeviceInfo device = _devices[deviceId]!;

            // Check if this is actually new data
            final DateTime receivedAt = DateTime.parse(item['received_at']);
            if (receivedAt.isAfter(device.lastActivity)) {
              device.lastActivity = receivedAt;

              if (!device.isActive) {
                device.isActive = true;
                statusChanged = true;
                _addLogEntry("Panic Button ${device.displayId} activated");
                print("Panic Button $deviceId activated at $now");
                _showDeviceActivationAlert(device);
              }
            }
          }
        }
      }
    }

    if (statusChanged) {
      _updateActiveDeviceCount();
    }

    setState(() {
      _lastUpdateTime = now;
    });
  }

  void _resetAllDevices() {
    setState(() {
      _devices.forEach((id, device) {
        device.isActive = false;
        device.inactivityTimer?.cancel();
        _addLogEntry("All Panic Buttons reset to inactive");
        print("Panic Button $id has been reset to inactive");
      });
      _updateActiveDeviceCount();
      _lastUpdateTime = DateTime.now();
    });
  }

  void _resetMapToDefault() {
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_defaultCenter));
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitBounds();
  }

  void _fitBounds() {
    if (_devices.isEmpty || _mapController == null) {
      _resetMapToDefault();
      return;
    }

    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;

    _devices.values.forEach((device) {
      minLat =
          minLat < device.location.latitude ? minLat : device.location.latitude;
      maxLat =
          maxLat > device.location.latitude ? maxLat : device.location.latitude;
      minLng = minLng < device.location.longitude
          ? minLng
          : device.location.longitude;
      maxLng = maxLng > device.location.longitude
          ? maxLng
          : device.location.longitude;
    });

    LatLngBounds bounds = LatLngBounds(
      northeast: LatLng(maxLat, maxLng),
      southwest: LatLng(minLat, minLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  Set<Marker> _createMarkers() {
    return _devices.values.map((device) {
      BitmapDescriptor icon;
      if (device.id.toLowerCase().contains('gateway')) {
        icon = isAndroid ? _gatewayMarkerIconLarge! : _gatewayMarkerIcon!;
      } else {
        icon = device.isActive
            ? (isAndroid ? _activeMarkerIconLarge! : _activeMarkerIcon!)
            : (isAndroid ? _inactiveMarkerIconLarge! : _inactiveMarkerIcon!);
      }

      return Marker(
        markerId: MarkerId(device.id),
        position: device.location,
        icon: icon,
        onTap: () => _showDeviceInfo(device),
      );
    }).toSet();
  }

  void _showDeviceActivationAlert(DeviceInfo device) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('DANGER ALERT',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 50),
              const SizedBox(height: 10),
              Text('Panic button ${device.displayId} is ACTIVE!',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                  'Location: ${device.location.latitude}, ${device.location.longitude}'),
            ],
          ),
          backgroundColor: Colors.yellow,
          actions: [
            TextButton(
              child: const Text('View on Map',
                  style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(device.location, 18),
                );
              },
            ),
            TextButton(
              child:
                  const Text('Dismiss', style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeviceInfo(DeviceInfo device) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        bool isGateway = device.id.toLowerCase().contains('gateway');
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isGateway
                    ? 'Gateway ${device.displayId}'
                    : 'Panic Button ${device.displayId}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (!isGateway) ...[
                _buildInfoRow(
                    'Status', device.isActive ? 'Active' : 'Inactive'),
                _buildInfoRow(
                    'Last Activity',
                    DateFormat('yyyy-MM-dd – kk:mm:ss')
                        .format(device.lastActivity)),
              ],
              _buildInfoRow('Location',
                  '${device.location.latitude}, ${device.location.longitude}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(device.location, 18),
                  );
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: isGateway ? Colors.purple : Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text('Zoom to ${isGateway ? 'Gateway' : 'Device'}'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  void _addLogEntry(String entry) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm:ss').format(now);

    setState(() {
      if (!_logEntries.containsKey(dateStr)) {
        _logEntries[dateStr] = [];
      }
      _logEntries[dateStr]!.insert(0, "$timeStr: $entry");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Panic Button Map'),
            Text(
              'Active: $_activeDevices | Last Update: ${DateFormat('HH:mm:ss').format(_lastUpdateTime)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetAllDevices,
            tooltip: 'Reset all panic buttons',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Timestamp Log',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ..._logEntries.entries.map((entry) {
              return ExpansionTile(
                title: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                children: entry.value
                    .map((logEntry) => ListTile(
                          title: Text(logEntry),
                        ))
                    .toList(),
              );
            }).toList(),
          ],
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            mapType: MapType.satellite,
            markers: _createMarkers(),
            initialCameraPosition: const CameraPosition(
              target: _defaultCenter,
              zoom: 15,
            ),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            right: 10,
            bottom: 90,
            child: FloatingActionButton(
              onPressed: _fitBounds,
              tooltip: 'Fit all markers',
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              child: const Icon(Icons.center_focus_strong),
            ),
          ),
        ],
      ),
    );
  }
}
