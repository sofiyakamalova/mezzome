import 'package:json_annotation/json_annotation.dart';

part 'technical_card_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class TechnicalCardListResponse {
  const TechnicalCardListResponse({
    this.cards = const [],
    this.total = 0,
  });

  final List<TechnicalCardModel> cards;
  final int total;

  List<TechnicalCardModel> get items => cards;

  factory TechnicalCardListResponse.fromJson(Map<String, dynamic> json) =>
      _$TechnicalCardListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TechnicalCardListResponseToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class TechnicalCardModel {
  const TechnicalCardModel({
    required this.id,
    required this.name,
    this.menuItemId,
    this.description,
    this.basePortions = 1,
    this.outputPerPortion = 0,
    this.outputUnit = 'g',
    this.totalIngredientCost = 0,
    this.foodCost = 0,
    this.categoryId,
    this.categoryName,
    this.status,
    this.approvalStatus,
    this.availableActions = const [],
    this.version,
    this.changeLevel,
    this.submittedAt,
    this.approvedAt,
    this.updatedAt,
    this.halalRequired = false,
    this.ingredients = const [],
  });

  final int id;
  final String name;

  /// Связанное блюдо меню (`menu_item_id`), если бэкенд его отдаёт.
  final int? menuItemId;
  final String? description;
  final double basePortions;
  final double outputPerPortion;
  final String outputUnit;
  final double totalIngredientCost;
  final double foodCost;
  final int? categoryId;
  final String? categoryName;
  final String? status;

  /// Статус согласования (`approval_status`): pending / approved / rejected.
  final String? approvalStatus;

  /// Действия, доступные текущей роли (`available_actions`), напр.
  /// `["view", "cancel_submission"]` у версии на согласовании.
  final List<String> availableActions;

  /// Номер версии техкарты (`version`) — растёт с каждой правкой.
  final int? version;

  /// Уровень изменения: `COSMETIC` / `PARAMETRIC` / ...
  final String? changeLevel;

  /// Когда версия отправлена на согласование (`submitted_at`).
  final DateTime? submittedAt;

  /// Когда версия утверждена (`approved_at`).
  final DateTime? approvedAt;

  /// Последнее обновление (`updated_at`).
  final DateTime? updatedAt;

  /// Требование халяль (`halal_required`). При `true` все ингредиенты должны
  /// быть сертифицированы — иначе PATCH вернёт `INVALID_TECHNICAL_CARD`.
  final bool halalRequired;

  final List<TechnicalCardIngredientModel> ingredients;

  /// Действия, означающие, что версию можно редактировать/переотправить.
  static const _editActions = {
    'edit',
    'update',
    'submit',
    'submit_for_approval',
    'resubmit',
    'save',
  };

  /// Версия только для просмотра: уже на согласовании (`pending`) либо
  /// `available_actions` не содержит ни одного редактирующего действия
  /// (например `["view", "cancel_submission"]`).
  bool get isReadOnly {
    final s = (status ?? '').toLowerCase();
    final a = (approvalStatus ?? '').toLowerCase();
    final pending =
        s == 'pending' || s == 'pending_approval' || a == 'pending';
    if (availableActions.isEmpty) {
      return pending;
    }
    final canEdit = availableActions
        .any((action) => _editActions.contains(action.toLowerCase()));
    return !canEdit;
  }

  factory TechnicalCardModel.fromJson(Map<String, dynamic> json) =>
      _$TechnicalCardModelFromJson(json);

  Map<String, dynamic> toJson() => _$TechnicalCardModelToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class TechnicalCardIngredientModel {
  const TechnicalCardIngredientModel({
    required this.id,
    this.ingredientId,
    this.ingredientName,
    this.brutto = 0,
    this.netto = 0,
    this.costPerUnit = 0,
    this.totalCost = 0,
    this.unit,
  });

  final int id;
  final int? ingredientId;
  final String? ingredientName;
  final double brutto;
  final double netto;
  final double costPerUnit;
  final double totalCost;
  final String? unit;

  factory TechnicalCardIngredientModel.fromJson(Map<String, dynamic> json) =>
      _$TechnicalCardIngredientModelFromJson(json);

  Map<String, dynamic> toJson() => _$TechnicalCardIngredientModelToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class UpdateTechnicalCardRequest {
  const UpdateTechnicalCardRequest({
    this.name,
    this.description,
    this.basePortions,
    this.outputPerPortion,
    this.outputUnit,
    this.ingredients,
    this.menuItemId,
    this.halalRequired = false,
    this.submitForApproval,
  });

  final String? name;
  final String? description;
  final double? basePortions;
  final double? outputPerPortion;
  final String? outputUnit;
  final List<TechnicalCardIngredientInput>? ingredients;

  /// Привязка к блюду меню (`menu_item_id`). После approve backend обновит
  /// название связанного блюда — так имя в таблице синхронизируется.
  final int? menuItemId;

  /// Обязательное поле бэкенда (`halal_required`) — NOT NULL в БД.
  final bool halalRequired;

  final bool? submitForApproval;

  Map<String, dynamic> toJson() => _$UpdateTechnicalCardRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class TechnicalCardIngredientInput {
  const TechnicalCardIngredientInput({
    this.ingredientId,
    this.ingredientName,
    this.brutto,
    this.netto,
    this.costPerUnit,
    this.sortOrder,
  });

  final int? ingredientId;
  final String? ingredientName;
  final double? brutto;
  final double? netto;
  final double? costPerUnit;
  final int? sortOrder;

  factory TechnicalCardIngredientInput.fromJson(Map<String, dynamic> json) =>
      _$TechnicalCardIngredientInputFromJson(json);

  Map<String, dynamic> toJson() => _$TechnicalCardIngredientInputToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class AuditLogListResponse {
  const AuditLogListResponse({
    this.items = const [],
    this.total = 0,
  });

  final List<AuditLogEntryModel> items;
  final int total;

  factory AuditLogListResponse.fromJson(Map<String, dynamic> json) =>
      _$AuditLogListResponseFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class AuditLogEntryModel {
  const AuditLogEntryModel({
    this.id,
    this.userId,
    this.userName,
    this.action,
    this.entityType,
    this.entityId,
    this.field,
    this.oldValue,
    this.newValue,
    this.createdAt,
  });

  final int? id;
  final int? userId;
  final String? userName;
  final String? action;
  final String? entityType;
  final String? entityId;
  final String? field;
  final String? oldValue;
  final String? newValue;
  final String? createdAt;

  factory AuditLogEntryModel.fromJson(Map<String, dynamic> json) =>
      _$AuditLogEntryModelFromJson(json);
}
