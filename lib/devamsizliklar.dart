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

  @override
  void initState() {
    super.initState();
    getUserRole();
  }

  Future<void> getUserRole() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    setState(() {
      userRole = doc['role'];
    });
  }

  Map<String, Map<String, String>> attendanceStatus = {};

  void setAttendance(String lessonId, String studentId, String status) {
    setState(() {
      attendanceStatus[lessonId] ??= {};
      attendanceStatus[lessonId]![studentId] = status;
    });
  }

  Future<void> submitAttendance(String lessonId) async {
    final lessonAttendance = attendanceStatus[lessonId];
    if (lessonAttendance == null) return;

    final batch = FirebaseFirestore.instance.batch();

    for (var entry in lessonAttendance.entries) {
      final docRef = FirebaseFirestore.instance
          .collection('lessons')
          .doc(lessonId)
          .collection('attendances')
          .doc(entry.key);

      batch.set(docRef, {'status': entry.value, 'timestamp': Timestamp.now()});
    }
    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Devamsızlık kaydedildi')),
    );

    setState(() {
      attendanceStatus.remove(lessonId);
    });
  }

  Future<bool> hasAttendance(String lessonId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('lessons')
        .doc(lessonId)
        .collection('attendances')
        .limit(1)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (userRole == null) {
      return Scaffold(
        backgroundColor: Colors.blue[50],
        appBar: AppBar(
          title: const Text('Devamsızlıklar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.blue[800],
          elevation: 10,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!))),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.blue[50],
        appBar: AppBar(
          title: const Text(
            'Devamsızlıklar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.blue[800],
          elevation: 10,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Girilmemiş'),
              Tab(text: 'Girilmiş'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            buildLessonList(hasAttendance: false),
            buildLessonList(hasAttendance: true),
          ],
        ),
      ),
    );
  }

  Widget buildLessonList({required bool hasAttendance}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('lessons').orderBy('date', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
              strokeWidth: 3,
            ),
          );
        }

        final allLessons = snapshot.data!.docs.where((doc) {
          final date = (doc['date'] as Timestamp).toDate();
          final time = TimeOfDay(
            hour: int.parse((doc['time'] as String).split(":")[0]),
            minute: int.parse((doc['time'] as String).split(":")[1]),
          );
          final lessonDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          return lessonDateTime.isBefore(now);
        }).toList();

        return FutureBuilder<List<DocumentSnapshot>>(
          future: (() async {
            final filteredList = <DocumentSnapshot>[];
            for (var lesson in allLessons) {
              final attendanceExists = await this.hasAttendance(lesson.id);
              if (attendanceExists == hasAttendance) {
                // Öğretmen rolü kontrolü buraya taşındı
                if (userRole == 'teacher' && lesson['teacherId'] != userId) {
                  continue; // Eğer öğretmen kendi dersi değilse atla
                }
                filteredList.add(lesson);
              }
            }
            return filteredList;
          })(),
          builder: (context, attendanceSnapshot) {
            if (!attendanceSnapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                  strokeWidth: 3,
                ),
              );
            }

            final filteredLessons = attendanceSnapshot.data!;

            if (filteredLessons.isEmpty) {
              return Center(
                child: Text(
                  'Bu kategoride devamsızlık dersi bulunmuyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              itemCount: filteredLessons.length,
              itemBuilder: (context, index) {
                final lesson = filteredLessons[index];
                final lessonId = lesson.id;
                final date = (lesson['date'] as Timestamp).toDate();
                final formattedDate = DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
                final studentId = lesson['studentId'] as String;
                final studentName = lesson['studentName'] ?? 'Öğrenci';
                final currentStatus = attendanceStatus[lessonId]?[studentId];

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
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.blue[50],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                              title: Text(
                                studentName,
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
                                      color: currentStatus == 'var' ? Colors.green[700] : Colors.grey[400],
                                    ),
                                    onPressed: () => setAttendance(lessonId, studentId, 'var'),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.cancel,
                                      size: 22,
                                      color: currentStatus == 'yok' ? Colors.red[700] : Colors.grey[400],
                                    ),
                                    onPressed: () => setAttendance(lessonId, studentId, 'yok'),
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 60,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        backgroundColor: currentStatus == 'izinli' ? Colors.amber[600] : Colors.grey[300],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                      ),
                                      child: Text(
                                        'İzinli',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: currentStatus == 'izinli' ? Colors.black : Colors.grey[700],
                                        ),
                                      ),
                                      onPressed: () => setAttendance(lessonId, studentId, 'izinli'),
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
                              onPressed: () => submitAttendance(lessonId),
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
              },
            );
          },
        );
      },
    );
  }
}