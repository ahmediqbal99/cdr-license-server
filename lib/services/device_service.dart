import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class DeviceService {

  static Future<String> getDeviceId() async {

    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;

      // 🔥 BEST UNIQUE ID
      return info.deviceId;
    }

    return "unknown_device";
  }
}