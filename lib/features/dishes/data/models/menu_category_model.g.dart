// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_category_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MenuCategoryModel _$MenuCategoryModelFromJson(Map<String, dynamic> json) =>
    MenuCategoryModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String?,
      nameEn: json['name_en'] as String?,
      nameKz: json['name_kz'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );

MenuCategoryListResponse _$MenuCategoryListResponseFromJson(
  Map<String, dynamic> json,
) => MenuCategoryListResponse(
  categories:
      (json['categories'] as List<dynamic>?)
          ?.map((e) => MenuCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);
