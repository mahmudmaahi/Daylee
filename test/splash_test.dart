import 'package:daylee/data/services/storage_service.dart';
import 'package:daylee/features/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('splash shows the brand and animates without errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('DayLee'), findsOneWidget);
    expect(find.text('Your day, in one place'), findsOneWidget);

    // Leave before the hand-over timer fires (navigation needs GetMaterialApp).
    await tester.pumpWidget(const SizedBox());
  });
}
