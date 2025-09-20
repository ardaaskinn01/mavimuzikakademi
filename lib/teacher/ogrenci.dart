import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../chat_screen.dart';

class StudentListScreen extends StatefulWidget {
  @override
  _StudentListScreenState createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final currentTeacherId = FirebaseAuth.instance.currentUser?.uid;
  String? selectedStudentId;
  List<Map<String, dynamic>> allStudents = [];
  List<Map<String, dynamic>> studentAbsences = [];
  bool isLoadingStudents = true;
  bool isLoadingAbsences = false;

  @override
  void initState() {
    super.initState();
    loadAllStudents();
  }

  Future<void> loadAllStudents() async {
    setState(() {
      isLoadingStudents = true;
    });

    final parentsQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .get();

    final lessonsQuery = await FirebaseFirestore.instance
        .collection('lessons')
        .where('teacherId', isEqualTo: currentTeacherId)
        .get();

    final studentsMap = <String, Map<String, dynamic>>{};
    for (var parent in parentsQuery.docs) {
      final parentData = parent.data();
      final parentId = parent.id;
      final studentList = List<Map<String, dynamic>>.from(parentData['students'] ?? []);

      for (var student in studentList) {
        studentsMap[student['name']] = {
          ...student,
          'parentId': parentId,
          'parentName': parentData['name'],
        };
      }
    }

    final enrolledStudents = <Map<String, dynamic>>[];
    for (var lesson in lessonsQuery.docs) {
      final studentName = lesson.data()['studentName'];
      if (studentsMap.containsKey(studentName)) {
        final student = studentsMap[studentName]!;
        if (!enrolledStudents.any((s) => s['name'] == student['name'])) {
          enrolledStudents.add(student);
        }
      }
    }

    setState(() {
      allStudents = enrolledStudents;
      isLoadingStudents = false;
      if (allStudents.isNotEmpty) {
        selectedStudentId = allStudents.first['name'];
        loadStudentAbsences(allStudents.first['parentId']);
      }
    });
  }

  Future<void> loadStudentAbsences(String studentId) async {
    setState(() {
      isLoadingAbsences = true;
      studentAbsences = [];
    });

    final lessonQuery = await FirebaseFirestore.instance
        .collection('lessons')
        .where('teacherId', isEqualTo: currentTeacherId)
        .get();

    List<Map<String, dynamic>> absences = [];

    for (var lesson in lessonQuery.docs) {
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(lesson.id)
          .collection('attendances')
          .doc(studentId)
          .get();

      if (attendanceDoc.exists) {
        final data = attendanceDoc.data()!;
        absences.add({
          'date': (data['timestamp'] as Timestamp).toDate(),
          'status': data['status'] ?? 'bilinmiyor',
          'lessonBranch': lesson.data()['branch'] ?? 'Branş yok',
        });
      }
    }

    setState(() {
      studentAbsences = absences;
      isLoadingAbsences = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text('Öğrenci Listesi',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        elevation: 10,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          if (isLoadingStudents)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: LinearProgressIndicator(),
            ),
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
                      });

                      final selectedStudent = allStudents.firstWhere(
                              (s) => s['name'] == newValue);
                      loadStudentAbsences(selectedStudent['parentId']);
                    }
                  },
                ),
              ),
            ),
          Expanded(
            child: isLoadingStudents
                ? const Center(child: CircularProgressIndicator())
                : allStudents.isEmpty
                ? const Center(child: Text('Kayıtlı öğrenci bulunamadı.'))
                : Column(
              children: [
                if (isLoadingAbsences)
                  const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
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
                      if (isLoadingAbsences)
                        const Center(
                            child: CircularProgressIndicator()),
                      if (!isLoadingAbsences &&
                          studentAbsences.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("Devamsızlık bilgisi bulunamadı."),
                        ),
                      if (!isLoadingAbsences)
                        ...studentAbsences.map((entry) {
                          final formattedDate = DateFormat(
                              'dd MMMM yyyy', 'tr_TR')
                              .format(entry['date']);
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              dense: true,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: getStatusColor(entry['status'])
                                      .withOpacity(0.2),
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
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Durum: ${getStatusText(entry['status'])}",
                                    style: TextStyle(
                                        color: Colors.blue[700]),
                                  ),
                                  Text(
                                    "Ders: ${entry['lessonBranch']}",
                                    style: TextStyle(
                                        color: Colors.blue[600]),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.chat,
                                    color: Colors.blue[700]),
                                onPressed: () {
                                  final selectedStudent = allStudents
                                      .firstWhere((s) =>
                                  s['name'] == selectedStudentId);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                          receiverId:
                                          selectedStudent['parentId']),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
              ],
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