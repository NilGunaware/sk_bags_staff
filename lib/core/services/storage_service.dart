import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class StorageKeys {
  static const String user = 'user';
}

class StorageService extends GetxService {
  StorageService();

  final GetStorage _box = GetStorage();

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _box.write(StorageKeys.user, user);
  }

  Map<String, dynamic>? readUser() {
    final value = _box.read(StorageKeys.user);
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> clearUser() async {
    await _box.remove(StorageKeys.user);
  }
}

