import 'dart:async';
import 'package:warqatek/services/access/auth_service.dart';

FutureOr<void> testExecutable(FutureOr<void> Function() testMain) async {
  AuthService.testingIterations = 50;
  AuthService.useCompute = false;
  try {
    await testMain();
  } finally {
    AuthService.testingIterations = 50;
  }
}
