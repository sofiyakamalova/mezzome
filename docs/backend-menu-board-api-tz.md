# ТЗ для бэкенда: API меню-борда (Kitchen OS)

**Версия:** 1.0  
**Дата:** 2026-06-04  
**Клиент:** Flutter MEZZOME Kitchen OS (`/dishes` — меню-борд)  
**Swagger:** https://api-dev.mezzome.com/swagger/v2/index.html  
**Базовый префикс:** `/api/v2`

---

## 1. Цель

Нужен единый контракт данных для экрана **«Меню по расписанию»** (меню-борд):

- сетка **позиция × день недели** (Пн–Вс);
- разрез по **сервисам**: завтрак / обед / ужин;
- в каждой ячейке — **блюдо + себестоимость порции (₸)** из техкарты;
- клик по ячейке — **редактор техкарты** (состав, выход, порции, потери, примечание);
- **сохранение с подписью** → immutable **журнал изменений**;
- **график расхода** по дням для выбранного сервиса;
- **импорт/экспорт** Excel и Word (формирует бэкенд).

Сейчас клиент собирает неделю **7 отдельными запросами** `production-plans?date=`, подставляет каталог `owner/menu/items` при 403, журнал хранит локально. Это временное решение — нужен целевой API.

---

## 2. Что уже есть в v2 (использовать / доработать)

| Область | Эндпоинты | Замечание |
|--------|-----------|-----------|
| Production plans | `GET /chef/production-plans?date=`, `GET /supervisor/production-plans?date=` | Есть план на **одну дату**, не матрица недели. Owner — **403**. |
| Меню (каталог) | `GET /owner/menu/items`, `GET /common/menu/items` | Список блюд, `cost_per_portion`, без привязки к дню/сервису. |
| Техкарты | `GET/POST/PATCH /chef/technical-cards`, `GET .../{id}/history` | Chef-only; нет явной связи `menu_item_id` ↔ `technical_card_id` в ответе. |
| Аудит | `GET /owner/audit?date=&page=` | Подходит для журнала owner; нужна фильтрация по `entity_type=menu/technical_card`. |
| Экспорт PDF | `GET /chef/technical-cards/{id}/export.pdf` | Только одна техкарта, не меню-борд. |
| Отчёты | `POST /manager/reports/export` | Общий payload, **нет** задокументированного `menu_board` + xlsx/docx. |

**Нет в swagger:** импорт меню/техкарт Excel·Word, единый `GET menu-board/week`, доступ owner к production plans.

---

## 3. Целевые сущности (доменная модель)

### 3.1. Сервис (service_type)

Фиксированный enum (строка в API):

| Код API | UI |
|---------|-----|
| `breakfast` | Завтрак |
| `lunch` | Обед |
| `dinner` | Ужин |

Дополнительно (если есть в БД): `snack`, `banquet` — клиент готов расширить фильтр.

### 3.2. Слот меню (menu_slot) — строка сетки

Позиция в меню (как «Яйцо», «Основное блюдо 1»), **не обязательно** = одно блюдо навсегда.

| Поле | Тип | Описание |
|------|-----|----------|
| `slot_id` | int / UUID | Стабильный ID строки сетки |
| `slot_name` | string | Название строки (категория / слот) |
| `category_id` | int? | Связь с `menu/categories` |
| `sort_order` | int | Порядок строк в UI |

### 3.3. Ячейка расписания (menu_schedule_cell)

Пересечение: **слот × день × сервис**.

| Поле | Тип | Описание |
|------|-----|----------|
| `date` | date `YYYY-MM-DD` | Календарный день |
| `weekday` | int 1–7 | Пн=1 … Вс=7 (ISO) |
| `service_type` | enum | breakfast / lunch / dinner |
| `slot_id` | int | Строка сетки |
| `menu_item_id` | int? | Назначенное блюдо (null = пустая ячейка) |
| `menu_item_name` | string | Отображаемое имя |
| `planned_portions` | int | План порций на день |
| `cost_per_portion` | decimal | **Себестоимость порции, ₸** — расчёт бэкенда из техкарты |
| `technical_card_id` | int? | Актуальная техкарта для редактора |
| `technical_card_version` | int? | Версия |
| `is_modified` | bool | Есть неподписанные / недавние изменения (для лайм-точки) |
| `status` | enum? | ok / deviation / overrun / draft |

### 3.4. Блюдо (menu_item) — кратко для ячейки

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | int | |
| `name` | string | |
| `category_id` | int? | |
| `category_name` | string? | |
| `price` | decimal? | Цена продажи (для food cost) |
| `cost_per_portion` | decimal? | Текущая себестоимость |
| `portion_weight_g` | int? | Вес порции |
| `image_url` | string? | |
| `is_active` | bool | |

