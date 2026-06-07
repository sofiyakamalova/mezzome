import 'package:json_annotation/json_annotation.dart';

part 'refresh_token_request.g.dart';

@JsonSerializable(fieldRename: FieldRename.none)
class RefreshTokenRequest {
  const RefreshTokenRequest({
    required this.phone,
    required this.deviceId,
    required this.refreshToken,
  });

  final String phone;

  @JsonKey(name: 'device_id')
  final String deviceId;

  @JsonKey(name: 'refresh_token')
  final String refreshToken;

  factory RefreshTokenRequest.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RefreshTokenRequestToJson(this);
}
