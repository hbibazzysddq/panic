import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:panic_button/components/map_componet.dart';
import 'package:panic_button/data/manual_coordinate.dart';
import 'package:panic_button/service/alarm_service.dart';
import 'package:panic_button/service/auth_service.dart';
import 'package:panic_button/service/data_service.dart';
import 'package:panic_button/service/log_service.dart';
import 'package:share_plus/share_plus.dart';
import '../models/device_info.dart';
import '../components/log_component.dart';
import '../components/device_info_bottom_sheet.dart';
import '../service/marker_service.dart';
import 'package:panic_button/utils/platform_check.dart';
import 'package:panic_button/service/notification_service.dart'; // Tambahan baru

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
  Map<String, BitmapDescriptor> _markerIcons = {};

  GoogleMapController? _mapController;
  Timer? _dataFetchTimer;
  BitmapDescriptor? _activeMarkerIcon;
  BitmapDescriptor? _inactiveMarkerIcon;
  BitmapDescriptor? _gatewayMarkerIcon;

  final AlarmService _alarmService = AlarmService();
  final DataService _dataService = DataService();
  final LogService _logService = LogService();
  final MarkerService _markerService = MarkerService();
  final NotificationService _notificationService =
      NotificationService(); // Tambahan baru
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeDevices();
    _startDataFetchTimer();
    _startPeriodicDeviceCheck();
    _loadLogEntries();
    if (isMobilePlatform) {
      _notificationService.initialize(); // Perubahan di sini
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _createMarkerIcons();
  }

  void _initializeDevices() {
    ManualCoordinates.coordinates.forEach((id, location) {
      _devices[id] = DeviceInfo(
        id: id,
        location: location,
        lastActivity: DateTime.now().subtract(const Duration(seconds: 5)),
        isActive: false,
      );
    });
    _updateActiveDeviceCount();
  }

  Future<void> _createMarkerIcons() async {
    double webSize = 14;
    double mobileSize = 32;

    bool isMobile = Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

    double regularSize = isMobile ? mobileSize : webSize;

    _activeMarkerIcon =
        await _markerService.createCustomMarkerBitmap(Colors.red, regularSize);
    _inactiveMarkerIcon = await _markerService.createCustomMarkerBitmap(
        Colors.green, regularSize);
    _gatewayMarkerIcon = await _markerService.createCustomMarkerBitmap(
        Colors.purple, regularSize);

    setState(() {
      _markerIcons = {
        'active': _activeMarkerIcon!,
        'inactive': _inactiveMarkerIcon!,
        'gateway': _gatewayMarkerIcon!,
      };
    });
  }

  void _startDataFetchTimer() {
    _dataFetchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchDataFromServer();
    });
  }

  void _startPeriodicDeviceCheck() {
    Timer.periodic(const Duration(seconds: 15), (timer) {
      final now = DateTime.now();
      bool statusChanged = false;

      _devices.forEach((id, device) {
        if (device.isActive &&
            now.difference(device.lastActivity) > _inactivityThreshold) {
          device.isActive = false;
          statusChanged = true;
          _addLogEntry(
              "Panic Button ${device.displayId} deactivated due to inactivity");
          _alarmService.stopAlarm();
        }
      });

      if (statusChanged) {
        setState(() {
          _updateActiveDeviceCount();
        });
      }
    });
  }

  Future<void> _loadLogEntries() async {
    final loadedEntries = await _logService.loadAllLogEntries();
    setState(() {
      _logEntries = loadedEntries;
    });
  }

  void _updateActiveDeviceCount() {
    setState(() {
      _activeDevices =
          _devices.values.where((device) => device.isActive).length;
    });
  }

  Future<void> _fetchDataFromServer() async {
    try {
      final data = await _dataService.fetchData();
      _updateDeviceInfo(data);
      setState(() {
        _lastUpdateTime = DateTime.now();
      });
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
            final DateTime receivedAt = DateTime.parse(item['received_at']);
            if (receivedAt.isAfter(device.lastActivity)) {
              device.lastActivity = receivedAt;
              if (!device.isActive) {
                device.isActive = true;
                statusChanged = true;
                _addLogEntry("Panic Button ${device.displayId} activated");
                _showDeviceActivationAlert(device);
                if (isMobilePlatform) {
                  _notificationService.showNotification(
                      'Panic Button Activated',
                      'Device ${device.displayId} is active at ${device.location.latitude}, ${device.location.longitude}'); // Perubahan di sini
                }
                _alarmService.startPeriodicAlarm(const Duration(seconds: 15),
                    () => _devices.values.any((d) => d.isActive));
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

  void _addLogEntry(String entry) async {
    await _logService.addLogEntry(entry);
    await _loadLogEntries();
  }

  void _resetAllDevices() {
    bool anyDeviceWasActive = false;
    setState(() {
      _devices.forEach((id, device) {
        if (device.isActive) {
          anyDeviceWasActive = true;
          device.isActive = false;
        }
      });

      if (anyDeviceWasActive) {
        _addLogEntry("All Panic Buttons reset to inactive");
      }

      _alarmService.stopAlarm();
      _updateActiveDeviceCount();
      _lastUpdateTime = DateTime.now();
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitBounds();
  }

  void _fitBounds() {
    if (_devices.isEmpty || _mapController == null) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(_defaultCenter));
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
                    CameraUpdate.newLatLngZoom(device.location, 18));
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
        return DeviceInfoBottomSheet(
          device: device,
          onZoomToDevice: () {
            Navigator.pop(context);
            _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(device.location, 18));
          },
        );
      },
    );
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
      drawer: LogComponent(
        logEntries: _logEntries,
        logService: _logService,
        authService: _authService,
      ),
      body: MapComponent(
        devices: _devices,
        onMapCreated: _onMapCreated,
        markers: _markerService.createMarkers(
          _devices,
          _markerIcons['active'] ?? BitmapDescriptor.defaultMarker,
          _markerIcons['inactive'] ?? BitmapDescriptor.defaultMarker,
          _markerIcons['gateway'] ?? BitmapDescriptor.defaultMarker,
          _showDeviceInfo,
        ),
        defaultCenter: _defaultCenter,
        fitBounds: _fitBounds,
        showDeviceInfo: _showDeviceInfo,
        markerIcons: const {},
      ),
    );
  }

  void _shareLogFile() async {
    final logFile = await _logService.exportLogToFile();
    await Share.shareXFiles([XFile(logFile.path)],
        text: 'Check out the panic button logs.');
  }

  void _downloadLogFile() async {
    final filePath = await _logService.getLogFilePath();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Log file saved at: $filePath'),
      ),
    );
  }

  @override
  void dispose() {
    _alarmService.dispose();
    _dataFetchTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
