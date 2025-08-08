import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:intl/intl.dart';

class BildirimScreen extends StatefulWidget {
  const BildirimScreen({super.key});

  @override
  State<BildirimScreen> createState() => _BildirimScreenState();
}

class _BildirimScreenState extends State<BildirimScreen> {
  List<Map<String, dynamic>> lessons = [];
  bool isLoading = true;
  final onesignalAppId = "391d3144-b237-4ef9-8a21-35cd09dee163";
  final onesignalRestApiKey = "os_v2_app_heotcrfsg5hptcrbgxgqtxxbmnwgq6djkl4u5cushs2nsmrozlb4u4glja7lvjrsvr4fgovqod5bpxaeajzppyqixgykzjtpbbsdvny";

  @override
  void initState() {
    super.initState();
    loadLessons(); // Veriyi yükle ve setState ile durumu güncelle
  }

  Future<void> loadLessons() async {
    final data = await fetchLessonsLast24Hours();
    setState(() {
      lessons = data;
      isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> fetchLessonsLast24Hours() async {
    final now = DateTime.now();
    final next24Hours = now.add(const Duration(hours: 24));

    final snapshot = await FirebaseFirestore.instance.collection('lessons').get();

    List<Map<String, dynamic>> filteredLessons = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();

      DateTime date = (data['date'] as Timestamp).toDate();
      String timeStr = data['time'] ?? "00:00";

      DateTime lessonDateTime;

      try {
        if (timeStr.toLowerCase().contains("am") || timeStr.toLowerCase().contains("pm")) {
          lessonDateTime = DateFormat.jm('en_US').parse(timeStr);
        } else {
          lessonDateTime = DateFormat("HH:mm").parse(timeStr);
        }
      } catch (e) {
        lessonDateTime = DateFormat("HH:mm").parse("00:00");
      }

      final combinedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        lessonDateTime.hour,
        lessonDateTime.minute,
      );

      // 🔽 24 saat filtresi burada
      if (combinedDateTime.isAfter(now) && combinedDateTime.isBefore(next24Hours)) {
        filteredLessons.add({
          'id': doc.id,
          'teacherId': data['teacherId'],
          'date': date,
          'time': timeStr,
          'notified': data['notified'] ?? false,
          'teacherName': data['teacherName'],
          'branch': data['branch'],
          'studentName': data['studentName'], // 👈 parent aramak için
        });
      }
    }

    return filteredLessons;
  }

  Future<void> sendPushNotification(String teacherId, String lessonId) async {
    final lessonDoc = await FirebaseFirestore.instance
        .collection('lessons')
        .doc(lessonId)
        .get();

    final lessonData = lessonDoc.data();
    if (lessonData == null) return;

    final teacherName = lessonData['teacherName'] ?? 'Bilinmeyen';
    final branch = lessonData['branch'] ?? 'Branş';
    final studentName = lessonData['studentName'] ?? '';
    final date = (lessonData['date'] as Timestamp?)?.toDate();
    final time = lessonData['time'] ?? 'Saat bilgisi yok';

    final message = "Yarın dersiniz var :)";

    // 1. Öğretmenin playerId'sini al
    final teacherDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(teacherId)
        .get();

    final teacherData = teacherDoc.data();
    final teacherPlayerId = teacherData?['playerId'];

    // 2. Öğrenci adına göre veli bul
    String? parentPlayerId;
    String? parentId;

    final parentsQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .get();

    for (var parentDoc in parentsQuery.docs) {
      final parentData = parentDoc.data();
      final students = parentData['students'] ?? [];

      for (var student in students) {
        if ((student['name'] as String?)?.toLowerCase() == studentName.toLowerCase()) {
          parentPlayerId = parentData['playerId'];
          parentId = parentDoc.id;
          break;
        }
      }

      if (parentPlayerId != null) break; // Eşleşen ilk veliyi al
    }

    // 4. Firestore'a bildirimi yaz
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': 'Ders Hatırlatması',
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'lessonId': lessonId,
      'branch': branch,
      'teacherName': teacherName,
      'type': 'lesson_reminder',
      'seenBy': [],
      'teacherId': teacherId,
      'parentId': parentId,
    });

    // 5. notified: true yap
    await FirebaseFirestore.instance
        .collection('lessons')
        .doc(lessonId)
        .update({'notified': true});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bildirim başarıyla gönderildi')),
    );

    loadLessons();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bildirim Gönder",
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
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
        ),
      )
          : lessons.isEmpty
          ? Center(
        child: Text(
          "Son 24 saat içinde ders bulunamadı",
          style: TextStyle(
            color: Colors.blue[800],
            fontSize: 16,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        itemCount: lessons.length,
        itemBuilder: (context, index) {
          final lesson = lessons[index];
          final dateFormatted = lesson['date'] != null
              ? DateFormat('dd MMMM yyyy', 'tr_TR').format(lesson['date'])
              : 'Tarih belirtilmemiş';

          final timeFormatted = lesson['time'] ?? ''; // eğer time null ise boş bırak

          final dateTimeText = timeFormatted.isNotEmpty
              ? '$dateFormatted - $timeFormatted'
              : dateFormatted;


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
                        Icons.school,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ders ${lesson['branch']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Eğitmen: ${lesson['teacherName']}',
                            style: TextStyle(
                              color: Colors.blue[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateTimeText,
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    lesson['notified']
                        ? Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green[700],
                        size: 28,
                      ),
                    )
                        : Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: () {
                          sendPushNotification(
                            lesson['teacherId'],
                            lesson['id'],
                          );
                        },
                        child: const Text(
                          'Bildirim Gönder',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}