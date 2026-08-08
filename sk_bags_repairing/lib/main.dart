import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'core/bindings/app_binding.dart';
import 'modules/auth/controllers/auth_controller.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  AppBinding().dependencies();
  final hasSession = await Get.find<AuthController>().hydrateSession();
  runApp(
    RepairingApp(initialRoute: hasSession ? Routes.repairCreate : Routes.login),
  );
}

class RepairingApp extends StatelessWidget {
  const RepairingApp({required this.initialRoute, super.key});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SkBags Repairing',
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      getPages: AppPages.pages,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B3F18),
          primary: const Color(0xFF8B3F18),
        ),
        scaffoldBackgroundColor: const Color(0xFFFBF7F1),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF121212),
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE4D8CB)),
          ),
        ),
      ),
      routingCallback: (routing) async {
        if (routing?.current == Routes.login) return;
        if (!Get.isRegistered<AuthController>()) return;
        final auth = Get.find<AuthController>();
        if (!auth.isLoggedIn.value) {
          await auth.hydrateSession();
        }
      },
    );
  }
}
