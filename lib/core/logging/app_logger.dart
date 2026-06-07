import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Shared app logger. Use [logger.i] / [logger.e] across the project.
final Logger appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 100,
    colors: true,
    printEmojis: false,
  ),
  level: kDebugMode ? Level.debug : Level.info,
);

/// Alias for [appLogger] — `logger.i('message')`.
final Logger logger = appLogger;
