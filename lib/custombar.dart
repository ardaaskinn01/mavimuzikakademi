import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mavimuzikakademi/people_screen.dart';
import 'package:mavimuzikakademi/profile_screen.dart';
import 'package:mavimuzikakademi/settings.dart';
import 'package:mavimuzikakademi/parent/parent_notifications.dart';
import 'package:mavimuzikakademi/teacher/teacher_notifications.dart'; // Öğretmen bildirimi sayfası

class CustomBottomNav extends StatefulWidget {
  final String? userName;
  final String? username;
  final String? role;

  const CustomBottomNav({
    super.key,
    required this.userName,
    required this.username,
    required this.role,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  int unseenCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnseenNotifications();
    print(widget.role);
  }

  Future<void> _loadUnseenNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    print("Bildirilmemiş sayısı: $unseenCount");
    print(widget.role);
    if (uid == null || widget.role == null) return;

    Query query = FirebaseFirestore.instance.collection('notifications');

    if (widget.role == 'parent') {
      query = query.where('parentId', isEqualTo: uid);
    } else if (widget.role == 'teacher') {
      query = query.where('teacherId', isEqualTo: uid);
    } else {
      return; // Diğer roller için desteklenmiyor
    }

    final snapshot = await query.get();

    final count = snapshot.docs.where((doc) {
      final seenBy = List<String>.from(doc['seenBy'] ?? []);
      return !seenBy.contains(uid);
    }).length;

    setState(() {
      unseenCount = count;
    });
    print("Bildirilmemiş sayısı: $unseenCount");
  }

  void _openNotifications(BuildContext context) {
    if (widget.role == 'parent') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ParentNotificationsPage()),
      ).then((_) => _loadUnseenNotifications());
    } else if (widget.role == 'teacher') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TeacherNotificationsPage()),
      ).then((_) => _loadUnseenNotifications());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.home),
              color: Colors.blueAccent,
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            IconButton(
              icon: const Icon(Icons.messenger),
              color: Colors.blueAccent,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PeopleScreen()),
                );
              },
            ),

            // Bildirim ikonu gösteriliyor mu?
            if (widget.role == 'parent' || widget.role == 'teacher')
              GestureDetector(
                onTap: () => _openNotifications(context),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.notifications, color: Colors.white),
                    ),
                    if (unseenCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$unseenCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
            // Supervisor ise yer tutucu boşluk bırak
              const SizedBox(width: 48), // CircleAvatar boyutuna yakın bir boşluk

            IconButton(
              icon: const Icon(Icons.settings),
              color: Colors.blueAccent,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.person),
              color: Colors.blueAccent,
              onPressed: () {
                if (widget.userName != null &&
                    widget.username != null &&
                    widget.role != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        name: widget.userName!,
                        username: widget.username!,
                        role: widget.role!,
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
