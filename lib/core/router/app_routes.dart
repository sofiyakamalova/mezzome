/// Path and [GoRouter] name constants.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/';
  static const String settings = '/settings';
  static const String dishes = '/dishes';
  static const String dishDetail = '/dishes/:id';
  static const String approvals = '/approvals';
  static const String myRequests = '/my-requests';
  static const String createPlan = '/create-plan';
  static const String expenses = '/expenses';
  static const String supervisorPlans = '/supervisor-plans';
  static const String techCards = '/tech-cards';

  static const String loginName = 'login';
  static const String dashboardName = 'dashboard';
  static const String settingsName = 'settings';
  static const String dishesName = 'dishes';
  static const String dishDetailName = 'dishDetail';
  static const String approvalsName = 'approvals';
  static const String myRequestsName = 'myRequests';
  static const String createPlanName = 'createPlan';
  static const String expensesName = 'expenses';
  static const String supervisorPlansName = 'supervisorPlans';
  static const String techCardsName = 'techCards';

  static String dishPath(int id) => '/dishes/$id';
}
