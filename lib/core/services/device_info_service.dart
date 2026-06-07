import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mezzome/core/config/app_config.dart';
import 'package:uuid/uuid.dart';

/// Stable device id and metadata for OTP verify.
class DeviceInfoService {
  DeviceInfoService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  static const _deviceIdKey = 'device_id';

  Future<String> getDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final id = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  String get deviceType {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return 'web';
  }

  String get appVersion => AppConfig.appVersion;

  String get deviceName {
    if (kIsWeb) {
      return 'Web browser';
    }
    if (Platform.isAndroid) {
      return 'Android device';
    }
    if (Platform.isIOS) {
      return 'iOS device';
    }
    return 'Unknown device';
  }
}
