import 'test_helpers.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  await setupLocalizationTests();
  await testMain();
}
