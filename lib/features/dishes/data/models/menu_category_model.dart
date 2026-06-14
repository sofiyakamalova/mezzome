import 'package:json_annotation/json_annotation.dart';

part 'menu_category_model.g.dart';

/// Категория меню (`dto.MenuCategoryResponse`). Категории — источник «слотов»
/// при составлении плана: `slot_key` = id категории, `slot_title` = её название,
/// `sort_order` = порядок. Отдельной сущности «слот» в API нет.
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class MenuCategoryModel {
  const MenuCategoryModel({
    required this.id,
    this.name,
    this.nameEn,
    this.nameKz,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final int id;
  final String? name;
  final String? nameEn;
  final String? nameKz;
  final int sortOrder;
  final bool isActive;

  factory MenuCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$MenuCategoryModelFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class MenuCategoryListResponse {
  const MenuCategoryListResponse({this.categories = const []});

  final List<MenuCategoryModel> categories;

  factory MenuCategoryListResponse.fromJson(Map<String, dynamic> json) =>
      _$MenuCategoryListResponseFromJson(json);
}