### 3.5. Техкарта (technical_card) — детально для редактора

Совместимо с `dto.TechnicalCardResponse`, плюс **обязательно**:

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | int | |
| `menu_item_id` | int? | **Нужно добавить в API**, если связь есть в БД |
| `name` | string | |
| `description` | string? | Примечание / технология |
| `base_portions` | decimal | Число порций |
| `output_per_portion` | decimal | Выход, г |
| `output_unit` | string | `g` |
| `total_ingredient_cost` | decimal | Сумма ингредиентов |
| `cost_per_portion` | decimal | **Итог на порцию** (бэкенд считает) |
| `food_cost` | decimal? | % |
| `status` | string | draft / approved / … |
| `ingredients[]` | array | См. ниже |
| `steps[]` | array? | Этапы (текст, время, порядок) |

**Строка ингредиента (`technical_card_ingredient`):**

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | int? | |
| `ingredient_id` | int? | |
| `ingredient_name` | string | |
| `brutto` | decimal | Брутто, г |
| `netto` | decimal | Нетто, г |
| `cost_per_unit` | decimal | ₸/кг (или за ед. по `unit`) |
| `unit` | string | kg / l / pcs |
| `total_cost` | decimal | **Сумма строки** (расчёт сервера) |
| `loss_pct` | decimal? | Потери % (или `cleaning_pct`) |
| `sort_order` | int | |

**Формулы (считает бэкенд, клиент — только preview):**

- `line_cost` = f(netto, unit, cost_per_unit) — для кг: `netto / 1000 × cost_per_unit`
- `cost_per_portion` = Σ line_cost / base_portions
- `loss_pct` = (brutto − netto) / brutto × 100 при brutto > 0

### 3.6. Журнал изменений (audit_log / menu_journal)

Immutable, без удаления.

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | int / UUID | |
| `timestamp` | datetime ISO8601 | |
| `user_id` | int | |
| `user_name` | string | Для подписи «Имя \| MEZZOME» |
| `role` | string | owner / chef / … |
| `signature` | string | Контрольный штамп (генерирует бэкенд) |
| `entity_type` | string | `menu_schedule_cell` / `technical_card` / `menu_item` |
| `entity_id` | string | |
| `cell_key` | string? | slot_id + date + service (для UI) |
| `action` | string | update / assign / revert |
| `changes[]` | array | `{ field, old_value, new_value }` |
| `summary` | string? | Человекочитаемо: «Пирог → Голубцы; cost 470→502 ₸» |

Примеры `field`: `dish_name`, `cost_per_portion`, `ingredients_count`, `netto`, `base_portions`.

### 3.7. Агрегаты для шапки борда

| Метрика | Описание |
|---------|----------|
| `positions_count` | Число строк (слотов) в сетке |
| `changed_count` | Ячеек с `is_modified=true` за период |
| `weekly_cost` | Σ cost_per_portion × planned_portions по неделе и сервису |
| `consumption_by_day[]` | `{ date, total_cost }` — для графика расхода |

---

## 4. Целевые эндпоинты (предложение контракта)

### 4.1. Меню-борд на неделю (главный)

```
GET /api/v2/{role}/menu-board/week
```

**Query:**

| Параметр | Обяз. | Описание |
|----------|-------|----------|
| `week_start` | да | `YYYY-MM-DD` — понедельник недели (или любая дата внутри недели → бэкенд нормализует) |
| `service_type` | нет | breakfast \| lunch \| dinner (без параметра — все сервисы) |
| `kitchen_id` | нет | Если мульти-кухня |
| `search` | нет | Фильтр по названию блюда/слота |

**Роли:** `chef`, `supervisor`, `owner` (единый доступ, без 403 для owner).

**Response 200:**

```json
{
  "week_start": "2026-06-02",
  "week_end": "2026-06-08",
  "service_type": "lunch",
  "summary": {
    "positions_count": 91,
    "changed_count": 3,
    "weekly_cost": 17925.50
  },
  "consumption_by_day": [
    { "date": "2026-06-02", "weekday": 1, "total_cost": 3200.0 },
    { "date": "2026-06-03", "weekday": 2, "total_cost": 2850.0 }
  ],
  "slots": [
    {
      "slot_id": 10,
      "slot_name": "Яйцо",
      "category_id": 2,
      "sort_order": 1,
      "cells": [
        {
          "date": "2026-06-02",
          "weekday": 1,
          "service_type": "breakfast",
          "menu_item_id": 101,
          "menu_item_name": "Отварное",
          "planned_portions": 50,
          "cost_per_portion": 119.0,
          "technical_card_id": 55,
          "is_modified": false,
          "status": "ok"
        }
      ]
    }
  ]
}
```

