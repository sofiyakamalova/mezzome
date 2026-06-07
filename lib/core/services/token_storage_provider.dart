import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/services/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});
