// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_send_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpSendResponse _$OtpSendResponseFromJson(Map<String, dynamic> json) =>
    OtpSendResponse(
      message: json['message'] as String?,
      phone: json['phone'] as String?,
    );

Map<String, dynamic> _$OtpSendResponseToJson(OtpSendResponse instance) =>
    <String, dynamic>{'message': instance.message, 'phone': instance.phone};
