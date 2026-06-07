import 'package:json_annotation/json_annotation.dart';

/// Роли пользователя (`domain.Role` в Swagger).
enum UserRole {
  @JsonValue('waiter')
  waiter,
  @JsonValue('chef')
  chef,
  @JsonValue('hot_cook')
  hotCook,
  @JsonValue('cold_cook')
  coldCook,
  @JsonValue('prep_cook')
  prepCook,
  @JsonValue('butcher')
  butcher,
  @JsonValue('storekeeper')
  storekeeper,
  @JsonValue('supervisor')
  supervisor,
  @JsonValue('manager')
  manager,
  @JsonValue('owner')
  owner,
  @JsonValue('admin')
  admin,
  @JsonValue('runner')
  runner,
  @JsonValue('client')
  client,
  unknown,
}

extension UserRoleX on UserRole {
  /// Значение для API (`snake_case` string).
  String get apiValue => switch (this) {
        UserRole.waiter => 'waiter',
        UserRole.chef => 'chef',
        UserRole.hotCook => 'hot_cook',
        UserRole.coldCook => 'cold_cook',
        UserRole.prepCook => 'prep_cook',
        UserRole.butcher => 'butcher',
        UserRole.storekeeper => 'storekeeper',
        UserRole.supervisor => 'supervisor',
        UserRole.manager => 'manager',
        UserRole.owner => 'owner',
        UserRole.admin => 'admin',
        UserRole.runner => 'runner',
        UserRole.client => 'client',
        UserRole.unknown => 'unknown',
      };

  static UserRole fromApi(String? value) {
    if (value == null || value.isEmpty) {
      return UserRole.unknown;
    }
    for (final role in UserRole.values) {
      if (role != UserRole.unknown && role.apiValue == value) {
        return role;
      }
    }
    return UserRole.unknown;
  }
}

class UserRoleConverter implements JsonConverter<UserRole, String> {
  const UserRoleConverter();

  @override
  UserRole fromJson(String json) => UserRoleX.fromApi(json);

  @override
  String toJson(UserRole object) => object.apiValue;
}
