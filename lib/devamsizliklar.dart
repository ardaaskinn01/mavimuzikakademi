import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DevamsizliklarScreen extends StatefulWidget {
  const DevamsizliklarScreen({super.key});

  @override
  State<DevamsizliklarScreen> createState() => _DevamsizliklarScreenState();
}

class _DevamsizliklarScreenState extends State<DevamsizliklarScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  final now = DateTime.now().add(const Duration(hours: 1));
  String? userRole;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  // {virtualId: {studentId: status}}
  Map<String, Map<String, String>> attendanceStatus = {};
  List<Map<String, dynamic>> allLessons = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getUserRole();

    final today = DateTime.now();
    if (today.day <= 3) {
      selectedMonth = today.month - 1;
      selectedYear = today.year;
    } else {
      selectedMonth = today.month;
      selectedYear = today.year;
    }

    // Verileri başlangıçta yükle
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
    });

    final lessons = await getFilteredLessons();

    // Tüm dersler için devamsızlık durumlarını yükle
    for (var lesson in lessons) {
      final lessonId = lesson['virtualId'];
      final isGroupLesson = lesson.containsKey('isGroupLesson')
          ? (lesson['isGroupLesson'] as bool? ?? false)
          : false;

      final studentIds = isGroupLesson
          ? List<String>.from(lesson['studentIds'] ?? [])
          : [lesson['studentId'] as String];

      await loadExistingAttendance(lesson['lessonId'], lessonId, studentIds);
    }

    setState(() {
      allLessons = lessons;
      isLoading = false;
    });
  }

  Future<void> getUserRole() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    setState(() {
      userRole = doc['role'];
    });
  }

  void setAttendance(String lessonId, String studentId, String status) {
    setState(() {
      attendanceStatus[lessonId] ??= {};
      attendanceStatus[lessonId]![studentId] = status;
    });
  }

  Future<void> submitAttendance(
      String lessonId, String virtualId, DateTime occurrenceDate) async {
    final lessonAttendance = attendanceStatus[virtualId];
    if (lessonAttendance == null) return;

    final batch = FirebaseFirestore.instance.batch();

    for (var entry in lessonAttendance.entries) {
      final docRef = FirebaseFirestore.instance
          .collection('lessons')
          .doc(lessonId)
          .collection('attendances')
          .doc('${entry.key}_${DateFormat('yyyyMMdd').format(occurrenceDate)}');

      batch.set(docRef, {
        'status': entry.value,
        'timestamp': Timestamp.now(),
        'occurrenceDate': Timestamp.fromDate(occurrenceDate),
      });
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Devamsızlık kaydedildi')),
    );

    setState(() {
      attendanceStatus.remove(virtualId);
    });
  }

  Future<List<Map<String, dynamic>>> getFilteredLessons() async {
    Query query = FirebaseFirestore.instance
        .collection('lessons')
        .orderBy('date', descending: true);

    // Sadece öğretmenin kendi derslerini göster
    if (userRole == 'teacher') {
      query = query.where('teacherId', isEqualTo: userId);
    } else if (userRole == 'student') {
      // Öğrenci ise kendi derslerini göster
      query = query.where('studentId', isEqualTo: userId);
    }
    // Admin veya diğer roller için filtre uygulanmaz (tüm dersleri görür)

    final snapshot = await query.get();

    final filteredLessons = snapshot.docs.where((doc) {
      final date = (doc['date'] as Timestamp).toDate();
      return date.isBefore(now) &&
          date.month == selectedMonth &&
          date.year == selectedYear;
    }).toList();

    final expandedLessons = <Map<String, dynamic>>[];

    for (var lesson in filteredLessons) {
      final data = lesson.data() as Map<String, dynamic>;
      final baseDate = (data['date'] as Timestamp).toDate();

      // Sadece kullanıcının yetkisi olan dersleri işle
      if (userRole == 'teacher' && data['teacherId'] != userId) {
        continue; // Öğretmenin kendi dersi değilse atla
      }

      if (userRole == 'student') {
        // Öğrenci için kontrol - bireysel ders mi grup dersi mi
        final isGroupLesson = data['isGroupLesson'] == true;
        if (isGroupLesson) {
          // Grup dersi ise öğrenci listede mi kontrol et
          final studentIds = List<String>.from(data['studentIds'] ?? []);
          if (!studentIds.contains(userId)) {
            continue; // Öğrenci bu grupta değilse atla
          }
        } else {
          // Bireysel ders ise öğrenci eşleşmeli
          if (data['studentId'] != userId) {
            continue; // Öğrencinin dersi değilse atla
          }
        }
      }

      if (data['recurring'] == true) {
        var currentDate = baseDate;
        while (currentDate.isBefore(now)) {
          expandedLessons.add({
            ...data,
            'virtualId': '${lesson.id}_${DateFormat('yyyyMMdd').format(currentDate)}',
            'lessonId': lesson.id,
            'date': Timestamp.fromDate(currentDate),
          });
          currentDate = currentDate.add(const Duration(days: 7));
        }
      } else {
        expandedLessons.add({
          ...data,
          'virtualId': lesson.id,
          'lessonId': lesson.id,
          'date': data['date'],
        });
      }
    }

    expandedLessons.sort((a, b) {
      final dateA = (a['date'] as Timestamp).toDate();
      final dateB = (b['date'] as Timestamp).toDate();
      return dateB.compareTo(dateA);
    });

    return expandedLessons;
  }

  // Önceden kaydedilmiş devamsızlık durumlarını yükle
  Future<void> loadExistingAttendance(String lessonId, String virtualId, List<String> studentIds) async {
    try {
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(lessonId)
          .collection('attendances')
          .get();

      final existingAttendance = <String, String>{};

      for (var attDoc in attendanceSnapshot.docs) {
        for (var studentId in studentIds) {
          // Doküman ID'si studentId ve tarih içeriyorsa
          if (attDoc.id.startsWith('${studentId}_')) {
            final attData = attDoc.data();
            existingAttendance[studentId] = attData['status'] ?? 'unknown';
          }
        }
      }

      if (existingAttendance.isNotEmpty) {
        setState(() {
          attendanceStatus[virtualId] = existingAttendance;
        });
      }
    } catch (e) {
      print('Devamsızlık yükleme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userRole == null || isLoading) {
      return Scaffold(
        backgroundColor: Colors.blue[50],
        appBar: AppBar(
          title: const Text('Devamsızlıklar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.blue[800],
          elevation: 10,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            DropdownButton<int>(
              value: selectedMonth,
              dropdownColor: Colors.blue[700],
              icon: const Icon(Icons.calendar_month, color: Colors.white),
              underline: const SizedBox(),
              items: List.generate(12, (index) {
                final month = index + 1;
                return DropdownMenuItem(
                  value: month,
                  child: Text(
                    DateFormat('MMMM', 'tr_TR').format(DateTime(0, month)),
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedMonth = value;
                    loadData(); // Ay değiştiğinde verileri yeniden yükle
                  });
                }
              },
            ),
          ],
        ),
        body: Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!))),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.blue[50],
        appBar: AppBar(
          title: const Text('Devamsızlıklar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.blue[800],
          elevation: 10,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(
                icon: Icon(Icons.check_circle, size: 20),
                text: 'Kayıtlı Dersler',
              ),
              Tab(
                icon: Icon(Icons.pending_actions, size: 20),
                text: 'Kayıtsız Dersler',
              ),
            ],
          ),
          actions: [
            DropdownButton<int>(
              value: selectedMonth,
              dropdownColor: Colors.blue[700],
              icon: const Icon(Icons.calendar_month, color: Colors.white),
              underline: const SizedBox(),
              items: List.generate(12, (index) {
                final month = index + 1;
                return DropdownMenuItem(
                  value: month,
                  child: Text(
                    DateFormat('MMMM', 'tr_TR').format(DateTime(0, month)),
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedMonth = value;
                    loadData(); // Ay değiştiğinde verileri yeniden yükle
                  });
                }
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Kayıtlı Dersler Tab
            _buildKayitliDerslerTab(),

            // Kayıtsız Dersler Tab
            _buildKayitsizDerslerTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildKayitliDerslerTab() {
    final kayitliLessons = allLessons.where((lesson) {
      final virtualId = lesson['virtualId'];
      return attendanceStatus.containsKey(virtualId) &&
          attendanceStatus[virtualId]!.isNotEmpty;
    }).toList();

    if (kayitliLessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.blue[300]),
            SizedBox(height: 16),
            Text(
              'Kayıtlı ders bulunmuyor',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        children: [
          ...kayitliLessons.map((lesson) => buildLessonCard(lesson)),
        ],
      ),
    );
  }

  Widget _buildKayitsizDerslerTab() {
    final kayitsizLessons = allLessons.where((lesson) {
      final virtualId = lesson['virtualId'];
      return !attendanceStatus.containsKey(virtualId) ||
          attendanceStatus[virtualId]!.isEmpty;
    }).toList();

    if (kayitsizLessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in, size: 64, color: Colors.blue[300]),
            SizedBox(height: 16),
            Text(
              'Tüm dersler kaydedilmiş',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        children: [
          ...kayitsizLessons.map((lesson) => buildLessonCard(lesson)),
        ],
      ),
    );
  }

  Widget buildLessonCard(Map<String, dynamic> lesson) {
    final lessonId = lesson['virtualId'];
    final date = (lesson['date'] as Timestamp).toDate();
    final formattedDate = DateFormat('dd MMMM yyyy', 'tr_TR').format(date);

    final isGroupLesson = lesson.containsKey('isGroupLesson')
        ? (lesson['isGroupLesson'] as bool? ?? false)
        : false;

    final studentIds = isGroupLesson
        ? List<String>.from(lesson['studentIds'] ?? [])
        : [lesson['studentId'] as String];
    final studentNames = isGroupLesson
        ? List<String>.from(lesson['studentNames'] ?? [])
        : [lesson['studentName'] ?? 'Öğrenci'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school, color: Colors.blue[700], size: 18),
                  const SizedBox(width: 6),
                  Text(
                    "${lesson['branch'] ?? 'Bilinmeyen'}",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formattedDate,
                style: TextStyle(
                  color: Colors.blue[700],
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Öğretmen: ${lesson['teacherName'] ?? 'Bilinmiyor'}',
                style: TextStyle(
                  color: Colors.blue[800],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.blue[100], thickness: 1),
              const SizedBox(height: 4),

              // 🔹 Öğrenciler listesi
              for (int i = 0; i < studentIds.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.blue[50],
                  ),
                  child: ListTile(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10),
                    title: Text(
                      studentNames[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.blue[900],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.check_circle,
                            size: 22,
                            color:
                            attendanceStatus[lessonId]?[studentIds[i]] == 'var'
                                ? Colors.green[700]
                                : Colors.grey[400],
                          ),
                          onPressed: () =>
                              setAttendance(lessonId, studentIds[i], 'var'),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.cancel,
                            size: 22,
                            color:
                            attendanceStatus[lessonId]?[studentIds[i]] == 'yok'
                                ? Colors.red[700]
                                : Colors.grey[400],
                          ),
                          onPressed: () =>
                              setAttendance(lessonId, studentIds[i], 'yok'),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 60,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor:
                              attendanceStatus[lessonId]?[studentIds[i]] ==
                                  'izinli'
                                  ? Colors.amber[600]
                                  : Colors.grey[300],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding:
                              const EdgeInsets.symmetric(vertical: 2),
                            ),
                            child: Text(
                              'İzinli',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                attendanceStatus[lessonId]?[studentIds[i]] ==
                                    'izinli'
                                    ? Colors.black
                                    : Colors.grey[700],
                              ),
                            ),
                            onPressed: () => setAttendance(
                                lessonId, studentIds[i], 'izinli'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => submitAttendance(
                    lesson['lessonId'],
                    lesson['virtualId'],
                    (lesson['date'] as Timestamp).toDate(),
                  ),
                  child: const Text(
                    'Kaydet',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}