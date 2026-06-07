// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refresh_token_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RefreshTokenRequest _$RefreshTokenRequestFromJson(Map<String, dynamic> json) =>
    RefreshTokenRequest(
      phone: json['phone'] as String,
      deviceId: json['device_id'] as String,
      refreshToken: json['refresh_token'] as String,
    );

Map<String, dynamic> _$RefreshTokenRequestToJson(
  RefreshTokenRequest instance,
) => <String, dynamic>{
  'phone': instance.phone,
  'device_id': instance.deviceId,
  'refresh_token': instance.refreshToken,
};
