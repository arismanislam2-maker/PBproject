
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../../core/database/database_helper.dart';
import '../models/user_model.dart';

class AuthRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<UserModel?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final db = await _dbHelper.database;
    
    try {
      // Check existing email
      final existing = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );
      
      if (existing.isNotEmpty) {
        throw Exception('อีเมลนี้ถูกใช้งานแล้ว');
      }

      final passwordHash = _hashPassword(password);
      
      // Insert user
      final userId = await db.insert('users', {
        'email': email,
        'password_hash': passwordHash,
        'display_name': displayName,
        'currency': 'THB',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create default cash account
      await db.insert('accounts', {
        'user_id': userId,
        'account_name': 'เงินสด',
        'account_type': 'CASH',
        'initial_balance': 0,
        'is_default': 1,
        'color_hex': '#6B4F3A',
        'icon_name': 'cash',
      });

      return UserModel(
        id: userId,
        email: email,
        displayName: displayName,
      );
    } catch (e) {
      throw Exception('สมัครสมาชิกไม่สำเร็จ: $e');
    }
  }

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    final db = await _dbHelper.database;
    
    final passwordHash = _hashPassword(password);
    
    final result = await db.query(
      'users',
      where: 'email = ? AND password_hash = ? AND deleted_at IS NULL',
      whereArgs: [email, passwordHash],
    );

    if (result.isEmpty) {
      throw Exception('อีเมลหรือรหัสผ่านไม่ถูกต้อง');
    }

    // Update last login
    await db.update(
      'users',
      {'last_login_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [result.first['id']],
    );

    return UserModel.fromMap(result.first);
  }

  Future<UserModel?> getUserById(int userId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'users',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [userId],
    );
    
    if (result.isEmpty) return null;
    return UserModel.fromMap(result.first);
  }

  Future<void> deleteAccount(int userId) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updateUserAvatar(int userId, String avatarUrl) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {'avatar_url': avatarUrl},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updateUserProfile({
    required int userId,
    required String displayName,
    required String status,
    String? avatarUrl,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {
        'display_name': displayName.trim(),
        'status': status.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
