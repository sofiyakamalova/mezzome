// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dish_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DishModel _$DishModelFromJson(Map<String, dynamic> json) => DishModel(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  price: (json['price'] as num?)?.toDouble(),
  costPerPortion: (json['cost_per_portion'] as num?)?.toDouble(),
  weight: (json['weight'] as num?)?.toDouble(),
  isAvailable: json['is_available'] as bool? ?? true,
  isActive: json['is_active'] as bool? ?? true,
  imageUrl: json['image_url'] as String?,
  categoryId: (json['category_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$DishModelToJson(DishModel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'price': instance.price,
  'cost_per_portion': instance.costPerPortion,
  'weight': instance.weight,
  'is_available': instance.isAvailable,
  'is_active': instance.isActive,
  'image_url': instance.imageUrl,
  'category_id': instance.categoryId,
};

DishListResponse _$DishListResponseFromJson(Map<String, dynamic> json) =>
    DishListResponse(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => DishModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$DishListResponseToJson(DishListResponse instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'total': instance.total,
    };
