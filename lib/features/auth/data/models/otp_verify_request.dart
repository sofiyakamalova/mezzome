import 'package:json_annotation/json_annotation.dart';

part 'otp_verify_request.g.dart';

@JsonSerializable(fieldRename: FieldRename.none)
class OtpVerifyRequest {
  const OtpVerifyRequest({
    required this.phone,
    required this.otp,
    required this.deviceId,
    required this.deviceType,
    this.appVersion,
    this.deviceName,
  });

  final String phone;
  final String otp;

  @JsonKey(name: 'device_id')
  final String deviceId;

  @JsonKey(name: 'device_type')
  final String deviceType;

  @JsonKey(name: 'app_version')
  final String? appVersion;

  @JsonKey(name: 'device_name')
  final String? deviceName;

  factory OtpVerifyRequest.fromJson(Map<String, dynamic> json) =>
      _$OtpVerifyRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OtpVerifyRequestToJson(this);
}
