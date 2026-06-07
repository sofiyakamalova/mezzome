import 'package:json_annotation/json_annotation.dart';
import 'package:mezzome/domain/user_role.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.isActive = true,
    this.restaurantId,
  });

  final int id;
  final String name;
  final String phone;

  @UserRoleConverter()
  final UserRole role;

  @JsonKey(name: 'is_active')
  final bool isActive;

  @JsonKey(name: 'restaurant_id')
  final int? restaurantId;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
