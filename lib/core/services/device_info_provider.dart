import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/services/device_info_service.dart';

final deviceInfoProvider = Provider<DeviceInfoService>((ref) {
  return DeviceInfoService();
});
