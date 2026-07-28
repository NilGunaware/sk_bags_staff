import 'package:get/get.dart';

import '../modules/auth/login/login_binding.dart';
import '../modules/auth/login/login_view.dart';
import '../modules/repairs/repair_create_view.dart';
import '../modules/repairs/repair_detail_view.dart';
import '../modules/repairs/repair_list_view.dart';
import '../modules/repairs/repairs_binding.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(
      name: Routes.login,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: Routes.repairs,
      page: () => const RepairListView(),
      binding: RepairListBinding(),
    ),
    GetPage(
      name: Routes.repairCreate,
      page: () => const RepairCreateView(),
      binding: RepairCreateBinding(),
    ),
    GetPage(
      name: Routes.repairDetail,
      page: () => const RepairDetailView(),
      binding: RepairDetailBinding(),
    ),
  ];
}
