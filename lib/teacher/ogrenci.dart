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
  final Map<String, bool> expandedMap = {};

  Future<List<Map<String, dynamic>>> getStudentAbsences(String studentId) async {
    final lessonQuery = await FirebaseFirestore.instance
        .collection('lessons')
        .where('teacherId', isEqualTo: currentTeacherId)
        .get();

    List<Map<String, dynamic>> allAbsences = [];

    for (var lesson in lessonQuery.docs) {
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(lesson.id)
          .collection('attendances')
          .doc(studentId)
          .get();

      if (attendanceDoc.exists) {
        final data = attendanceDoc.data()!;
        allAbsences.add({
          'date': (data['timestamp'] as Timestamp).toDate(),
          'status': data['status'] ?? 'bilinmiyor',
          'lessonBranch': lesson.data()['branch'] ?? 'Branş yok',
        });
      }
    }

    return allAbsences;
  }

  Future<String> getParentName(String parentId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(parentId)
        .get();
    return doc['name'] ?? 'İsimsiz Veli';
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'parent')
            .snapshots(),
        builder: (context, parentSnapshot) {
          if (parentSnapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                strokeWidth: 3,
              ),
            );
          }

          if (!parentSnapshot.hasData || parentSnapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('Veli bulunamadı.',
                  style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 18,
                      fontWeight: FontWeight.w500)),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('lessons')
                .where('teacherId', isEqualTo: currentTeacherId)
                .snapshots(),
            builder: (context, lessonSnapshot) {
              if (lessonSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                  ),
                );
              }

              final parents = parentSnapshot.data!.docs;
              final lessons = lessonSnapshot.data?.docs ?? [];

              // Öğrenci bilgilerini topla
              final studentsMap = <String, Map<String, dynamic>>{};
              for (var parent in parents) {
                final parentData = parent.data() as Map<String, dynamic>;
                final students = List<Map<String, dynamic>>.from(parentData['students'] ?? []);
                for (var student in students) {
                  studentsMap[student['name']] = {
                    ...student,
                    'parentId': parent.id,
                    'parentName': parentData['name'],
                  };
                }
              }

              // Derslerdeki öğrencileri kontrol et
              final enrolledStudents = <String, Map<String, dynamic>>{};
              for (var lesson in lessons) {
                final lessonData = lesson.data() as Map<String, dynamic>;
                final studentName = lessonData['studentName'];
                if (studentsMap.containsKey(studentName)) {
                  enrolledStudents[studentName] = studentsMap[studentName]!;
                }
              }

              if (enrolledStudents.isEmpty) {
                return Center(
                  child: Text('Öğrenci bulunamadı.',
                      style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 18,
                          fontWeight: FontWeight.w500)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: enrolledStudents.length,
                itemBuilder: (context, index) {
                  final studentName = enrolledStudents.keys.elementAt(index);
                  final student = enrolledStudents[studentName]!;
                  final parentId = student['parentId'];
                  final isExpanded = expandedMap[parentId] ?? false;

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
                                  Text(
                                    "Veli: ${student['parentName']}",
                                    style: TextStyle(color: Colors.blue[700]),
                                  ),
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
                                    icon: Icon(Icons.chat, color: Colors.blue[700]),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ChatScreen(receiverId: parentId),
                                        ),
                                      );
                                    },
                                  ),
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
                                        expandedMap[parentId] = !isExpanded;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isExpanded)
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: getStudentAbsences(parentId),
                              builder: (context, absenceSnapshot) {
                                if (absenceSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: LinearProgressIndicator(
                                      backgroundColor: Colors.blue[100],
                                      valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          Colors.blue[700]!),
                                    ),
                                  );
                                }

                                final absences = absenceSnapshot.data ?? [];

                                if (absences.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      "Devamsızlık bilgisi bulunamadı.",
                                      style: TextStyle(color: Colors.blue[800]),
                                    ),
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
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
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
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

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