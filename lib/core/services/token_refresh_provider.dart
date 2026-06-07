import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/services/device_info_provider.dart';
import 'package:mezzome/core/services/token_refresh_service.dart';
import 'package:mezzome/core/services/token_storage_provider.dart';

final tokenRefreshServiceProvider = Provider<TokenRefreshService>((ref) {
  return TokenRefreshService(
    tokenStorage: ref.watch(tokenStorageProvider),
    deviceInfo: ref.watch(deviceInfoProvider),
  );
});
