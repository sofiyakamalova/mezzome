import 'package:flutter/material.dart';

abstract final class AppLocales {
  static const supported = <Locale>[
    Locale('ru'),
    Locale('kk'),
    Locale('en'),
  ];

  static const fallback = Locale('ru');
}
