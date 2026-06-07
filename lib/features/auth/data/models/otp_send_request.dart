import 'package:json_annotation/json_annotation.dart';

part 'otp_send_request.g.dart';

@JsonSerializable()
class OtpSendRequest {
  const OtpSendRequest({
    required this.phone,
    this.role,
    this.restaurantId,
  });

  final String phone;
  final String? role;

  @JsonKey(name: 'restaurant_id')
  final int? restaurantId;

  factory OtpSendRequest.fromJson(Map<String, dynamic> json) =>
      _$OtpSendRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OtpSendRequestToJson(this);
}
