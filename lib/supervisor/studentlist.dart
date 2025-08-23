import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../dersprogrami.dart';
import '../devamsizliklar.dart';

// Assuming AddMakeupEventDialog is defined elsewhere
// and used in the same way.

class SupervisorStudentListScreen extends StatefulWidget {
  const SupervisorStudentListScreen({super.key});

  @override
  State<SupervisorStudentListScreen> createState() => _SupervisorStudentListScreenState();
}

class _SupervisorStudentListScreenState extends State<SupervisorStudentListScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  String? userRole;
  String? selectedStudentId; // Will store the selected student's name for simplicity
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
    final lessonsQuery = await FirebaseFirestore.instance
        .collection('lessons')
        .where('studentName', isEqualTo: studentName)
        .get();

    List<Map<String, dynamic>> absences = [];

    for (var lesson in lessonsQuery.docs) {
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(lesson.id)
          .collection('attendances')
          .doc(lesson['studentId'])
          .get();

      if (attendanceDoc.exists) {
        final data = attendanceDoc.data()!;
        absences.add({
          'date': (data['timestamp'] as Timestamp).toDate(),
          'status': data['status'] ?? 'bilinmiyor',
          'lessonBranch': lesson['branch'] ?? 'Branş yok',
          'teacherId': lesson['teacherId'],
          'teacherName': lesson['teacherName'],
          'studentId': lesson['studentId'] ?? allStudents.firstWhere((s) => s['name'] == studentName)['parentId'],
        });
      }
    }

    setState(() {
      studentAbsences = absences;
    });
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
                        studentAbsences = []; // Clear absences while loading
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
                if (allStudents.isEmpty) {
                  return const Center(child: Text('Kayıtlı öğrenci bulunamadı.'));
                }

                if (studentAbsences.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("Devamsızlık bilgisi bulunamadı."),
                  );

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