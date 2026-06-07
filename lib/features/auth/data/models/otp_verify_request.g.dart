// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_verify_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpVerifyRequest _$OtpVerifyRequestFromJson(Map<String, dynamic> json) =>
    OtpVerifyRequest(
      phone: json['phone'] as String,
      otp: json['otp'] as String,
      deviceId: json['device_id'] as String,
      deviceType: json['device_type'] as String,
      appVersion: json['app_version'] as String?,
      deviceName: json['device_name'] as String?,
    );

Map<String, dynamic> _$OtpVerifyRequestToJson(OtpVerifyRequest instance) =>
    <String, dynamic>{
      'phone': instance.phone,
      'otp': instance.otp,
      'device_id': instance.deviceId,
      'device_type': instance.deviceType,
      'app_version': instance.appVersion,
      'device_name': instance.deviceName,
    };
