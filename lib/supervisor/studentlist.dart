import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../dersprogrami.dart';
import '../devamsizliklar.dart';

class SupervisorStudentListScreen extends StatefulWidget {
  const SupervisorStudentListScreen({super.key});

  @override
  State<SupervisorStudentListScreen> createState() => _SupervisorStudentListScreenState();
}

class _SupervisorStudentListScreenState extends State<SupervisorStudentListScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  String? userRole;
  String? selectedStudentId;
  List<Map<String, dynamic>> allStudents = [];
  List<Map<String, dynamic>> studentAbsences = [];

  @override
  void initState() {
    super.initState();
    getUserRole();
    loadAllStudents();
  }

  Future<void> getUserRole() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    setState(() {
      userRole = doc['role'];
    });
  }

  Future<void> loadAllStudents() async {
    final parentsQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .get();

    final List<Map<String, dynamic>> students = [];
    for (var parent in parentsQuery.docs) {
      final parentData = parent.data();
      final parentId = parent.id;
      final parentName = parentData['name'];
      final studentList = List<Map<String, dynamic>>.from(parentData['students'] ?? []);

      for (var student in studentList) {
        students.add({
          ...student,
          'parentName': parentName,
          'parentId': parentId,
        });
      }
    }
    setState(() {
      allStudents = students;
      if (allStudents.isNotEmpty) {
        selectedStudentId = allStudents.first['name'];
        loadStudentAbsences(selectedStudentId!);
      }
    });
  }

  Future<void> loadStudentAbsences(String studentName) async {
    // Bireysel dersler için sorgu
    final individualLessonsQuery = await FirebaseFirestore.instance
        .collection('lessons')
        .where('studentName', isEqualTo: studentName)
        .get();

    // Grup dersleri için sorgu - studentNames array'inde öğrenci adını içeren dersler
    final groupLessonsQuery = await FirebaseFirestore.instance
        .collection('lessons')
        .where('studentNames', arrayContains: studentName)
        .get();

    List<Map<String, dynamic>> absences = [];

    // Bireysel dersleri işle
    for (var lesson in individualLessonsQuery.docs) {
      await processLessonAttendance(lesson, studentName, absences);
    }

    // Grup derslerini işle
    for (var lesson in groupLessonsQuery.docs) {
      await processLessonAttendance(lesson, studentName, absences);
    }

    setState(() {
      studentAbsences = absences;
    });
  }

  Future<void> processLessonAttendance(
      QueryDocumentSnapshot<Map<String, dynamic>> lesson,
      String studentName,
      List<Map<String, dynamic>> absences) async {
    final lessonData = lesson.data();
    final bool isGroupLesson = lessonData['isGroupLesson'] ?? false;
    final String studentId;

    // Öğrenci ID'sini bul
    if (isGroupLesson) {
      final List<String> studentNames = List<String>.from(lessonData['studentNames'] ?? []);
      final List<String> studentIds = List<String>.from(lessonData['studentIds'] ?? []);

      final int index = studentNames.indexOf(studentName);
      if (index != -1 && index < studentIds.length) {
        studentId = studentIds[index];
      } else {
        final student = allStudents.firstWhere(
              (s) => s['name'] == studentName,
          orElse: () => {'parentId': 'unknown'},
        );
        studentId = student['parentId'];
      }
    } else {
      studentId = lessonData['studentId'] ??
          allStudents.firstWhere(
                (s) => s['name'] == studentName,
            orElse: () => {'parentId': 'unknown'},
          )['parentId'];
    }

    // Devamsızlık bilgisini almak için attendances alt koleksiyonunda parametre arıyoruz
    final attendanceQuery = await FirebaseFirestore.instance
        .collection('lessons')
        .doc(lesson.id)
        .collection('attendances')
        .where('studentId', isEqualTo: studentId)
        .get();

    for (var attendanceDoc in attendanceQuery.docs) {
      final data = attendanceDoc.data();
      absences.add({
        'date': (data['timestamp'] as Timestamp).toDate(),
        'status': data['status'] ?? 'bilinmiyor',
        'lessonBranch': lessonData['branch'] ?? 'Branş yok',
        'teacherId': lessonData['teacherId'],
        'teacherName': lessonData['teacherName'],
        'studentId': studentId,
        'isGroupLesson': isGroupLesson,
        'lessonType': isGroupLesson ? 'Grup Dersi' : 'Bireysel Ders',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text(
          'Tüm Öğrenciler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        elevation: 10,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: userRole == 'supervisor'
            ? [
          IconButton(
            icon: const Icon(Icons.group, color: Colors.white),
            tooltip: 'Öğrenciler',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DevamsizliklarScreen()),
              );
            },
          )
        ]
            : null,
      ),
      body: Column(
        children: [
          if (allStudents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: DropdownButton<String>(
                  value: selectedStudentId,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: allStudents.map((student) {
                    return DropdownMenuItem<String>(
                      value: student['name'],
                      child: Text(
                        "${student['name']} - Veli: ${student['parentName']}",
                        style: TextStyle(color: Colors.blue[900]),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedStudentId = newValue;
                        studentAbsences = [];
                      });
                      loadStudentAbsences(newValue);
                    }
                  },
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<void>(
              future: allStudents.isNotEmpty ? Future.value() : loadAllStudents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (allStudents.isEmpty) {
                  return const Center(child: Text('Kayıtlı öğrenci bulunamadı.'));
                }

                return ListView(
                  children: [
                    if (selectedStudentId != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "$selectedStudentId Devamsızlıkları",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    if (studentAbsences.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text("Devamsızlık bilgisi bulunamadı."),
                      ),
                    ...studentAbsences.map((entry) {
                      final formattedDate = DateFormat('dd MMMM yyyy', 'tr_TR').format(entry['date']);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: getStatusColor(entry['status']).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              getStatusIcon(entry['status']),
                              color: getStatusColor(entry['status']),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            formattedDate,
                            style: TextStyle(
                                color: Colors.blue[900],
                                fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Durum: ${getStatusText(entry['status'])}",
                                style: TextStyle(color: Colors.blue[700]),
                              ),
                              Text(
                                "Ders: ${entry['lessonBranch']}",
                                style: TextStyle(color: Colors.blue[600]),
                              ),
                              Text(
                                "Tip: ${entry['lessonType']}",
                                style: TextStyle(color: Colors.blue[500]),
                              ),
                            ],
                          ),
                          trailing: entry['status'] != 'var'
                              ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[50],
                              foregroundColor: Colors.orange[800],
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AddMakeupEventDialog(
                                  onSave: (date, event) { /*...*/ },
                                  initialTeacherId: entry['teacherId'],
                                  initialTeacherName: entry['teacherName'],
                                  initialStudentId: entry['studentId'],
                                  initialStudentName: selectedStudentId!,
                                ),
                              );
                            },
                            child: const Text('Telafi Oluştur'),
                          )
                              : null,
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper functions
  Color getStatusColor(String status) {
    switch (status) {
      case 'var':
        return Colors.green;
      case 'izinli':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'var':
        return Icons.check_circle;
      case 'izinli':
        return Icons.event_available;
      default:
        return Icons.cancel;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'var':
        return 'Katıldı';
      case 'izinli':
        return 'İzinli';
      default:
        return 'Katılmadı';
    }
  }
}