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
  bool isLoadingStudents = false;
  String? selectedBranch;
  List<String> availableBranches = [];
  List<DocumentSnapshot> teachers = [];

  // Yeni eklendi: Grup dersi için
  bool isGroupLesson = false;
  List<Map<String, dynamic>> selectedStudents = [];
  List<String> selectedStudentNames = [];

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final timeSlots = List.generate(
      48,
          (i) {
        final hour = 0 + (i ~/ 2);
        final minute = (i % 2) * 30;
        final formatted =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        return {'label': formatted, 'hour': hour, 'minute': minute};
      },
    ).toList();

    return AlertDialog(
      title: const Text("Yeni Ders Ekle"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<QuerySnapshot>(
              future: firestore.collection('users').where('role', isEqualTo: 'teacher').get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('Eğitmen bulunamadı.');
                }
                final teacherDocs = snapshot.data!.docs;
                teachers = teacherDocs;
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Eğitmen Seç'),
                  value: selectedTeacherId,
                  items: teachers.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    setState(() {
                      selectedTeacherId = val;
                      selectedDay = null;
                      selectedTime = null;
                      selectedStudentId = null;
                      selectedStudentName = null;
                      filteredStudents = [];
                      isLoadingStudents = true;
                      selectedStudents = [];
                      selectedStudentNames = [];
                    });

                    final selectedDoc = teachers.firstWhere((t) => t.id == val);
                    final List<String> teacherBranches = List<String>.from(selectedDoc['branches'] ?? []);
                    final parentSnapshot = await firestore.collection('users').where('role', isEqualTo: 'parent').get();

                    List<Map<String, dynamic>> matchingStudents = [];
                    for (var doc in parentSnapshot.docs) {
                      final students = List<Map<String, dynamic>>.from(doc['students'] ?? []);
                      for (var student in students) {
                        final studentBranches = List<String>.from(student['branches'] ?? []);
                        // Eğitmen ve öğrenci branşlarının en az birinin eşleşmesi gerekiyor
                        if (teacherBranches.any((branch) => studentBranches.contains(branch))) {
                          matchingStudents.add({
                            'parentId': doc.id,
                            'name': student['name'],
                            'branches': student['branches'],
                          });
                        }
                      }
                    }

                    setState(() {
                      filteredStudents = matchingStudents;
                      isLoadingStudents = false;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<DateTime>(
              decoration: InputDecoration(
                labelText: 'Gün Seç',
                enabled: selectedTeacherId != null,
              ),
              value: selectedDay,
              items: widget.weekDays.map((day) {
                return DropdownMenuItem(
                  value: day,
                  child: Text(DateFormat('EEEE', 'tr_TR').format(day)),
                );
              }).toList(),
              onChanged: selectedTeacherId != null ? (val) {
                setState(() {
                  selectedDay = val;
                  selectedTime = null;
                });
              } : null,
            ),
            const SizedBox(height: 10),
            FutureBuilder<QuerySnapshot>(
              future: (selectedTeacherId != null && selectedDay != null)
                  ? firestore.collection('lessons').where('teacherId', isEqualTo: selectedTeacherId).get()
                  : null,
              builder: (context, snapshot) {
                if (selectedTeacherId == null || selectedDay == null) {
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Saat Seç'),
                    items: const [],
                    onChanged: null,
                    hint: const Text('Önce gün ve eğitmen seçin'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final lessons = snapshot.data?.docs ?? [];
                // Grup dersi ise dolu saatler de seçilebilsin
                final reservedTimes = isGroupLesson
                    ? <String>{}
                    : lessons
                    .where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lessonDate = (data['date'] as Timestamp).toDate();
                  return lessonDate.weekday == selectedDay!.weekday;
                })
                    .map((doc) => (doc['time'] as String))
                    .toSet();

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Saat Seç'),
                  value: selectedTime,
                  items: timeSlots.map((slot) {
                    final timeLabel = slot['label'] as String;
                    final isReserved = reservedTimes.contains(timeLabel);
                    return DropdownMenuItem<String>(
                      value: isReserved ? null : timeLabel,
                      enabled: !isReserved,
                      child: Text(
                        timeLabel,
                        style: TextStyle(
                          color: isReserved ? Colors.grey : Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => selectedTime = val);
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            // Grup dersi seçimi için Checkbox
            Row(
              children: [
                Checkbox(
                  value: isGroupLesson,
                  onChanged: (bool? value) {
                    setState(() {
                      isGroupLesson = value!;
                      // Grup dersi seçimi değişince öğrenci seçimini sıfırla
                      selectedStudents = [];
                      selectedStudentNames = [];
                      selectedStudentId = null;
                      selectedStudentName = null;
                    });
                  },
                ),
                const Text("Grup Dersi"),
              ],
            ),
            const SizedBox(height: 10),
            if (isLoadingStudents)
              const Center(child: CircularProgressIndicator())
            else if (isGroupLesson)
            // Grup dersi için öğrenci seçimi
              TextFormField(
                readOnly: true,
                onTap: () async {
                  final result = await _showMultiSelectDialog(
                    context,
                    filteredStudents,
                    selectedStudents,
                  );
                  if (result != null) {
                    setState(() {
                      selectedStudents = result;
                      selectedStudentNames =
                          result.map((s) => s['name'] as String).toList();
                      _updateAvailableBranches();
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: selectedStudentNames.isEmpty
                      ? 'Öğrenci(ler) Seç'
                      : 'Seçilen Öğrenci: ${selectedStudentNames.join(", ")}',
                  border: const OutlineInputBorder(),
                  enabled: selectedTeacherId != null && filteredStudents.isNotEmpty,
                ),
              )
            else
            // Bireysel ders için öğrenci seçimi
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Öğrenci Seç',
                  enabled: selectedTeacherId != null && filteredStudents.isNotEmpty,
                ),
                value: selectedStudentId != null ? "${selectedStudentId}_$selectedStudentName" : null,
                items: filteredStudents.map((student) {
                  final uniqueValue = "${student['parentId']}_${student['name']}";
                  return DropdownMenuItem<String>(
                    value: uniqueValue,
                    child: Text(student['name']),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      final selected = filteredStudents.firstWhere(
                            (s) => "${s['parentId']}_${s['name']}" == val,
                      );
                      selectedStudentId = selected['parentId'];
                      selectedStudentName = selected['name'];

                      // Tekil öğrenci için ortak branşları bul
                      final teacherDoc = teachers.firstWhere((t) => t.id == selectedTeacherId);
                      final teacherBranches = List<String>.from(teacherDoc['branches'] ?? []);
                      final studentBranches = List<String>.from(selected['branches'] ?? []);
                      availableBranches = teacherBranches
                          .where((b) => studentBranches.contains(b))
                          .toList();

                      selectedBranch = null; // yeniden seçtirsin
                    });
                  }
                },
              ),
            const SizedBox(height: 10),
            // Branş seçimi
            if (availableBranches.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Branş Seç'),
                value: selectedBranch,
                items: availableBranches.map((branch) {
                  return DropdownMenuItem(
                    value: branch,
                    child: Text(branch),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => selectedBranch = val);
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
            if (selectedTeacherId != null && selectedTime != null && selectedDay != null &&
                ((isGroupLesson && selectedStudents.isNotEmpty) || (!isGroupLesson && selectedStudentId != null))) {
              final teacherDoc = await firestore.collection('users').doc(selectedTeacherId).get();
              final teacherName = teacherDoc['name'];

              if (selectedBranch == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lütfen bir branş seçin.'),
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
                'branch': selectedBranch,
                'recurring': true,
                'isMakeup': false,
                'isGroupLesson': isGroupLesson,
              };

              if (isGroupLesson) {
                event['studentIds'] = selectedStudents.map((s) => s['parentId']).toList();
                event['studentNames'] = selectedStudents.map((s) => s['name']).toList();
              } else {
                event['studentId'] = selectedStudentId;
                event['studentName'] = selectedStudentName;
              }

              await newDocRef.set(event);
              widget.onSave(selectedDay!, event);
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lütfen tüm alanları doldurun.'),
                ),
              );
            }
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }

  // Ortak branşları bulma fonksiyonu
  void _updateAvailableBranches() {
    if (selectedTeacherId == null || selectedStudents.isEmpty) {
      setState(() {
        availableBranches = [];
        selectedBranch = null;
      });
      return;
    }

    final teacherDoc = teachers.firstWhere((t) => t.id == selectedTeacherId);
    final teacherBranches = List<String>.from(teacherDoc['branches'] ?? []);

    // Seçilen tüm öğrencilerin ortak branşlarını bul
    List<String> commonBranches = List.from(teacherBranches);
    for (var student in selectedStudents) {
      final studentBranches = List<String>.from(student['branches'] ?? []);
      commonBranches = commonBranches.where((b) => studentBranches.contains(b)).toList();
    }

    setState(() {
      availableBranches = commonBranches;
      // Eğer seçili branş artık mevcut değilse sıfırla
      if (selectedBranch != null && !availableBranches.contains(selectedBranch)) {
        selectedBranch = null;
      }
    });
  }

  // Çoklu öğrenci seçimi için pop-up
  Future<List<Map<String, dynamic>>?> _showMultiSelectDialog(
      BuildContext context,
      List<Map<String, dynamic>> students,
      List<Map<String, dynamic>> initialSelected,
      ) async {
    List<Map<String, dynamic>> tempSelected = List.from(initialSelected);

    return showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) { // <-- Pop-up'ın kendi durumunu yöneten setState
            return AlertDialog(
              title: const Text('Öğrenci Seç'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: students.map((student) {
                    final isSelected = tempSelected.any((s) => s['name'] == student['name'] && s['parentId'] == student['parentId']);
                    return CheckboxListTile(
                      title: Text(student['name']),
                      value: isSelected,
                      onChanged: (bool? selected) {
                        setDialogState(() { // <-- pop-up'ın durumunu güncelliyor
                          if (selected != null && selected) {
                            tempSelected.add(student);
                          } else {
                            tempSelected.removeWhere((s) => s['name'] == student['name'] && s['parentId'] == student['parentId']);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, tempSelected),
                  child: const Text('Tamam'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}