import 'package:mezzome/features/financial/domain/models/financial_dashboard.dart';

/// Парсинг `GET /dashboard` (объект `financial`) → доменную модель.
/// Лоялен к Decimal-строкам.
abstract final class FinancialDashboardDto {
  static FinancialDashboard fromJson(Map<String, dynamic> json) {
    final f = (json['financial'] as Map?)?.cast<String, dynamic>() ?? const {};
    final perms = (json['permissions'] as Map?)?.cast<String, dynamic>();

    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    Map<String, dynamic> obj(String key) =>
        (f[key] as Map?)?.cast<String, dynamic>() ?? const {};

    final s = obj('sales');
    final c = obj('costs');
    final p = obj('profitability');
    final pay = obj('payments');
    final pr = obj('production');
    final dq = obj('data_quality');

    return FinancialDashboard(
      currency: f['currency']?.toString() ?? 'KZT',
      sales: FinSales(
        recognizedRevenue: _d(s['recognized_revenue']),
        grossSales: _d(s['gross_sales']),
        netSales: _d(s['net_sales']),
        discountsTotal: _d(s['discounts_total']),
        serviceChargeTotal: _d(s['service_charge_total']),
        ordersTotal: _i(s['orders_total']),
        completedOrders: _i(s['completed_orders']),
        openOrders: _i(s['open_orders']),
        cancelledOrders: _i(s['cancelled_orders']),
        averageOrderValue: _d(s['average_order_value']),
        discountPct: _d(s['discount_pct']),
      ),
      costs: FinCosts(
        cogs: _d(c['cogs']),
        foodCostPct: _d(c['food_cost_pct']),
        opexTotal: _d(c['opex_total']),
        wasteTotal: _d(c['waste_total']),
        writeOffsTotal: _d(c['write_offs_total']),
        lossesTotal: _d(c['losses_total']),
        inventoryPurchases: _d(c['inventory_purchases']),
        inventoryConsumption: _d(c['inventory_consumption']),
      ),
      profitability: FinProfitability(
        grossProfit: _d(p['gross_profit']),
        grossMarginPct: _d(p['gross_margin_pct']),
        operatingProfit: _d(p['operating_profit']),
        operatingMarginPct: _d(p['operating_margin_pct']),
      ),
      payments: FinPayments(
        netPayments: _d(pay['net_payments']),
        pendingPayments: _d(pay['pending_payments']),
        refundsTotal: _d(pay['refunds_total']),
        collectionRatePct: _d(pay['collection_rate_pct']),
        cashPayments: _d(pay['cash_payments']),
        cashlessPayments: _d(pay['cashless_payments']),
      ),
      production: FinProduction(
        theoreticalFoodCost: _d(pr['theoretical_food_cost']),
        actualFoodCost: _d(pr['actual_food_cost']),
        varianceCost: _d(pr['variance_cost']),
        variancePct: _d(pr['variance_pct']),
        costPerMeal: _d(pr['cost_per_meal']),
        mealsServed: _i(pr['meals_served']),
      ),
      dataQuality: FinDataQuality(
        overallCompletenessPct: _d(dq['overall_completeness_pct']),
        completedOrderItems: _i(dq['completed_order_items']),
        orderItemsWithoutCost: _i(dq['order_items_without_cost']),
        activeMenuItems: _i(dq['active_menu_items']),
        menuItemsWithoutRecipe: _i(dq['menu_items_without_recipe']),
        acceptedReceiptItems: _i(dq['accepted_receipt_items']),
        receiptItemsWithoutCost: _i(dq['receipt_items_without_cost']),
        costCoveragePct: _d(dq['cost_coverage_pct']),
        recipeCoveragePct: _d(dq['recipe_coverage_pct']),
        receiptCostCoveragePct: _d(dq['receipt_cost_coverage_pct']),
        warnings:
            (dq['warnings'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
      ),
      daily: list(
        f['daily'],
        (e) => FinDailyPoint(
          date: e['date']?.toString() ?? '',
          recognizedRevenue: _d(e['recognized_revenue']),
          cogs: _d(e['cogs']),
          opex: _d(e['opex']),
          operatingProfit: _d(e['operating_profit']),
        ),
      ),
      expenseCategories: list(
        f['expense_categories'],
        (e) => FinCategory(
          category: e['category']?.toString() ?? '',
          amount: _d(e['amount']),
          sharePct: _d(e['share_pct']),
        ),
      ),
      paymentMethods: list(
        f['payment_methods'],
        (e) => FinPaymentMethod(
          paymentType: e['payment_type']?.toString() ?? '',
          netAmount: _d(e['net_amount']),
          count: _i(e['count']),
        ),
      ),
      topItems: list(
        f['top_items'],
        (e) => FinTopItem(
          name: e['name']?.toString() ?? '',
          quantity: _i(e['quantity']),
          revenue: _d(e['revenue']),
          grossProfit: _d(e['gross_profit']),
          grossMarginPct: _d(e['gross_margin_pct']),
        ),
      ),
      canViewMoney: perms == null ? true : perms['can_view_money'] != false,
    );
  }
}

double _d(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _i(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
