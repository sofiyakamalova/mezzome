/// Главный финансовый дашборд («Обзор», гайд §5): полный P&L. Чистые domain-
/// модели без JSON — парсинг в data/dtos.
class FinancialDashboard {
  const FinancialDashboard({
    required this.currency,
    required this.sales,
    required this.costs,
    required this.profitability,
    required this.payments,
    required this.production,
    required this.dataQuality,
    required this.daily,
    required this.expenseCategories,
    required this.paymentMethods,
    required this.topItems,
    required this.canViewMoney,
  });

  final String currency;
  final FinSales sales;
  final FinCosts costs;
  final FinProfitability profitability;
  final FinPayments payments;
  final FinProduction production;
  final FinDataQuality dataQuality;
  final List<FinDailyPoint> daily;
  final List<FinCategory> expenseCategories;
  final List<FinPaymentMethod> paymentMethods;
  final List<FinTopItem> topItems;
  final bool canViewMoney;
}

class FinSales {
  const FinSales({
    this.recognizedRevenue = 0,
    this.grossSales = 0,
    this.netSales = 0,
    this.discountsTotal = 0,
    this.serviceChargeTotal = 0,
    this.ordersTotal = 0,
    this.completedOrders = 0,
    this.openOrders = 0,
    this.cancelledOrders = 0,
    this.averageOrderValue = 0,
    this.discountPct = 0,
  });

  final double recognizedRevenue;
  final double grossSales;
  final double netSales;
  final double discountsTotal;
  final double serviceChargeTotal;
  final int ordersTotal;
  final int completedOrders;
  final int openOrders;
  final int cancelledOrders;
  final double averageOrderValue;
  final double discountPct;
}

class FinCosts {
  const FinCosts({
    this.cogs = 0,
    this.foodCostPct = 0,
    this.opexTotal = 0,
    this.wasteTotal = 0,
    this.writeOffsTotal = 0,
    this.lossesTotal = 0,
    this.inventoryPurchases = 0,
    this.inventoryConsumption = 0,
  });

  final double cogs;
  final double foodCostPct;
  final double opexTotal;
  final double wasteTotal;
  final double writeOffsTotal;
  final double lossesTotal;
  final double inventoryPurchases;
  final double inventoryConsumption;
}

class FinProfitability {
  const FinProfitability({
    this.grossProfit = 0,
    this.grossMarginPct = 0,
    this.operatingProfit = 0,
    this.operatingMarginPct = 0,
  });

  final double grossProfit;
  final double grossMarginPct;
  final double operatingProfit;
  final double operatingMarginPct;
}

class FinPayments {
  const FinPayments({
    this.netPayments = 0,
    this.pendingPayments = 0,
    this.refundsTotal = 0,
    this.collectionRatePct = 0,
    this.cashPayments = 0,
    this.cashlessPayments = 0,
  });

  final double netPayments;
  final double pendingPayments;
  final double refundsTotal;
  final double collectionRatePct;
  final double cashPayments;
  final double cashlessPayments;
}

class FinProduction {
  const FinProduction({
    this.theoreticalFoodCost = 0,
    this.actualFoodCost = 0,
    this.varianceCost = 0,
    this.variancePct = 0,
    this.costPerMeal = 0,
    this.mealsServed = 0,
  });

  final double theoreticalFoodCost;
  final double actualFoodCost;
  final double varianceCost;
  final double variancePct;
  final double costPerMeal;
  final int mealsServed;
}

class FinDataQuality {
  const FinDataQuality({
    this.overallCompletenessPct = 100,
    this.completedOrderItems = 0,
    this.orderItemsWithoutCost = 0,
    this.activeMenuItems = 0,
    this.menuItemsWithoutRecipe = 0,
    this.acceptedReceiptItems = 0,
    this.receiptItemsWithoutCost = 0,
    this.costCoveragePct = 100,
    this.recipeCoveragePct = 100,
    this.receiptCostCoveragePct = 100,
    this.warnings = const [],
  });

  final double overallCompletenessPct;
  final int completedOrderItems;
  final int orderItemsWithoutCost;
  final int activeMenuItems;
  final int menuItemsWithoutRecipe;
  final int acceptedReceiptItems;
  final int receiptItemsWithoutCost;
  final double costCoveragePct;
  final double recipeCoveragePct;
  final double receiptCostCoveragePct;
  final List<String> warnings;
}

class FinDailyPoint {
  const FinDailyPoint({
    this.date = '',
    this.recognizedRevenue = 0,
    this.cogs = 0,
    this.opex = 0,
    this.operatingProfit = 0,
  });

  final String date;
  final double recognizedRevenue;
  final double cogs;
  final double opex;
  final double operatingProfit;
}

class FinCategory {
  const FinCategory({this.category = '', this.amount = 0, this.sharePct = 0});

  final String category;
  final double amount;
  final double sharePct;
}

class FinPaymentMethod {
  const FinPaymentMethod({
    this.paymentType = '',
    this.netAmount = 0,
    this.count = 0,
  });

  final String paymentType;
  final double netAmount;
  final int count;
}

class FinTopItem {
  const FinTopItem({
    this.name = '',
    this.quantity = 0,
    this.revenue = 0,
    this.grossProfit = 0,
    this.grossMarginPct = 0,
  });

  final String name;
  final int quantity;
  final double revenue;
  final double grossProfit;
  final double grossMarginPct;
}
