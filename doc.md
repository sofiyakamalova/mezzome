lib/
│
├── main.dart                      # Точка входа, инициализация ProviderScope и Firebase/ИИ SDK
├── app.dart                       # Основной виджет MaterialApp, настройка роутинга и тем
│
├── core/                          # Глобальные модули, независимые от конкретных фич
│   ├── constants/                 # Константы (цвета, отступы, строки)
│   ├── theme/                     # Настройки светлой/темной темы
│   ├── router/                    # Конфигурация навигации (например, GoRouter)
│   ├── services/                  # Глобальные сервисы (локальное хранилище, логирование)
│   └── network/                   # Базовый HTTP/Dio клиент для работы с API
│       ├── api_client.dart
│       └── dio_provider.dart      # Riverpod провайдер для Dio
│
└── features/                      # Каждая фича — это изолированный вертикальный слайс
    └── dashboard/                 # Ваша фича "Dashboard"
        ├── data/                  # Слой данных (API, Модели, Репозитории)
        │   ├── api/
        │   │   └── dashboard_api.dart //  rest queries with retrofit
        │   ├── models/
        │   │   ├── dashboard_stats_model.dart //models with json annotation, build runner
        │   │   └── dashboard_stats_model.g.dart
        │   └── repository/
        │       └── dashboard_repository.dart // repository
        │
        ├── presentation/          # Слой пре дставления (UI + Логика экрана)
        │   ├── providers/         # Управление состоянием (Riverpod)
        │   │   ├── dashboard_notifier.dart
        │   │   └── dashboard_state.dart
        │   ├── screens/           # Сами экраны (Страницы)
        │   │   └── dashboard_screen.dart
        │   └── widgets/           # Мелкие переиспользуемые виджеты внутри этой фичи
        │       ├── ai_status_card.dart
        │       └── stats_grid.dart