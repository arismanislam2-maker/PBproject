import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _keySavedUserId = 'saved_user_id';
  static const _keyRememberMe = 'remember_me';

  /// บันทึก user id สำหรับ auto-login (จำรหัส/จำการเข้าสู่ระบบ)
  static Future<void> saveUserSession(int userId, {bool rememberMe = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySavedUserId, userId);
    await prefs.setBool(_keyRememberMe, rememberMe);
  }

  /// ดึง user id ที่บันทึกไว้ (ถ้ามี)
  static Future<int?> getSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_keyRememberMe) ?? true;
    if (!rememberMe) return null;
    return prefs.getInt(_keySavedUserId);
  }

  /// ตรวจสอบสถานะจำรหัส
  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? true;
  }

  /// ลบ session เมื่อออกจากระบบ (Logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySavedUserId);
  }
}
