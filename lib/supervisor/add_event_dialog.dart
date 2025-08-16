import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddEventDialog extends StatefulWidget {
  final List<DateTime> weekDays;
  final Function(DateTime, Map<String, dynamic>) onSave;

  const AddEventDialog({
    super.key,
    required this.weekDays,
    required this.onSave,
  });

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  String? selectedTeacherId;
  String? selectedTime;
  String? selectedStudentId;
  String? selectedStudentName;
  DateTime? selectedDay;
  List<Map<String, dynamic>> filteredStudents = [];

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final timeSlots =
        List.generate(48, (i) {
          final hour = 0 + (i ~/ 2);
          final minute = (i % 2) * 30;
          final formatted =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          return {'label': formatted, 'hour': hour, 'minute': minute};
        }).toList();

    return AlertDialog(
      title: const Text("Yeni Ders Ekle"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            DropdownButtonFormField<DateTime>(
              decoration: const InputDecoration(labelText: 'Gün Seç'),
              items:
                  widget.weekDays.map((day) {
                    return DropdownMenuItem(
                      value: day,
                      child: Text(DateFormat('EEEE', 'tr_TR').format(day)),
                    );
                  }).toList(),
              onChanged: (val) => selectedDay = val,
            ),
            const SizedBox(height: 10),
            FutureBuilder<QuerySnapshot>(
              future:
                  firestore
                      .collection('users')
                      .where('role', isEqualTo: 'teacher')
                      .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final teachers = snapshot.data!.docs;

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Eğitmen Seç'),
                  items:
                      teachers.map((doc) {
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(doc['name']),
                        );
                      }).toList(),
                  onChanged: (val) async {
                    selectedTeacherId = val;
                    final selectedDoc = teachers.firstWhere((t) => t.id == val);
                    final List<String> teacherBranches =
                    List<String>.from(selectedDoc['branches'] ?? []);

                    final parentSnapshot =
                        await firestore
                            .collection('users')
                            .where('role', isEqualTo: 'parent')
                            .get();

                    List<Map<String, dynamic>> matchingStudents = [];

                    for (var doc in parentSnapshot.docs) {
                      final parent = doc.data();
                      final parentId = doc.id;
                      final students = List<Map<String, dynamic>>.from(
                        parent['students'] ?? [],
                      );

                      for (var student in students) {
                        final studentBranches = List<String>.from(
                          student['branches'] ?? [],
                        );
                        if (teacherBranches.any((branch) => studentBranches.contains(branch))) {
                          matchingStudents.add({
                            'parentId': parentId,
                            'name': student['name'],
                          });
                        }
                      }
                    }

                    setState(() {
                      filteredStudents = matchingStudents;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Saat Seç'),
              items:
                  timeSlots.map((slot) {
                    return DropdownMenuItem<String>(
                      value: slot['label'] as String,
                      child: Text(slot['label'] as String),
                    );
                  }).toList(),
              onChanged: (val) => selectedTime = val,
            ),
            const SizedBox(height: 10),
            if (filteredStudents.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Öğrenci Seç'),
                items: filteredStudents.map((student) {
                  final uniqueValue = "${student['parentId']}_${student['name']}";
                  return DropdownMenuItem<String>(
                    value: uniqueValue,
                    child: Text(student['name']),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    final selected = filteredStudents.firstWhere(
                          (s) => "${s['parentId']}_${s['name']}" == val,
                    );
                    selectedStudentId = selected['parentId'];
                    selectedStudentName = selected['name'];
                  });
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (selectedTeacherId != null &&
                selectedTime != null &&
                selectedStudentId != null &&
                selectedDay != null) {
              final teacherDoc =
                  await firestore
                      .collection('users')
                      .doc(selectedTeacherId)
                      .get();
              final teacherName = teacherDoc['name'];

              final List<dynamic> branches = teacherDoc['branches'] ?? [];
              final branch = branches.isNotEmpty ? branches[0] : null;

              if (branch == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Eğitmenin tanımlı bir branşı yok'),
                  ),
                );
                return;
              }

              final newDocRef = firestore.collection('lessons').doc();
              final event = {
                'id': newDocRef.id,
                'date': Timestamp.fromDate(selectedDay!),
                'time': selectedTime,
                'teacherId': selectedTeacherId,
                'teacherName': teacherName,
                'branch': branch,
                'studentId': selectedStudentId,
                'studentName': selectedStudentName,
                'recurring': true,
                'isMakeup': false,
              };

              await newDocRef.set(event);
              widget.onSave(selectedDay!, event);
              Navigator.pop(context);
            }
          },

          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