**Почему один запрос:** клиент сейчас делает 6–7× `production-plans?date=` → медленно, нет слотов, owner не видит планы.

---

### 4.2. Одна ячейка / назначение блюда в ячейку

```
PUT /api/v2/{role}/menu-board/cells
```

**Body:**

```json
{
  "date": "2026-06-03",
  "service_type": "lunch",
  "slot_id": 10,
  "menu_item_id": 205,
  "planned_portions": 120
}
```

Ответ: обновлённая `menu_schedule_cell` + пересчитанный `cost_per_portion`.

---

### 4.3. Техкарта (чтение / сохранение)

**Чтение (уже есть, доработать):**

```
GET /api/v2/chef/technical-cards/{id}
GET /api/v2/chef/technical-cards?search={name}&menu_item_id={id}
```

**Обязательно в ответе:** `menu_item_id`, `cost_per_portion` (или `total_ingredient_cost` + `base_portions`).

**Сохранение с подписью (расширить PATCH):**

```
PATCH /api/v2/chef/technical-cards/{id}
```

**Body** (как `dto.UpdateTechnicalCardRequest`):

```json
{
  "name": "Пирог с говядиной",
  "description": "Способ приготовления…",
  "base_portions": 1,
  "output_per_portion": 220,
  "output_unit": "g",
  "ingredients": [
    {
      "ingredient_id": 1,
      "ingredient_name": "Говядина",
      "brutto": 150,
      "netto": 144,
      "cost_per_unit": 1240,
      "sort_order": 0
    }
  ],
  "sign_and_save": true
}
```

**Response:** обновлённая техкарта + **`audit_entry`** (см. §3.6) + пересчитанные `cost_per_portion` для всех ячеек с этим `menu_item_id` / `technical_card_id`.

**RBAC:**

| Роль | Право |
|------|-------|
| owner | Прямое сохранение, без согласования |
| chef | Сохранение → `pending_approval` или `sign_and_save` по политике |
| cook | Только чтение техкарты **без цен** (отдельный DTO или флаг `hide_financials`) |

---

### 4.4. Журнал изменений

```
GET /api/v2/owner/audit?date_from=&date_to=&entity_type=technical_card&page=&page_size=
```

Доработать фильтры: `menu_item_id`, `slot_id`, `service_type`.

**Альтернатива для ячейки:**

```
GET /api/v2/menu-board/cells/{cell_id}/history
```

---

### 4.5. Откат ячейки к утверждённой версии

```
POST /api/v2/{role}/menu-board/cells/revert
```

**Body:** `{ "date", "service_type", "slot_id" }` или `{ "technical_card_id", "version" }`

Восстанавливает последнюю **approved** версию техкарты / назначения, пишет запись в audit.

---

### 4.6. Импорт / экспорт

**Экспорт меню-борда (новое):**

```
GET /api/v2/owner/menu-board/export?week_start=2026-06-02&service_type=lunch&format=xlsx
GET /api/v2/owner/menu-board/export?week_start=2026-06-02&format=docx
```

Ответ: `application/octet-stream` или `{ "download_url": "..." }`.

**Импорт (новое, только owner):**

```
POST /api/v2/owner/menu-board/import
Content-Type: multipart/form-data
```

Поля: `file`, `format` (xlsx | docx), `dry_run` (bool) — предпросмотр без сохранения.

**Response (dry_run):**

```json
{
  "rows_parsed": 120,
  "rows_valid": 115,
  "errors": [{ "row": 5, "message": "Unknown ingredient" }],
  "preview": [ … ]
}
```

**Response (commit):** `{ "imported": 115, "audit_id": "…" }`

---

### 4.7. Production plans (совместимость)

Текущие эндпоинты оставить, но:

1. Добавить **`service_type`** в list/detail, если ещё не везде стабилен.
2. В `production_plan.items[]` добавить: `menu_item_name`, `cost_per_portion`, `technical_card_id`, `slot_id`.
3. **Owner:** `GET /owner/production-plans?date=` **или** проксировать через `menu-board/week`.

---

## 5. Матрица доступа (RBAC)

