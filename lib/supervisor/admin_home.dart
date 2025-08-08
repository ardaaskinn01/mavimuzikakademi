import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mavimuzikakademi/parent_list_page.dart';
import 'package:mavimuzikakademi/paylasimlar.dart';
import 'package:mavimuzikakademi/people_screen.dart';
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

  void _onAddUser() {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final studentCountController = TextEditingController();

    String selectedRole = 'teacher';
    List<String> selectedBranches = [];

    final List<String> branches = [
      'Gitar', 'Piyano', 'Yan flüt', 'Keman', 'Ney', 'Bağlama',
      'Müzikli drama', 'Solfej', 'Ukulele', 'Viyolonsel', 'Diğer',
    ];

    final List<String> kaynaklar = [
      "Alfred’s Basic Piano Library",
      "Bastien Piano Basics",
      "Faber & Faber (Piano Adventures)",
      "Carl Czerny Etütleri",
      "Hanon",
      "Renklerle Piyano Öğretimi",
      "Enver Tufan & Selmin Tufan – Piyano Metodu 1, 2",
      "Gençler ve Yetişkinler İçin Başlangıç Piyano Metodu",
      "Piyano Albümü",
      "Yalçın İman – Piyano Metodu",
      "Sevinç Ereren – Kolay Piyano 1, 2 / Kolay Solfej",
    ];

    List<Map<String, dynamic>> students = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text("Yeni Kullanıcı Kaydet"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "İsim"),
                  ),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: "Kullanıcı Adı"),
                  ),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Şifre"),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: "Rol"),
                    items: const [
                      DropdownMenuItem(value: 'teacher', child: Text("Eğitmen")),
                      DropdownMenuItem(value: 'parent', child: Text("Veli")),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedRole = value;
                          selectedBranches = [];
                          students = [];
                          studentCountController.clear();
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  if (selectedRole == 'teacher') ...[
                    Wrap(
                      spacing: 6,
                      children: branches.map((branch) {
                        final selected = selectedBranches.contains(branch);
                        return FilterChip(
                          label: Text(branch),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                selectedBranches.add(branch);
                              } else {
                                selectedBranches.remove(branch);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  if (selectedRole == 'parent') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: "Telefon Numarası"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: studentCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Öğrenci Sayısı"),
                      onChanged: (value) {
                        final count = int.tryParse(value) ?? 0;
                        setState(() {
                          students = List.generate(count, (i) => {
                            'name': TextEditingController(),
                            'age': TextEditingController(),
                            'branches': <String>[],
                            'methods': <String>[], // 👈 EKLENDİ
                          });
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    for (int i = 0; i < students.length; i++) ...[
                      const Divider(),
                      Text("Öğrenci ${i + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextField(
                        controller: students[i]['name'],
                        decoration: const InputDecoration(labelText: "İsim"),
                      ),
                      TextField(
                        controller: students[i]['age'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Yaş"),
                      ),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            "Branşlar",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

// BRANŞ SEÇİMİ
                      Wrap(
                        spacing: 6,
                        children: branches.map((branch) {
                          final selected = students[i]['branches'].contains(branch);
                          return FilterChip(
                            label: Text(branch),
                            selected: selected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  students[i]['branches'].add(branch);
                                } else {
                                  students[i]['branches'].remove(branch);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),

// METODLAR BAŞLIĞI
                      // METODLAR SADECE PİYANO SEÇİLİYSE GÖRÜNÜR
                      if (students[i]['branches'].contains('Piyano')) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(top: 12, bottom: 8),
                            child: Text(
                              "Kullanılan Metodlar",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          children: kaynaklar.map((method) {
                            final selected = students[i]['methods'].contains(method);
                            return FilterChip(
                              label: Text(method, style: const TextStyle(fontSize: 12)),
                              selected: selected,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    students[i]['methods'].add(method);
                                  } else {
                                    students[i]['methods'].remove(method);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 10),
                    ],
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("İptal", style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final email = '${usernameController.text.trim()}@example.com';
                  final password = passwordController.text.trim();

                  if (selectedRole == 'teacher' && selectedBranches.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Lütfen en az bir branş seçiniz.")),
                    );
                    return;
                  }

                  try {
                    final secondaryApp = await Firebase.initializeApp(
                      name: 'SecondaryApp',
                      options: Firebase.app().options,
                    );

                    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
                    final userCred = await secondaryAuth.createUserWithEmailAndPassword(
                      email: email,
                      password: password,
                    );

                    final Map<String, dynamic> userDoc = {
                      'name': nameController.text.trim(),
                      'username': usernameController.text.trim(),
                      'role': selectedRole,
                      'password': password,
                    };

                    if (selectedRole == 'teacher') {
                      userDoc['branches'] = selectedBranches; // ✅ Burası doğru
                    } else if (selectedRole == 'parent') {
                      userDoc['phone'] = phoneController.text.trim();
                      userDoc['students'] = students.map((s) => {
                        'name': s['name'].text.trim(),
                        'age': s['age'].text.trim(),
                        'branches': s['branches'], // ✅ Bu da List<String>, doğru
                        'methods': s['methods'], // ✅ Bu da List<String>, doğru
                      }).toList();
                    }

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userCred.user!.uid)
                        .set(userDoc);

                    await secondaryAuth.signOut();
                    await secondaryApp.delete();

                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Kayıt başarısız: $e")),
                    );
                  }
                },
                child: const Text("Kaydet", style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        );
      },
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
                      const DevamsizliklarScreen(),
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

      floatingActionButton: FloatingActionButton(
        onPressed: _onAddUser,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.person_add),
        tooltip: "Kullanıcı Ekle",
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
