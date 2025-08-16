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
    // initState içinde async işlemler yaparken dikkatli olmak gerekir.
    // Bu yüzden _loadInitialData gibi birleşik bir fonksiyon kullanabiliriz.
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchCurrentUserRoleAndInfo();
    setState(() {}); // Rol bilgisi geldikten sonra arayüzü yeniden çizmek için.
  }

  Future<void> _fetchCurrentUserRoleAndInfo() async {
    if (currentUserId == null) return;
    final doc =
    await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    if (doc.exists) {
      final data = doc.data()!;
      currentUserRole = data['role'];
      userName = data['name'] ?? 'İsimsiz';
      username = data['username'] ?? '-';
    }
  }

  // YENİ EKLENEN FONKSİYON: İlişkili kullanıcı ID'lerini getirir.
  Future<List<String>> _getRelatedUserIds() async {
    if (currentUserId == null || currentUserRole == null) return [];

    final Set<String> relatedIds = {};

    // 1. Tüm rollerin yöneticileri görebilmesi için yönetici ID'lerini ekle.
    final supervisorSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'supervisor')
        .get();
    for (var doc in supervisorSnapshot.docs) {
      relatedIds.add(doc.id);
    }

    // 2. Role özel filtreleme yap.
    if (currentUserRole == 'teacher') {
      // Öğretmense, ders verdiği öğrencilerin velilerini ve öğrencileri bul.
      final lessonsSnapshot = await FirebaseFirestore.instance
          .collection('lessons')
          .where('teacherId', isEqualTo: currentUserId)
          .get();
      for (var lesson in lessonsSnapshot.docs) {
        if (lesson.data().containsKey('parentId') && lesson['parentId'] != null) {
          relatedIds.add(lesson['parentId']);
        }
        if (lesson.data().containsKey('studentId') && lesson['studentId'] != null) {
          // Öğrenciler de 'users' koleksiyonunda ise onları da ekle.
          relatedIds.add(lesson['studentId']);
        }
      }
    } else if (currentUserRole == 'parent') {
      // Veliyse, çocuğunun öğretmenlerini bul.
      final lessonsSnapshot = await FirebaseFirestore.instance
          .collection('lessons')
          .where('parentId', isEqualTo: currentUserId)
          .get();
      for (var lesson in lessonsSnapshot.docs) {
        if (lesson.data().containsKey('teacherId') && lesson['teacherId'] != null) {
          relatedIds.add(lesson['teacherId']);
        }
      }
    }

    // Kullanıcının kendisini listeden çıkar.
    relatedIds.remove(currentUserId);

    return relatedIds.toList();
  }

  String _getTurkishRole(String? role) {
    switch (role) {
      case 'teacher':
        return 'Eğitmen';
      case 'parent':
        return 'Veli';
      case 'supervisor':
        return 'Yönetici';
      case 'student':
        return 'Öğrenci';
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
          // Arama Kutusu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Container(
              // ... arama kutusu stilleri aynı ...
            ),
          ),

          // GÜNCELLENMİŞ KULLANICI LİSTESİ BÖLÜMÜ
          Expanded(
            child: _buildUserList(),
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

  // YENİ WIDGET: Arayüzü daha temiz tutmak için kullanıcı listesi mantığını ayırır.
  Widget _buildUserList() {
    // Supervisor herkesi görür.
    if (currentUserRole == 'supervisor') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data!.docs.where((doc) {
            return doc.id != currentUserId &&
                (doc['name'] ?? '').toString().toLowerCase().contains(searchQuery);
          }).toList();
          return _buildListView(users);
        },
      );
    }

    // Diğer roller (teacher, parent) için FutureBuilder -> StreamBuilder yapısı
    return FutureBuilder<List<String>>(
      future: _getRelatedUserIds(),
      builder: (context, relatedIdsSnapshot) {
        if (relatedIdsSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!relatedIdsSnapshot.hasData || relatedIdsSnapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "Görüşülecek kimse bulunamadı.",
              style: TextStyle(color: Colors.blue[800], fontSize: 16),
            ),
          );
        }

        final userIds = relatedIdsSnapshot.data!;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: userIds)
              .snapshots(),
          builder: (context, usersSnapshot) {
            if (!usersSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final users = usersSnapshot.data!.docs.where((doc) {
              final name = (doc['name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery);
            }).toList();

            return _buildListView(users);
          },
        );
      },
    );
  }

  // YENİ WIDGET: ListView.builder kod tekrarını önlemek için ayrıldı.
  Widget _buildListView(List<QueryDocumentSnapshot> users) {
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
  }
}

String _getChatId(String uid1, String uid2) {
  return uid1.hashCode <= uid2.hashCode ? "$uid1\_$uid2" : "$uid2\_$uid1";
}