| Эндпоинт | owner | supervisor | chef | cook |
|----------|:-----:|:----------:|:----:|:----:|
| menu-board/week | ✓ | ✓ | ✓ | ✓ (без ₸) |
| menu-board/cells PUT | ✓ | ✓ | ✓ | — |
| technical-cards PATCH | ✓ | ✓ | ✓* | — |
| technical-cards (цены в ingredients) | ✓ | ✓ | ✓ | скрыть |
| audit / history | ✓ | ✓ | ✓ | — |
| import | ✓ | — | — | — |
| export xlsx/docx | ✓ | export | export | — |

\* chef — с согласованием, если политика включена.

---

## 6. Ошибки и edge cases

| Код | Ситуация |
|-----|----------|
| 403 | Роль не имеет доступа — JSON `{ "error": "FORBIDDEN", "message": "…" }` |
| 404 | Нет плана на дату — **пустая сетка**, не 404 на весь week (предпочтительно `slots: []`) |
| 422 | Невалидные граммовки / отрицательные порции |
| 409 | Конфликт версий техкарты (optimistic lock: `version` в PATCH) |

**Пустая неделя:** `200` + `slots: []`, `summary.positions_count: 0`.

**Часовой пояс:** даты в timezone ресторана (передавать `restaurant_id` из JWT).

---

## 7. Что нужно клиенту в приоритете (MVP → полный борд)

### Фаза 1 — без этого борд «пустой»

1. `GET menu-board/week` с `service_type`, Пн–Вс, `cost_per_portion`, `technical_card_id`.
2. Доступ **owner** (сейчас 403 на production-plans).
3. `PATCH technical-cards/{id}` + запись в audit + поле `menu_item_id` в техкарте.

### Фаза 2 — редактор и журнал

4. `GET audit` с фильтрами по меню/техкарте.
5. `POST cells/revert`.
6. `consumption_by_day` и `summary` в ответе week (или отдельный lightweight endpoint).

### Фаза 3 — импорт/экспорт

7. `GET menu-board/export?format=xlsx|docx`.
8. `POST menu-board/import` с `dry_run`.

### Фаза 4 — согласование (по ТЗ продукта)

9. `GET /changes?status=pending`, `POST /changes/{id}/approve|reject`.

---

## 8. Критерии приёмки для бэкенда

1. Один запрос `menu-board/week` отдаёт сетку на 7 дней × 3 сервиса (или фильтр по сервису) с `cost_per_portion` в каждой заполненной ячейке.
2. Owner и chef получают **200**, не 403, на dev-стенде с тестовым рестораном.
3. `PATCH technical-cards/{id}` с `sign_and_save: true` создаёт запись в audit с `old_value` / `new_value` и `signature`.
4. После сохранения техкарты пересчитывается `cost_per_portion` в ячейках расписания.
5. Экспорт xlsx содержит: слоты, дни Пн–Вс, сервис, название блюда, ₸/порц, порции.
6. Импорт xlsx с `dry_run=true` возвращает preview и список ошибок без записи в БД.
7. Cook при `GET technical-cards/{id}` не видит `cost_per_unit`, `total_cost`, `cost_per_portion` (или отдельный scope).

---

## 9. Пример сценария для QA

1. Создать production plan на **среду, обед**, 3 блюда с техкартами.
2. `GET menu-board/week?week_start=2026-06-02&service_type=lunch` → в колонке «Ср» три ячейки с именами и ₸.
3. `PATCH technical-cards/55` — изменить netto говядины 144→160 → в ответе новый `cost_per_portion`.
4. `GET owner/audit` → запись «netto 144 → 160», user, signature.
5. `GET menu-board/week` → `is_modified: true` на ячейке среды (опционально).
6. Owner: `GET menu-board/export?format=xlsx` → файл скачивается.

---

## 10. Контакты и ссылки

- Клиент: `lib/features/dishes/` — `menu_dashboard_*`, `dishes_screen.dart`
- Продуктовое ТЗ: `documentation.md` §4–§8
- Dev API: https://api-dev.mezzome.com/swagger/v2/index.html
- Текущий workaround клиента: 7× `GET .../production-plans?date=` + `GET /owner/menu/items` (fallback)

**Вопросы к бэкенду (нужны ответы до реализации):**

1. Есть ли в БД сущность «слот меню» или только `menu_item` × `production_plan`?
2. Как связываются `menu_item_id` и `technical_card_id` (1:1 или версии)?
3. Кто источник правды для «блюдо в ячейке среды на обед» — production plan или отдельная таблица menu_schedule?
4. Готовый формат Excel для импорта (образец файла)?

---

*Документ можно передать бэкенд-разработчику как основу для оценки и декомпозиции задач в Jira/Linear.*
