import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_spacing.dart';

class DishDetailScreen extends ConsumerWidget {
  const DishDetailScreen({super.key, required this.dishId});

  final int dishId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('dishTitle'.tr(namedArgs: {'dishId': '$dishId'})),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text('dishDetailStub'.tr()),
      ),
    );
  }
}
