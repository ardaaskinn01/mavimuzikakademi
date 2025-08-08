import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mavimuzikakademi/parent_list_page.dart';
import 'package:mavimuzikakademi/paylasimlar.dart';
import 'package:mavimuzikakademi/people_screen.dart';
import 'package:mavimuzikakademi/supervisor/reset_password_dialog.dart';
import 'package:mavimuzikakademi/supervisor/teacher_list_page.dart';

import '../custombar.dart';
import '../dersprogrami.dart';
import '../devamsizliklar.dart';
import '../login.dart';
import '../profile_screen.dart';
import '../settings.dart';
import 'dersler.dart';
import 'ogrenci.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  String? userName;
  String? username;
  String? role;
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          userName = data['name'] ?? 'İsimsiz';
          username = data['username'] ?? '-';
          role = data['role'] ?? 'unknown';
          print(role);
          profileImageUrl = data['profileImage']; // yeni satır
        });
      }
    }
  }

  String _getTurkishRole(String? role) {
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

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  int _selectedIndex = 2; // Ortadaki buton

  @override
  Widget build(BuildContext context) {
    // Veriler gelmediyse beklet
    if (userName == null || username == null || role == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Veriler geldiyse asıl UI
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: Colors.blue.shade700,
          elevation: 4,
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(top: 30, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Profil resmi
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: profileImageUrl != null && profileImageUrl!.isNotEmpty
                          ? NetworkImage(profileImageUrl!)
                          : const AssetImage('assets/images/pp.png') as ImageProvider,
                      fit: BoxFit.scaleDown,
                    ),
                  ),
                ),

                // Kullanıcı bilgisi
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      userName!,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getTurkishRole(role),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // Çıkış butonu
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _logout,
                  tooltip: 'Çıkış Yap',
                ),
              ],
            ),
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildTopButton(
                      context,
                      "Öğrenci Listesi",
                      Colors.deepOrange,
                      Icons.people,
                      StudentListScreen()
                    ),
                  ),
                  Expanded(
                    child: _buildTopButton(
                      context,
                      "Duyurular",
                      Colors.red,
                      Icons.announcement,
                      const PaylasimlarScreen(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildTopButton(
                      context,
                      "Devamsızlıklar",
                      Colors.purple,
                      Icons.event_busy,
                      const DevamsizliklarScreen(),
                    ),
                  ),
                  Expanded(
                    child: _buildTopButton(
                      context,
                      "Ders Programı",
                      Colors.indigoAccent,
                      Icons.calendar_month,
                      const Dersler(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: CustomBottomNav(
        userName: userName,
        username: username,
        role: role,
      ),
    );
  }

  Widget _buildTopButton(
      BuildContext context,
      String title,
      Color color,
      IconData icon,
      Widget? targetPage, {
        VoidCallback? onPressedOverride, // ← yeni parametre
      }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(),
        minimumSize: const Size.fromHeight(double.infinity),
      ),
      icon: Icon(icon, size: 24),
      label: Text(
        title,
        style: const TextStyle(fontSize: 17, color: Colors.white),
      ),
      onPressed:
      onPressedOverride ??
          (targetPage != null
              ? () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => targetPage),
          )
              : null),
    );
  }
}