import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'recipe_models.dart';

/// Таблица рецептуры (№, Продукт, Брутто, Нетто, % потерь, Цена за кг, Сумма).
class RecipeTable extends StatelessWidget {
  final List<Ingredient> items;
  const RecipeTable({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(40),   // №
          1: FlexColumnWidth(2.4),   // Продукт
          2: FlexColumnWidth(1.2),   // Брутто
          3: FlexColumnWidth(1.2),   // Нетто
          4: FlexColumnWidth(1.3),   // % потерь
          5: FlexColumnWidth(1.4),   // Цена за кг
          6: FlexColumnWidth(1.2),   // Сумма
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          _headerRow(),
          for (final ing in items) _dataRow(ing),
        ],
      ),
    );
  }

  TableRow _headerRow() {
    const headers = ['№', 'Продукт', 'Брутто, г', 'Нетто, г', '% потерь', 'Цена за кг', 'Сумма'];
    return TableRow(
      children: [
        for (int i = 0; i < headers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(headers[i], style: AppText.tableHeader),
          ),
      ],
    );
  }

  TableRow _dataRow(Ingredient ing) {
    final cells = [
      ing.number.toString(),
      ing.product,
      ing.grossG.toString(),
      ing.netG.toString(),
      ing.lossPercent,
      ing.pricePerKg,
      ing.sum,
    ];
    return TableRow(
      children: [
        for (int i = 0; i < cells.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              cells[i],
              style: i == 1
                  ? AppText.tableCell.copyWith(fontWeight: FontWeight.w500)
                  : AppText.tableCell,
            ),
          ),
      ],
    );
  }
}
