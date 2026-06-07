import 'package:json_annotation/json_annotation.dart';

part 'otp_verify_response.g.dart';

@JsonSerializable(fieldRename: FieldRename.none)
class OtpVerifyResponse {
  const OtpVerifyResponse({
    required this.accessToken,
    required this.refreshToken,
    this.message,
    this.pin,
    this.sessionId,
  });

  final String accessToken;
  final String refreshToken;
  final String? message;
  final String? pin;

  @JsonKey(name: 'session_id')
  final String? sessionId;

  factory OtpVerifyResponse.fromJson(Map<String, dynamic> json) =>
      _$OtpVerifyResponseFromJson(json);

  Map<String, dynamic> toJson() => _$OtpVerifyResponseToJson(this);
}
