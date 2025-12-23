import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'core/services/token_storage.dart';
import 'core/services/storage_service.dart';

import 'core/bindings/app_binding.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  assert(() {
    const token = String.fromEnvironment('DEBUG_STAFF_TOKEN', defaultValue: '');
    if (token.isNotEmpty) {
      final box = GetStorage();
      final existing = box.read(StorageKeys.user);
      final Map<String, dynamic> user = existing is Map<String, dynamic>
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
      user['token'] = token;
      user['id'] = user['id'] ?? 'debug';
      user['login_mode'] = 'debug';
      box.write(StorageKeys.user, user);
      TokenStorage.saveToken(token);
    }
    return true;
  }());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.scaffold,
          onSurface: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.scaffold,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        useMaterial3: true,
      ),
      initialBinding: AppBinding(),
      initialRoute: Routes.splash,
      getPages: AppPages.pages,
    );
  }
}
