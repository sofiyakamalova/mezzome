import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/l10n/app_locales.dart';
import 'package:mezzome/core/logging/app_logger.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Locale>(
      tooltip: 'languageTooltip'.tr(),
      icon: const Icon(Icons.language),
      onSelected: (locale) {
        appLogger.i('Locale changed → ${locale.languageCode}');
        context.setLocale(locale);
      },
      itemBuilder: (context) => AppLocales.supported
          .map(
            (locale) => CheckedPopupMenuItem<Locale>(
              value: locale,
              checked: context.locale.languageCode == locale.languageCode,
              child: Text(_label(locale)),
            ),
          )
          .toList(),
    );
  }

  String _label(Locale locale) => switch (locale.languageCode) {
    'ru' => 'languageRu'.tr(),
    'kk' => 'languageKk'.tr(),
    'en' => 'languageEn'.tr(),
    _ => locale.languageCode,
  };
}
