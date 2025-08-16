import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mavimuzikakademi/supervisor/studentlist.dart';

class DevamsizliklarScreen extends StatefulWidget {
  const DevamsizliklarScreen({super.key});

  @override
  State<DevamsizliklarScreen> createState() => _DevamsizliklarScreenState();
}

class _DevamsizliklarScreenState extends State<DevamsizliklarScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  final now = DateTime.now().add(const Duration(hours: 1));
  String? userRole;

  Future<void> getUserRole() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    setState(() {
      userRole = doc['role']; // "teacher", "supervisor", vs.
    });
  }

  @override
  void initState() {
    super.initState();
    getUserRole();
  }

  Map<String, Map<String, String>> attendanceStatus =
      {}; // {lessonId: {studentId: status}}

  void setAttendance(String lessonId, String studentId, String status) {
    setState(() {
      attendanceStatus[lessonId] ??= {};
      attendanceStatus[lessonId]![studentId] = status;
    });
  }

  Future<void> submitAttendance(String lessonId) async {
    final lessonAttendance = attendanceStatus[lessonId];
    if (lessonAttendance == null) return;

    for (var entry in lessonAttendance.entries) {
      await FirebaseFirestore.instance
          .collection('lessons')
          .doc(lessonId)
          .collection('attendances')
          .doc(entry.key) // studentId
          .set({'status': entry.value, 'timestamp': Timestamp.now()});
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Devamsızlık kaydedildi')));
  }

  Stream<QuerySnapshot> getLessonStream() {
    final baseQuery = FirebaseFirestore.instance.collection('lessons').orderBy('date');

    if (userRole == 'teacher') {
      return baseQuery.where('teacherId', isEqualTo: userId).snapshots();
    } else {
      return baseQuery.snapshots(); // supervisor tüm dersleri görsün
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: userRole == null
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: getLessonStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                strokeWidth: 3,
              ),
            );
          }

          final lessons =
              snapshot.data!.docs.where((doc) {
                final date = (doc['date'] as Timestamp).toDate();
                final time = TimeOfDay(
                  hour: int.parse((doc['time'] as String).split(":")[0]),
                  minute: int.parse((doc['time'] as String).split(":")[1]),
                );
                final lessonDateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                return lessonDateTime.isBefore(now);
              }).toList();

          if (lessons.isEmpty) {
            return Center(
              child: Text(
                'Henüz girilecek devamsızlık dersi yok.',
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
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              final lessonId = lesson.id;
              final date = (lesson['date'] as Timestamp).toDate();
              final formattedDate = DateFormat('dd MMMM yyyy', 'tr_TR').format(date);

              final studentId = lesson['studentId'] as String;
              final studentName = lesson['studentName'] ?? 'Öğrenci';
              final currentStatus = attendanceStatus[lessonId]?[studentId];

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12), // küçüldü
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
                    padding: const EdgeInsets.all(12), // küçüldü
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.school, color: Colors.blue[700], size: 18), // küçük ikon
                            const SizedBox(width: 6),
                            Text(
                              "${lesson['branch'] ?? 'Bilinmeyen'}",
                              style: TextStyle(
                                fontSize: 15, // küçüldü
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
                                    color: currentStatus == 'var'
                                        ? Colors.green[700]
                                        : Colors.grey[400],
                                  ),
                                  onPressed: () => setAttendance(lessonId, studentId, 'var'),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.cancel,
                                    size: 22,
                                    color: currentStatus == 'yok'
                                        ? Colors.red[700]
                                        : Colors.grey[400],
                                  ),
                                  onPressed: () => setAttendance(lessonId, studentId, 'yok'),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 60, // daha dar
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: currentStatus == 'izinli'
                                          ? Colors.amber[600]
                                          : Colors.grey[300],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                    ),
                                    child: Text(
                                      'İzinli',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: currentStatus == 'izinli'
                                            ? Colors.black
                                            : Colors.grey[700],
                                      ),
                                    ),
                                    onPressed: () =>
                                        setAttendance(lessonId, studentId, 'izinli'),
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
      ),
    );
  }
}
