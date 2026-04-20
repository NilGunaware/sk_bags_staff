import 'package:get/get.dart';

import '../modules/orders/order_create_view.dart';
import '../modules/orders/order_detail_view.dart';
import '../modules/orders/order_list_view.dart';
import '../modules/orders/orders_binding.dart';
import '../modules/scanner/scanner_binding.dart';
import '../modules/scanner/scanner_view.dart';
import '../modules/splash/splash_binding.dart';
import '../modules/splash/splash_view.dart';
import '../modules/auth/login/login_binding.dart';
import '../modules/auth/login/login_view.dart';
import '../modules/home/home_binding.dart';
import '../modules/home/home_view.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: Routes.login,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: Routes.scanner,
      page: () => const ScannerView(),
      binding: ScannerBinding(),
    ),
    GetPage(
      name: Routes.orders,
      page: () => const OrderListView(),
      binding: OrdersBinding(),
    ),
    GetPage(
      name: Routes.orderCreate,
      page: () => const OrderCreateView(),
      binding: OrdersBinding(),
    ),
    GetPage(
      name: Routes.orderDetail,
      page: () => const OrderDetailView(),
      binding: OrdersBinding(),
    ),
  ];
}
