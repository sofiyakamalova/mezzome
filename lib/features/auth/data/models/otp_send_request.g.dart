// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_send_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpSendRequest _$OtpSendRequestFromJson(Map<String, dynamic> json) =>
    OtpSendRequest(
      phone: json['phone'] as String,
      role: json['role'] as String?,
      restaurantId: (json['restaurant_id'] as num?)?.toInt(),
    );

Map<String, dynamic> _$OtpSendRequestToJson(OtpSendRequest instance) =>
    <String, dynamic>{
      'phone': instance.phone,
      'role': instance.role,
      'restaurant_id': instance.restaurantId,
    };
