import 'package:dio/dio.dart';
import 'package:mezzome/features/auth/data/models/otp_send_request.dart';
import 'package:mezzome/features/auth/data/models/otp_send_response.dart';
import 'package:mezzome/features/auth/data/models/otp_verify_request.dart';
import 'package:mezzome/features/auth/data/models/otp_verify_response.dart';
import 'package:mezzome/features/auth/data/models/user_model.dart';
import 'package:retrofit/retrofit.dart';

part 'auth_api.g.dart';

@RestApi()
abstract class AuthApi {
  factory AuthApi(Dio dio, {String? baseUrl}) = _AuthApi;

  @POST('/public/otp/send')
  Future<OtpSendResponse> sendOtp(@Body() OtpSendRequest request);

  @POST('/public/otp/verify')
  Future<OtpVerifyResponse> verifyOtp(@Body() OtpVerifyRequest request);

  @GET('/profile')
  Future<UserModel> getProfile();
}
