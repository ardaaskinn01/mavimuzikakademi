import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mavimuzikakademi/parent_list_page.dart';
import 'package:mavimuzikakademi/paylasimlar.dart';
import 'package:mavimuzikakademi/people_screen.dart';
import 'package:mavimuzikakademi/supervisor/studentlist.dart';
import 'package:mavimuzikakademi/supervisor/teacher_list_page.dart';

import '../custombar.dart';
import '../dersprogrami.dart';
import '../devamsizliklar.dart';
import '../login.dart';
import '../profile_screen.dart';
import '../settings.dart';
import 'bildirim_screen.dart';

class SupervisorHome extends StatefulWidget {
  const SupervisorHome({super.key});

  @override
  State<SupervisorHome> createState() => _SupervisorHomeState();
}

class _SupervisorHomeState extends State<SupervisorHome> {
  String? userName;
  String? username;
  String? role;
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }


  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
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

  int _selectedIndex = 2; // Ortadaki buton

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        // AppBar yüksekliği artırıldı
        child: AppBar(
          backgroundColor: Colors.blue.shade700,
          elevation: 4,
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(top: 30, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Orta: Profil fotoğrafı
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: profileImageUrl != null && profileImageUrl!.isNotEmpty
                          ? NetworkImage(profileImageUrl!)
                          : const AssetImage('assets/images/pp.png') as ImageProvider,
                      fit: BoxFit.scaleDown, // Burada artık fit kullanılabilir
                    ),
                  ),
                ),


                if (userName != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      const Text(
                        "Yönetici",
                        style: TextStyle(fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                else
                  const Text(
                    "Yükleniyor...",
                    style: TextStyle(color: Colors.white),
                  ),

                // Sağ: Çıkış butonu
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
                      "Veliler",
                      Colors.deepOrange,
                      Icons.people,
                      const ParentListPage(),
                    ),
                  ),
                  Expanded(
                    child: _buildTopButton(
                      context,
                      "Eğitmenler",
                      Colors.red,
                      Icons.school,
                      const TeacherListPage(),
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
                      Icons.event,
                      const SupervisorStudentListScreen(),
                    ),
                  ),
                  Expanded(
                    child: _buildTopButton(
                      context,
                      "Ders Programı",
                      Colors.indigoAccent,
                      Icons.calendar_month,
                      const DersProgramiScreen(),
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
                      "Bildirimler",
                      Colors.teal,
                      Icons.notifications,
                      null,
                      onPressedOverride: () {
                        showDialog(
                          context: context,
                          builder: (_) => const BildirimScreen(),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildTopButton(
                      context,
                      "Duyurular",
                      Colors.green,
                      Icons.announcement,
                      const PaylasimlarScreen(),
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


  Widget _buildTopButton(BuildContext context,
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
      onPressed: onPressedOverride ??
          (targetPage != null
              ? () =>
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => targetPage))
              : null),
    );
  }
}
