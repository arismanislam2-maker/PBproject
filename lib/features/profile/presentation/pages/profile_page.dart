import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../shared/providers/user_provider.dart';
import '../../../auth/data/repositories/auth_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _brown = Color(0xFF5A3A28);
  static const _cream = Color(0xFFF8F4EE);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _statusController = TextEditingController();
  final _picker = ImagePicker();
  final _repository = AuthRepository();
  String? _avatarPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _nameController.text = user?.displayName ?? '';
    _statusController.text = user?.status ?? '';
    _avatarPath = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image != null && mounted) setState(() => _avatarPath = image.path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เลือกรูปโปรไฟล์ไม่สำเร็จ: $error')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final provider = context.read<UserProvider>();
    final user = provider.user;
    final userId = user?.id;
    if (user == null || userId == null) return;

    setState(() => _saving = true);
    try {
      await _repository.updateUserProfile(
        userId: userId,
        displayName: _nameController.text,
        status: _statusController.text,
        avatarUrl: _avatarPath,
      );
      if (!mounted) return;
      provider.setUser(user.copyWith(
        displayName: _nameController.text.trim(),
        status: _statusController.text.trim(),
        avatarUrl: _avatarPath,
      ));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกโปรไฟล์ไม่สำเร็จ: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _brown,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'โปรไฟล์',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: InkWell(
                  onTap: _saving ? null : _pickAvatar,
                  customBorder: const CircleBorder(),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: Colors.white,
                        backgroundImage: _avatarPath == null
                            ? null
                            : FileImage(File(_avatarPath!)),
                        child: _avatarPath == null
                            ? const Icon(Icons.person, size: 54, color: _brown)
                            : null,
                      ),
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: _brown,
                          child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'ชื่อที่แสดง',
                  prefixIcon: Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'กรุณากรอกชื่อ'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _statusController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'สถานะ',
                  hintText: 'เช่น กำลังวางแผนการเงิน',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined, color: _brown),
                title: const Text('อีเมล'),
                subtitle: Text(user?.email ?? '-'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  backgroundColor: _brown,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกโปรไฟล์'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
