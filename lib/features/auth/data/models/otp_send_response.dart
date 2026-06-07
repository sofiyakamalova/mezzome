import 'package:json_annotation/json_annotation.dart';

part 'otp_send_response.g.dart';

@JsonSerializable(fieldRename: FieldRename.none)
class OtpSendResponse {
  const OtpSendResponse({
    this.message,
    this.phone,
  });

  final String? message;
  final String? phone;

  factory OtpSendResponse.fromJson(Map<String, dynamic> json) =>
      _$OtpSendResponseFromJson(json);

  Map<String, dynamic> toJson() => _$OtpSendResponseToJson(this);
}
