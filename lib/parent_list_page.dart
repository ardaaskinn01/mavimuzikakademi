import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_screen.dart';
import 'supervisor/reset_password_dialog.dart';

// Branşlar listesi
final List<String> allBranches = [
  'Gitar',
  'Piyano',
  'Yan flüt',
  'Keman',
  'Ney',
  'Bağlama',
  'Müzikli drama',
  'Solfej',
  'Ukulele',
  'Viyolonsel',
  'Resim',
];

class ParentListPage extends StatefulWidget {
  const ParentListPage({super.key});

  @override
  State<ParentListPage> createState() => _ParentListPageState();
}

class _ParentListPageState extends State<ParentListPage> {
  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      currentUserRole = doc.data()?['role'];
    });
  }

  // Branş düzenleme pop-up'ını gösteren fonksiyon
  void _showEditBranchesDialog(DocumentSnapshot parentDoc) {
    final parentData = parentDoc.data() as Map<String, dynamic>;
    final parentName = parentData['name'] ?? 'İsimsiz';
    final students = List.from(parentData['students'] ?? []);

    // Her öğrenci için seçili branşları tutan bir harita oluştur
    final Map<String, List<String>> selectedBranchesMap = {};
    for (var student in students) {
      final studentName = student['name'];
      if (studentName != null) {
        selectedBranchesMap[studentName] = List<String>.from(student['branches'] ?? []);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                "$parentName Branşları Düzenle",
                style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: students.map((student) {
                    final studentName = student['name'];
                    if (studentName == null) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            children: allBranches.map((branch) {
                              final isSelected = selectedBranchesMap[studentName]!.contains(branch);
                              return FilterChip(
                                label: Text(branch),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedBranchesMap[studentName]!.add(branch);
                                    } else {
                                      selectedBranchesMap[studentName]!.remove(branch);
                                    }
                                  });
                                },
                                selectedColor: Colors.blue[100],
                                checkmarkColor: Colors.blue[900],
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.blue[900] : Colors.blue[800],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "İptal",
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _saveBranches(parentDoc.id, students, selectedBranchesMap);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                  ),
                  child: const Text(
                    "Kaydet",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Firestore'da branşları güncelleyen fonksiyon
  Future<void> _saveBranches(
      String parentId,
      List<dynamic> students,
      Map<String, List<String>> selectedBranchesMap,
      ) async {
    try {
      final updatedStudents = students.map((student) {
        final studentName = student['name'];
        if (studentName != null) {
          return {
            ...student,
            'branches': selectedBranchesMap[studentName],
          };
        }
        return student;
      }).toList();

      await FirebaseFirestore.instance.collection('users').doc(parentId).update({
        'students': updatedStudents,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Branşlar başarıyla güncellendi!"),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Branşları güncellerken hata oluştu: $e"),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Veliler",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            )),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      backgroundColor: Colors.blue[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'parent')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Text(
                "Kayıtlı veli bulunamadı.",
                style: TextStyle(
                  color: Colors.blue[800],
                  fontSize: 16,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'İsimsiz';
              final username = data['username'] ?? '-';
              final students = data['students'] as List<dynamic>? ?? [];
              final phone = data['phone'] ?? '-';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(receiverId: doc.id),
                        ),
                      );
                    },
                    onLongPress: currentUserRole == 'supervisor'
                        ? () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            "Veli Sil",
                            style: TextStyle(color: Colors.blue[900]),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          content: Text("$name adlı veliyi silmek istediğinizden emin misiniz?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue[700],
                              ),
                              child: const Text("İptal"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red[700],
                              ),
                              child: const Text("Sil"),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await FirebaseFirestore.instance.collection('users').doc(doc.id).delete();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("$name silindi."),
                                backgroundColor: Colors.blue[700],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Hata oluştu: $e"),
                                backgroundColor: Colors.red[400],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        }
                      }
                    }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          (data.containsKey('profileImage') &&
                              data['profileImage'] != null &&
                              data['profileImage'].toString().isNotEmpty)
                              ? Container(
                            width: 60,
                            height: 60,
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
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _defaultAvatar(name: name);
                                },
                              ),
                            ),
                          )
                              : _defaultAvatar(name: name, size: 60),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Öğrenci listesi
                                ...students.map((student) {
                                  final studentName = student['name'] ?? 'İsimsiz';
                                  final studentAge = student['age'] ?? '-';
                                  final studentBranches = (student['branches'] as List<dynamic>?)
                                      ?.join(', ') ??
                                      'Branş yok';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      "$studentName - Yaş: $studentAge - Branş: $studentBranches",
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  );
                                }).toList(),

                                const SizedBox(height: 4),
                                Text(
                                  "@$username",
                                  style: TextStyle(
                                    color: Colors.blue[400],
                                    fontSize: 13,
                                  ),
                                ),

                                // Telefon numarası sadece supervisor görsün
                                if (currentUserRole == 'supervisor') ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    "Telefon: $phone",
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (currentUserRole == 'supervisor')
                            IconButton(
                              icon: Icon(Icons.key, color: Colors.blue[700]),
                              tooltip: "Şifreyi Değiştir",
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ResetPasswordDialog(username: username),
                                );
                              },
                            ),
                          // Yeni eklenen düzenleme butonu
                          if (currentUserRole == 'supervisor')
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue[700]),
                              tooltip: "Branşları Düzenle",
                              onPressed: () {
                                _showEditBranchesDialog(doc);
                              },
                            ),
                          IconButton(
                            icon: Icon(Icons.message, color: Colors.blue[700]),
                            tooltip: "Mesaj Gönder",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(receiverId: doc.id),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _defaultAvatar({required String name, double size = 60}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue[100],
        border: Border.all(
          color: Colors.blue[200]!,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'İ',
          style: TextStyle(
            color: Colors.blue[800],
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}