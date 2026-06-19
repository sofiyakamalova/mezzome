/// Фильтр «Мои запросы». Значение [statusValue] — контракт бэкенда
/// (`GET /chef/technical-cards?status=...`).
enum MyRequestFilter {
  pending,
  rejected,
  approved;

  String get statusValue => switch (this) {
        // Сервер хранит статус ожидающей версии как `pending_approval`.
        MyRequestFilter.pending => 'pending_approval',
        MyRequestFilter.rejected => 'rejected',
        MyRequestFilter.approved => 'approved',
      };
}
