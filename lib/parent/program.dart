import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class _LessonDisplayData {
  final QueryDocumentSnapshot doc;
  final DateTime nextDate;

  _LessonDisplayData({required this.doc, required this.nextDate});
}

class ParentProgramScreen extends StatelessWidget {
  const ParentProgramScreen({Key? key}) : super(key: key);

  DateTime _nextRecurringDate(DateTime startDate, DateTime fromDate) {
    int startWeekday = startDate.weekday;
    int fromWeekday = fromDate.weekday;

    int daysDifference = (startWeekday - fromWeekday) % 7;
    DateTime nextDate = fromDate.add(Duration(days: daysDifference));

    if (_isSameDate(nextDate, fromDate) && fromDate.isAfter(startDate)) {
      nextDate = nextDate.add(Duration(days: 7));
    }

    return DateTime(
      nextDate.year,
      nextDate.month,
      nextDate.day,
      startDate.hour,
      startDate.minute,
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<List<_LessonDisplayData>> fetchLessonsForParent(String parentId) async {
    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();

    // Bireysel dersleri çek
    final individualLessons = await firestore
        .collection('lessons')
        .where('studentId', isEqualTo: parentId)
        .get();

    // Grup derslerini çek
    final groupLessons = await firestore
        .collection('lessons')
        .where('isGroupLesson', isEqualTo: true)
        .where('studentIds', arrayContains: parentId)
        .get();

    List<QueryDocumentSnapshot> allDocs = [...individualLessons.docs, ...groupLessons.docs];

    // Yinelenen dersleri filtreleme
    // Aynı 'id'ye sahip dersleri tekilleştirme
    final uniqueDocs = allDocs.fold<Map<String, QueryDocumentSnapshot>>({}, (map, doc) {
      map[doc.id] = doc;
      return map;
    }).values.toList();


    List<_LessonDisplayData> lessonDisplayList = [];

    for (var lessonDoc in uniqueDocs) {
      final data = lessonDoc.data() as Map<String, dynamic>;

      final Timestamp? timestamp = data['date'];
      if (timestamp == null) continue;

      final lessonDate = timestamp.toDate();
      final bool recurring = data['recurring'] ?? false;

      DateTime nextLessonDate;

      if (recurring) {
        nextLessonDate = _nextRecurringDate(lessonDate, now);
      } else {
        nextLessonDate = lessonDate;
      }

      if (nextLessonDate.isAfter(now) || _isSameDate(nextLessonDate, now)) {
        lessonDisplayList.add(_LessonDisplayData(doc: lessonDoc, nextDate: nextLessonDate));
      }
    }

    lessonDisplayList.sort((a, b) => a.nextDate.compareTo(b.nextDate));

    return lessonDisplayList;
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
      body: FutureBuilder<List<_LessonDisplayData>>(
        future: fetchLessonsForParent(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text("Bir hata oluştu: ${snapshot.error}"));
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
              final lessonData = lessons[index];
              final lesson = lessonData.doc;
              final data = lesson.data() as Map<String, dynamic>;

              final date = lessonData.nextDate;
              final formattedDate = DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(date);
              final formattedTime = data['time'] ?? 'Saat bilgisi yok';
              final branch = data['branch'] ?? 'Ders Başlığı Yok';
              final teacherName = data['teacherName'] ?? 'Eğitmen Bilinmiyor';

              // Grup dersi kontrolü
              final isGroupLesson = data['isGroupLesson'] ?? false;
              String studentInfo;
              if (isGroupLesson) {
                final List<String> studentNames = List.from(data['studentNames'] ?? []);
                studentInfo = studentNames.join(', ');
              } else {
                studentInfo = data['studentName'] ?? 'Öğrenci Bilinmiyor';
              }

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
                            isGroupLesson ? Icons.groups : Icons.person,
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
                                '$branch - $studentInfo',
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