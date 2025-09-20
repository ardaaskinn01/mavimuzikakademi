import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mavimuzikakademi/chat_screen.dart';
import 'package:mavimuzikakademi/supervisor/all_chats_screen.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchCurrentUserRoleAndInfo();
    setState(() {});
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

  // İlgili kullanıcıların ID'lerini role göre getiren fonksiyon
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
    if (currentUserRole == 'supervisor') {
      // Supervisor ise kendi hariç tüm kullanıcıları getir.
      final allUsersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      for (var doc in allUsersSnapshot.docs) {
        relatedIds.add(doc.id);
      }
    } else if (currentUserRole == 'teacher') {
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

  // Tarih formatlama fonksiyonu
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return 'Bugün ${DateFormat('HH:mm').format(timestamp)}';
    } else if (messageDate == yesterday) {
      return 'Dün ${DateFormat('HH:mm').format(timestamp)}';
    } else {
      return DateFormat('dd.MM.yyyy HH:mm').format(timestamp);
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: "İsim ara...",
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.blue[700]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
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

  // TÜM KULLANICILARI VE SOHBET GEÇMİŞİNİ BİRLEŞTİREN BÖLÜM
  Widget _buildUserList() {
    return FutureBuilder<List<String>>(
      future: _getRelatedUserIds(), // İlgili kullanıcıların ID'lerini getir
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

        final relatedUserIds = relatedIdsSnapshot.data!;

        return FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _fetchUsersInBatches(relatedUserIds),
          builder: (context, usersSnapshot) {
            if (usersSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final allRelatedUsers = usersSnapshot.data ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: currentUserId)
                  .snapshots(),
              builder: (context, chatsSnapshot) {
                if (!chatsSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final chatDocs = chatsSnapshot.data!.docs;
                final chatMap = _createChatMap(chatDocs);

                // Tüm ilgili kullanıcıları sohbet verileriyle birleştir
                final List<Map<String, dynamic>> userChatData = [];
                for (final userDoc in allRelatedUsers) {
                  final userData = userDoc.data() as Map<String, dynamic>;
                  final chatId = _getChatId(currentUserId!, userDoc.id);
                  final chatData = chatMap[chatId];
                  final lastTimestamp = (chatData?['lastTimestamp'] as Timestamp?)?.toDate();

                  userChatData.add({
                    'user': userData,
                    'userId': userDoc.id,
                    'lastMessage': chatData?['lastMessage'],
                    'lastTimestamp': lastTimestamp,
                  });
                }

                // Sohbeti olanları en üste, olmayanları ise alfabetik sıraya göre sırala
                userChatData.sort((a, b) {
                  final timeA = a['lastTimestamp'] ?? DateTime(0);
                  final timeB = b['lastTimestamp'] ?? DateTime(0);

                  // İkisi de sohbet geçmişine sahipse, zamana göre sırala
                  if (timeA.millisecondsSinceEpoch > 0 && timeB.millisecondsSinceEpoch > 0) {
                    return timeB.compareTo(timeA);
                  }
                  // Sadece biri sohbet geçmişine sahipse, o en üstte olur
                  if (timeA.millisecondsSinceEpoch > 0) return -1;
                  if (timeB.millisecondsSinceEpoch > 0) return 1;
                  // İkisinin de sohbeti yoksa, isme göre sırala
                  return a['user']['name'].compareTo(b['user']['name']);
                });

                // Arama sorgusuna göre filtreleme
                final filteredData = userChatData.where((data) {
                  final name = (data['user']['name'] ?? '').toString().toLowerCase();
                  return name.contains(searchQuery);
                }).toList();

                if (filteredData.isEmpty) {
                  return Center(
                    child: Text(
                      "Kullanıcı bulunamadı.",
                      style: TextStyle(color: Colors.blue[800], fontSize: 16),
                    ),
                  );
                }

                return _buildListView(filteredData);
              },
            );
          },
        );
      },
    );
  }

  // Firebase kısıtlamasını aşmak için kullanıcıları 30'lu gruplar halinde çeken fonksiyon
  Future<List<QueryDocumentSnapshot>> _fetchUsersInBatches(List<String> userIds) async {
    List<List<String>> batches = [];
    int batchSize = 30;
    for (int i = 0; i < userIds.length; i += batchSize) {
      batches.add(
          userIds.sublist(i, i + batchSize > userIds.length ? userIds.length : i + batchSize));
    }

    List<QueryDocumentSnapshot> allUsers = [];
    for (var batch in batches) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      allUsers.addAll(snapshot.docs);
    }
    return allUsers;
  }

  // Sohbet verilerini hızlı erişim için bir haritaya dönüştürür
  Map<String, Map<String, dynamic>> _createChatMap(List<QueryDocumentSnapshot> chatDocs) {
    final Map<String, Map<String, dynamic>> chatMap = {};
    for (final chat in chatDocs) {
      final participants = List<String>.from(chat['participants'] ?? []);
      participants.sort();
      final chatId = participants.join('_');
      chatMap[chatId] = chat.data() as Map<String, dynamic>;
    }
    return chatMap;
  }

  // Sohbet ID'sini oluşturan fonksiyon
  String _getChatId(String userId1, String userId2) {
    final List<String> participants = [userId1, userId2];
    participants.sort();
    return participants.join('_');
  }

  // Liste görünümünü oluşturur
  Widget _buildListView(List<Map<String, dynamic>> userChatData) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: userChatData.length,
      itemBuilder: (context, index) {
        final data = userChatData[index];
        final userData = data['user'] as Map<String, dynamic>;
        final lastMessage = data['lastMessage'] ?? '';
        final lastTimestamp = data['lastTimestamp'] as DateTime?;

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
              leading: userData.containsKey('profileImage') &&
                  userData['profileImage'] != null &&
                  userData['profileImage'].toString().isNotEmpty
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
                    userData['profileImage'],
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
                  (userData['name'] ?? ' ')[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(
                    userData['role'] == 'parent' &&
                        userData['students'] != null &&
                        (userData['students'] as List).isNotEmpty
                        ? "${userData['name']} (${(userData['students'][0] as Map<String, dynamic>)['name'] ?? ''} velisi)"
                        : userData['name'] ?? 'İsimsiz',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getTurkishRole(userData['role']),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lastMessage.isNotEmpty ? lastMessage : "Henüz mesaj yok.",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: lastMessage.isNotEmpty ? Colors.blue[800] : Colors.blue[400],
                      ),
                    ),
                    if (lastTimestamp != null)
                      Text(
                        _formatTimestamp(lastTimestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[400],
                        ),
                      ),
                  ],
                ),
              ),
              onTap: () {
                final targetRole = userData['role'];
                final now = DateTime.now().toUtc().add(const Duration(hours: 3));
                final currentHour = now.hour;
                final isWithinWorkingHours = currentHour >= 8 && currentHour < 18;

                if (currentUserRole == 'parent' &&
                    targetRole == 'teacher' &&
                    !isWithinWorkingHours) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        "Mesaj Gönderilemez",
                        style: TextStyle(color: Colors.blue[900]),
                      ),
                      content: const Text(
                        "Eğitmenlere sadece 08:00 - 18:00 saatleri arasında mesaj gönderebilirsiniz.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Tamam",
                            style: TextStyle(color: Colors.blue[700]),
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
                    builder: (context) => ChatScreen(receiverId: data['userId']),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}