import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'supervisor/admin_home.dart';
import 'login.dart' show LoginScreen;
import 'parent/parent_home.dart';
import 'teacher/teacher_home.dart';

class LoginLoadingScreen extends StatefulWidget {
  final User user;

  const LoginLoadingScreen({super.key, required this.user});

  @override
  State<LoginLoadingScreen> createState() => _LoginLoadingScreenState();
}

class _LoginLoadingScreenState extends State<LoginLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  void _checkUserRole() async {
    await Future.delayed(const Duration(seconds: 2));

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();

    final role = doc.data()?['role'];

    if (role == 'parent') {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ParentHome()),
      );
    } else if (role == 'teacher') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TeacherHome()),
      );
    } else if (role == 'supervisor') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SupervisorHome()),
      );
    } else {
      // Bilinmeyen rol
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rol bilgisi bulunamadı.")),
      );
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/images/pp.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 20),

            // Yükleniyor yazısı
            const Text(
              "Oturum yükleniyor...",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
