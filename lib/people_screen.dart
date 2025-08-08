import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mavimuzikakademi/chat_screen.dart';
import 'package:mavimuzikakademi/supervisor/all_chats_screen.dart';

import 'custombar.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String searchQuery = '';
  String? currentUserRole;
  String? userName;
  String? username;
  String? role;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
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
        });
      }
    }
  }

  Future<void> _fetchCurrentUserRole() async {
    if (currentUserId == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
    setState(() {
      currentUserRole = doc['role'];
    });
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

  @override
  Widget build(BuildContext context) {
    if (currentUserRole == null) {
      return Scaffold(
        backgroundColor: Colors.blue[50],
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mesajlaşma",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          if (currentUserRole == 'supervisor')
            IconButton(
              icon: const Icon(Icons.history, size: 26),
              tooltip: 'Sohbetleri Gör',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatLogPage()),
                );
              },
            ),
        ],
      ),
      backgroundColor: Colors.blue[50],
      body: Column(
        children: [
          // 🔍 Arama Kutusu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Container(
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
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Kullanıcı ara...",
                  prefixIcon: Icon(Icons.search, color: Colors.blue[700]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          ),

          // 👥 Kullanıcı Listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue[700]!,
                      ),
                    ),
                  );
                }

                final users =
                    snapshot.data!.docs.where((doc) {
                      final userId = doc.id;
                      final name = (doc['name'] ?? '').toString().toLowerCase();
                      final role = doc['role'];

                      // Parent ise sadece teacher ve supervisor görsün
                      if (currentUserRole == 'parent' &&
                          role != 'teacher' &&
                          role != 'supervisor') {
                        return false;
                      }

                      return userId != currentUserId &&
                          name.contains(searchQuery);
                    }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      "Kullanıcı bulunamadı.",
                      style: TextStyle(color: Colors.blue[800], fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final userName = user['name'] ?? 'İsimsiz';
                    final data = user.data() as Map<String, dynamic>;

                    return FutureBuilder<DocumentSnapshot>(
                      future:
                          FirebaseFirestore.instance
                              .collection('chats')
                              .doc(_getChatId(currentUserId!, user.id))
                              .get(),
                      builder: (context, chatSnapshot) {
                        String lastMessage = '';
                        if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                          final data =
                              chatSnapshot.data!.data() as Map<String, dynamic>;
                          lastMessage = data['lastMessage'] ?? '';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            color: Colors.white,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              leading:
                                  data.containsKey('profileImage') &&
                                          data['profileImage'] != null &&
                                          data['profileImage']
                                              .toString()
                                              .isNotEmpty
                                      ? Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.blue[100]!,
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: Image.network(
                                            data['profileImage'],
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      )
                                      : CircleAvatar(
                                        backgroundColor: Colors.blue[100],
                                        radius: 24,
                                        child: Text(
                                          userName[0].toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.blue[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              title: Row(
                                children: [
                                  Text(
                                    userName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getTurkishRole(user['role']),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  lastMessage.isNotEmpty
                                      ? lastMessage
                                      : "Henüz mesaj yok.",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        lastMessage.isNotEmpty
                                            ? Colors.blue[800]
                                            : Colors.blue[400],
                                  ),
                                ),
                              ),
                              onTap: () {
                                final targetRole = user['role'];
                                final now = DateTime.now().toUtc().add(
                                  const Duration(hours: 3),
                                ); // Türkiye saati

                                final currentHour = now.hour;
                                final isWithinWorkingHours =
                                    currentHour >= 8 && currentHour < 18;

                                if (currentUserRole == 'parent' &&
                                    targetRole == 'teacher' &&
                                    !isWithinWorkingHours) {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          title: Text(
                                            "Mesaj Gönderilemez",
                                            style: TextStyle(
                                              color: Colors.blue[900],
                                            ),
                                          ),
                                          content: const Text(
                                            "Eğitmenlere sadece 08:00 - 18:00 saatleri arasında mesaj gönderebilirsiniz.",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: Text(
                                                "Tamam",
                                                style: TextStyle(
                                                  color: Colors.blue[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                  );
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            ChatScreen(receiverId: user.id),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        userName: userName,
        username: username,
        role: currentUserRole,
      ),
    );
  }

  String _getChatId(String uid1, String uid2) {
    return uid1.hashCode <= uid2.hashCode ? "$uid1\_$uid2" : "$uid2\_$uid1";
  }
}
