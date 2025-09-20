import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

import 'custombar.dart';

class ProfileScreen extends StatefulWidget {
  final String name;
  final String username;
  final String role;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.username,
    required this.role,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? imageUrl;
  List<Map<String, dynamic>> students = [];
  List<dynamic> teacherBranches = []; // Değişiklik burada

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: widget.username)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();

      if (widget.role == 'parent') {
        setState(() {
          students = List<Map<String, dynamic>>.from(data['students'] ?? []);
        });
      } else if (widget.role == 'teacher') {
        setState(() {
          // Değişiklik burada
          teacherBranches = data['branches'] ?? [];
        });
      }
    }
  }

  Future<void> _loadProfileImage() async {
    final storage = Supabase.instance.client.storage;
    try {
      final files = await storage.from('kuyumcu').list(path: 'users/${widget.username}');

      final hasProfileImage = files.any((file) => file.name == 'profile.jpg');

      if (hasProfileImage) {
        final url = storage.from('kuyumcu').getPublicUrl('users/${widget.username}/profile.jpg');
        setState(() => imageUrl = url);
      } else {
        setState(() => imageUrl = null);
      }
    } catch (e) {
      debugPrint("Fotoğraf kontrolü başarısız: $e");
      setState(() => imageUrl = null);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    final file = File(image.path);
    final storage = Supabase.instance.client.storage;
    final filePath = 'users/${widget.username}/profile.jpg';

    try {
      await storage.from('kuyumcu').upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = storage.from('kuyumcu').getPublicUrl(filePath);
      setState(() => imageUrl = publicUrl);

      await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({'profileImage': publicUrl});
        }
      });

    } catch (e) {
      debugPrint("Yükleme hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fotoğraf yüklenemedi.")),
      );
    }
  }

  String getTranslatedRole(String role) {
    switch (role) {
      case 'teacher':
        return 'Eğitmen';
      case 'parent':
        return 'Veli';
      case 'supervisor':
        return 'Yönetici';
      default:
        return 'Bilinmiyor';
    }
  }

  String _formatBranches(List<dynamic> branches) {
    return branches.map((e) => e.toString()).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final translatedRole = getTranslatedRole(widget.role);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 70,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Profil',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black26)]
                  )),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[800]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 👤 Avatar
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue[100]!, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.2),
                                blurRadius: 12,
                                spreadRadius: 4,
                              )
                            ],
                          ),
                          child: ClipOval(
                            child: imageUrl != null
                                ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              width: 140,
                              height: 140,
                            )
                                : Container(
                              color: Colors.blue[100],
                              child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.blue[800]),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: const Icon(
                                Icons.camera_alt,
                                size: 22,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 👤 Bilgiler
                  Column(
                    children: [
                      _buildInfoTile(
                        icon: Icons.person,
                        label: 'Ad Soyad',
                        value: widget.name,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoTile(
                        icon: Icons.alternate_email,
                        label: 'Kullanıcı Adı',
                        value: "@${widget.username}",
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoTile(
                        icon: Icons.badge,
                        label: 'Rol',
                        value: translatedRole,
                        theme: theme,
                      ),
                      if (widget.role == 'teacher') ...[
                        const SizedBox(height: 16),
                        _buildInfoTile(
                          icon: Icons.class_,
                          label: 'Branş',
                          value: teacherBranches.isEmpty
                              ? 'Bilinmiyor'
                              : _formatBranches(teacherBranches), // Değişiklik burada
                          theme: theme,
                        ),
                      ],
                    ],
                  ),

                  // Öğrenci Listesi (Sadece veli rolünde)
                  if (widget.role == 'parent' && students.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Öğrencilerim',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...students.map((student) => _buildStudentCard(student)).toList(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        userName: widget.name,
        username: widget.username,
        role: widget.role,
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                student['name'] ?? 'İsimsiz',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.cake_outlined, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Yaş: ${student['age'] ?? 'Belirtilmemiş'}',
                style: TextStyle(
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.school_outlined, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Branşlar: ${_formatBranches(student['branches'] ?? [])}',
                  style: TextStyle(
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue[800], size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    label,
                    style: TextStyle(
                        color: Colors.blue[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w500
                    )
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}