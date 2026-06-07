// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_verify_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpVerifyResponse _$OtpVerifyResponseFromJson(Map<String, dynamic> json) =>
    OtpVerifyResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      message: json['message'] as String?,
      pin: json['pin'] as String?,
      sessionId: json['session_id'] as String?,
    );

Map<String, dynamic> _$OtpVerifyResponseToJson(OtpVerifyResponse instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'message': instance.message,
      'pin': instance.pin,
      'session_id': instance.sessionId,
    };
