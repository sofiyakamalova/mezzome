# MEZZOME Kitchen OS (Flutter)

## Структура `lib/`

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/
│   ├── constants/     # цвета, отступы 8px
│   ├── theme/
│   ├── router/        # GoRouter
│   ├── services/      # TokenStorage
│   └── network/       # Dio, ApiClient, interceptors
└── features/
    ├── auth/data/
    └── dashboard/
```

## Code generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

## API base URL

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```
