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
  final Map<String, bool> expandedMap = {};
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

  Future<List<Map<String, dynamic>>> getStudentAbsences(String studentName) async {
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
          .doc(lesson['studentId']) // öğrenci ID'si burada tutuluyor
          .get();

      if (attendanceDoc.exists) {
        final data = attendanceDoc.data()!;
        absences.add({
          'date': (data['timestamp'] as Timestamp).toDate(),
          'status': data['status'] ?? 'bilinmiyor',
          'lessonBranch': lesson['branch'] ?? 'Branş yok',
        });
      }
    }

    return absences;
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'parent')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Veli bulunamadı.'));
          }

          final parents = snapshot.data!.docs;

          // Tüm öğrencileri topla
          final List<Map<String, dynamic>> allStudents = [];
          for (var parent in parents) {
            final parentData = parent.data() as Map<String, dynamic>;
            final parentId = parent.id;
            final parentName = parentData['name'];
            final students = List<Map<String, dynamic>>.from(parentData['students'] ?? []);

            for (var student in students) {
              allStudents.add({
                ...student,
                'parentName': parentName,
                'parentId': parentId,
              });
            }
          }

          if (allStudents.isEmpty) {
            return const Center(child: Text('Kayıtlı öğrenci bulunamadı.'));
          }

          return ListView.builder(
            itemCount: allStudents.length,
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemBuilder: (context, index) {
              final student = allStudents[index];
              final studentName = student['name'];
              final parentId = student['parentId'];
              final isExpanded = expandedMap[studentName] ?? false;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          title: Text(
                            studentName,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Colors.blue[900]),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Veli: ${student['parentName']}",
                                  style: TextStyle(color: Colors.blue[700])),
                              Text(
                                "Branş: ${student['branches']?.join(', ') ?? 'Branş yok'}",
                                style: TextStyle(color: Colors.blue[600]),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.blue[700],
                                  size: 28,
                                ),
                                onPressed: () {
                                  setState(() {
                                    expandedMap[studentName] = !isExpanded;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isExpanded)
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: getStudentAbsences(studentName),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(8),
                                child: LinearProgressIndicator(),
                              );
                            }

                            final absences = snapshot.data ?? [];

                            if (absences.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text("Devamsızlık bilgisi bulunamadı."),
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                children: absences.map((entry) {
                                  final formattedDate = DateFormat(
                                      'dd MMMM yyyy', 'tr_TR')
                                      .format(entry['date']);
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
                                        onPressed: () async {
                                          // Get teacher info for this lesson
                                          final lessonQuery = await FirebaseFirestore.instance
                                              .collection('lessons')
                                              .where('studentName', isEqualTo: studentName)
                                              .where('branch', isEqualTo: entry['lessonBranch'])
                                              .limit(1)
                                              .get();

                                          if (lessonQuery.docs.isNotEmpty) {
                                            final lessonData = lessonQuery.docs.first.data();
                                            final teacherId = lessonData['teacherId'];
                                            final teacherName = lessonData['teacherName'];

                                            showDialog(
                                              context: context,
                                              builder: (context) => AddMakeupEventDialog(
                                                onSave: (date, event) {
                                                  // Optional: You can add any post-save logic here
                                                },
                                                initialTeacherId: teacherId,
                                                initialTeacherName: teacherName,
                                                initialStudentId: student['parentId'], // parentId is used as studentId in your structure
                                                initialStudentName: studentName,
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text('Telafi Oluştur'),
                                      )
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Yardımcı fonksiyonlar
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
