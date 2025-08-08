import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ParentProgramScreen extends StatelessWidget {
  const ParentProgramScreen({Key? key}) : super(key: key);

  Future<List<QueryDocumentSnapshot>> fetchLessonsForParent(String parentId) async {
    // 1. Parent verisini al
    final parentDoc = await FirebaseFirestore.instance.collection('users').doc(parentId).get();
    final parentData = parentDoc.data();

    if (parentData == null || parentData['students'] == null) return [];

    final List<dynamic> studentList = parentData['students'];
    final List<String> studentNames = studentList.map((e) => e['name'].toString().toLowerCase()).toList();

    // 2. Lessons koleksiyonunu al
    final lessonsSnapshot = await FirebaseFirestore.instance.collection('lessons').get();

    // 3. Öğrencinin adına göre filtrele
    final now = DateTime.now();

    final filteredLessons = lessonsSnapshot.docs.where((lessonDoc) {
      final data = lessonDoc.data();
      final lessonStudentName = (data['studentName'] ?? '').toString().toLowerCase();
      final Timestamp? timestamp = data['date'];
      if (timestamp == null) return false;

      final lessonDate = timestamp.toDate();
      return studentNames.contains(lessonStudentName) && lessonDate.isAfter(now);
    }).toList();

    // Tarihe göre sırala (yakın olanlar en önce)
    filteredLessons.sort((a, b) {
      final dateA = (a['date'] as Timestamp).toDate();
      final dateB = (b['date'] as Timestamp).toDate();
      return dateA.compareTo(dateB);
    });

    return filteredLessons;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(child: Text("Giriş yapılmamış."));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ders Programı',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      backgroundColor: Colors.blue[50],
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: fetchLessonsForParent(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'Gelecek ders bulunamadı.',
                style: TextStyle(
                  color: Colors.blue[800],
                  fontSize: 16,
                ),
              ),
            );
          }

          final lessons = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              final data = lesson.data() as Map<String, dynamic>;

              final date = (data['date'] as Timestamp).toDate();
              final formattedDate = DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(date);
              final formattedTime = data['time'] ?? 'Saat bilgisi yok';
              final branch = data['branch'] ?? 'Ders Başlığı Yok';
              final teacherName = data['teacherName'] ?? 'Eğitmen Bilinmiyor';
              final studentName = data['studentName'] ?? 'Öğrenci Bilinmiyor';

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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.music_note,
                            color: Colors.blue[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$branch - $studentName',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Eğitmen: $teacherName',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.blue[600]),
                                  const SizedBox(width: 8),
                                  Text(formattedDate, style: TextStyle(color: Colors.blue[800])),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.blue[600]),
                                  const SizedBox(width: 8),
                                  Text(formattedTime, style: TextStyle(color: Colors.blue[800])),
                                ],
                              ),
                            ],
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