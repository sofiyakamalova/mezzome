// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  phone: json['phone'] as String,
  role: const UserRoleConverter().fromJson(json['role'] as String),
  isActive: json['is_active'] as bool? ?? true,
  restaurantId: (json['restaurant_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'phone': instance.phone,
  'role': const UserRoleConverter().toJson(instance.role),
  'is_active': instance.isActive,
  'restaurant_id': instance.restaurantId,
};
