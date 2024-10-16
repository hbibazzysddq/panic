// file: lib/services/alarm_service.dart
import 'package:just_audio/just_audio.dart';
import 'dart:async';

class AlarmService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _alarmTimer;

  Future<void> playAlarm() async {
    try {
      await _audioPlayer.setAsset('alarm/alarm.wav');
      await _audioPlayer.play();
    } catch (e) {
      print("Error playing alarm: $e");
    }
  }

  void stopAlarm() {
    _audioPlayer.stop();
    _alarmTimer?.cancel();
  }

  void startPeriodicAlarm(Duration interval, bool Function() shouldPlay) {
    _alarmTimer = Timer.periodic(interval, (timer) {
      if (shouldPlay()) {
        playAlarm();
      } else {
        stopAlarm();
      }
    });
  }

  void dispose() {
    _audioPlayer.dispose();
    _alarmTimer?.cancel();
  }
}
