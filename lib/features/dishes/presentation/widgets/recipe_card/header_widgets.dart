import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Логотип MEZZOME с иконкой.
class MezzomeLogo extends StatelessWidget {
  const MezzomeLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        const Text(
          'MEZZOME',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Хлебные крошки «Меню • Технологическая карта».
class Breadcrumbs extends StatelessWidget {
  final List<String> items;
  const Breadcrumbs({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Text(
      items.join('  •  '),
      style: const TextStyle(
        fontSize: 12.5,
        color: AppColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Бейдж статуса: цветная точка + подпись.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({super.key, required this.label, this.color = AppColors.textMuted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Синяя кнопка «Редактировать».
class EditButton extends StatelessWidget {
  final VoidCallback? onTap;
  const EditButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Редактировать',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 7),
              Icon(Icons.open_in_new, color: Colors.white, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}
