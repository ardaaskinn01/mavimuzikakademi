import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
    addBranchesToFirestore();
    _loadUnseenNotifications();
    print(widget.role);
  }

  final List<String> branches = [
    'Gitar', 'Piyano', 'Yan flüt', 'Keman', 'Ney', 'Bağlama',
    'Müzikli drama', 'Solfej', 'Ukulele', 'Viyolonsel', 'Resim',
  ];

  Future<void> addBranchesToFirestore() async {
    final CollectionReference branchesRef =
    FirebaseFirestore.instance.collection('branches');

    // Firestore'daki mevcut şubeleri al
    final snapshot = await branchesRef.get();
    final existingBranches =
    snapshot.docs.map((doc) => doc['name'] as String).toList();

    for (String branch in branches) {
      // Eğer Firestore'da yoksa ekle
      if (!existingBranches.contains(branch)) {
        await branchesRef.add({'name': branch});
      }
    }
  }


  void _onAddUser() {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final studentCountController = TextEditingController();

    String selectedRole = 'teacher';
    List<String> selectedBranches = [];



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

                  // 🔹 Eğitmen için Firestore’dan branş listesi
                  if (selectedRole == 'teacher')
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance.collection('branches').get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final branches = snapshot.data!.docs.map((d) => d['name'] as String).toList();

                        return Wrap(
                          spacing: 6,
                          children: [
                            ...branches.map((branch) {
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

                            // 🔹 Yeni branş ekleme butonu
                            ActionChip(
                              avatar: const Icon(Icons.add, color: Colors.white, size: 18),
                              label: const Text("Yeni Branş"),
                              backgroundColor: Colors.green,
                              labelStyle: const TextStyle(color: Colors.white),
                              onPressed: () async {
                                final newBranchController = TextEditingController();
                                final result = await showDialog<String>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Yeni Branş Ekle"),
                                    content: TextField(
                                      controller: newBranchController,
                                      decoration: const InputDecoration(hintText: "Branş adı"),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("İptal"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          final text = newBranchController.text.trim();
                                          if (text.isNotEmpty) {
                                            Navigator.pop(context, text);
                                          }
                                        },
                                        child: const Text("Ekle"),
                                      ),
                                    ],
                                  ),
                                );

                                if (result != null && result.isNotEmpty) {
                                  await FirebaseFirestore.instance.collection('branches').add({
                                    'name': result,
                                  });
                                  setState(() {}); // Listeyi güncellemek için yeniden çiz
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),

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
                            'methods': <String>[],
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

                      // 🔹 Öğrencinin branş seçimi Firestore’dan
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance.collection('branches').get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();

                          final branches = snapshot.data!.docs.map((d) => d['name'] as String).toList();

                          return Wrap(
                            spacing: 6,
                            children: [
                              ...branches.map((branch) {
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

                              ActionChip(
                                avatar: const Icon(Icons.add, color: Colors.white, size: 18),
                                label: const Text("Yeni Branş"),
                                backgroundColor: Colors.green,
                                labelStyle: const TextStyle(color: Colors.white),
                                onPressed: () async {
                                  final newBranchController = TextEditingController();
                                  final result = await showDialog<String>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Yeni Branş Ekle"),
                                      content: TextField(
                                        controller: newBranchController,
                                        decoration: const InputDecoration(hintText: "Branş adı"),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("İptal"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            final text = newBranchController.text.trim();
                                            if (text.isNotEmpty) {
                                              Navigator.pop(context, text);
                                            }
                                          },
                                          child: const Text("Ekle"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (result != null && result.isNotEmpty) {
                                    await FirebaseFirestore.instance.collection('branches').add({
                                      'name': result,
                                    });
                                    setState(() {});
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      ),

                      // Eğer öğrenci Piyano seçerse metodlar
                      if (students[i]['branches'].contains('Piyano')) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(top: 12, bottom: 8),
                            child: Text("Kullanılan Metodlar", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    ],
                  ],
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
                      userDoc['branches'] = selectedBranches;
                    } else if (selectedRole == 'parent') {
                      userDoc['phone'] = phoneController.text.trim();
                      userDoc['students'] = students.map((s) => {
                        'name': s['name'].text.trim(),
                        'age': s['age'].text.trim(),
                        'branches': s['branches'],
                        'methods': s['methods'],
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

            // Bildirim ikonu
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
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
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
            else if (widget.role == 'supervisor')
              IconButton(
                icon: const Icon(Icons.person_add),
                color: Colors.blueAccent,
                onPressed: _onAddUser, // Supervisor ekleme fonksiyonu
                tooltip: "Kullanıcı Ekle",
              )
            else
              const SizedBox(width: 48),

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
