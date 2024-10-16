// file: lib/components/device_info_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/device_info.dart';

class DeviceInfoBottomSheet extends StatelessWidget {
  final DeviceInfo device;
  final Function() onZoomToDevice;

  const DeviceInfoBottomSheet({
    super.key,
    required this.device,
    required this.onZoomToDevice,
  });

  @override
  Widget build(BuildContext context) {
    bool isGateway = device.id.toLowerCase().contains('gateway');
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isGateway
                ? 'Gateway ${device.displayId}'
                : 'Panic Button ${device.displayId}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (!isGateway) ...[
            _buildInfoRow('Status', device.isActive ? 'Active' : 'Inactive'),
            _buildInfoRow(
                'Last Activity',
                DateFormat('yyyy-MM-dd – kk:mm:ss')
                    .format(device.lastActivity)),
          ],
          _buildInfoRow('Location',
              '${device.location.latitude}, ${device.location.longitude}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onZoomToDevice,
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
}
