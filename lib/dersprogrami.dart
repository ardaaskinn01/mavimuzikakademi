import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'supervisor/day_column.dart';
import 'supervisor/add_event_dialog.dart';
import 'supervisor/event_service.dart';


class DersProgramiScreen extends StatefulWidget {
  const DersProgramiScreen({super.key});

  @override
  State<DersProgramiScreen> createState() => _DersProgramiScreenState();
}

class _DersProgramiScreenState extends State<DersProgramiScreen> {
  int pageIndex = 0;
  Map<int, List<Map<String, dynamic>>> events = {};
  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    _loadEventsFromFirebase();
  }

  Future<void> _loadEventsFromFirebase() async {
    List<Map<String, dynamic>> firebaseEvents = await _eventService.getAllEvents();

    setState(() {
      events.clear();
      for (var event in firebaseEvents) {
        DateTime eventDate = (event['date'] as Timestamp).toDate();
        int weekday = eventDate.weekday;
        events.putIfAbsent(weekday, () => []);
        events[weekday]!.add(event);
      }
    });
  }

  List<DateTime> getCurrentWeekDates() {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(firstDayOfWeek.year, firstDayOfWeek.month, firstDayOfWeek.day + pageIndex * 7);
    return List.generate(7, (i) => DateTime(start.year, start.month, start.day + i));
  }

  void addEvent(DateTime day, Map<String, dynamic> event) {
    setState(() {
      final weekday = day.weekday;
      events.putIfAbsent(weekday, () => []);
      events[weekday]!.add(event);
    });
  }

  Future<void> showAddEventDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AddEventDialog(
        weekDays: getCurrentWeekDates(),
        onSave: addEvent,
      ),
    );
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await _eventService.deleteEvent(eventId);
      setState(() {
        events.forEach((key, list) {
          list.removeWhere((event) => event['id'] == eventId);
        });
      });
    } catch (e) {
      print('Silme hatası: $e');
    }
  }

  void cancelSingleLesson(String eventId, DateTime dateToCancel) async {
    try {
      final lessonRef = FirebaseFirestore.instance.collection('lessons').doc(eventId);

      // Belirtilen tarihi 'cancelledDates' dizisine ekle
      await lessonRef.update({
        'cancelledDates': FieldValue.arrayUnion([Timestamp.fromDate(dateToCancel)])
      });

      // Tüm event'leri yeniden yükle
      await _loadEventsFromFirebase();

    } catch (e) {
      print('İptal hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ders iptal edilirken hata oluştu: $e')),
      );
    }
  }

  Future<void> _showAddOptionsDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ders Türü Seçin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 24),

                // Haftalık Ders Butonu
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, 'normal'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Haftalık Ders Ekle',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Telafi Dersi Butonu
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.orange.shade600],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, 'makeup'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.autorenew, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Telafi Dersi Ekle',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'İptal',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == 'normal') {
      await showDialog(
        context: context,
        builder: (context) => AddEventDialog(
          weekDays: getCurrentWeekDates(),
          onSave: addEvent,
        ),
      );
    } else if (choice == 'makeup') {
      await showDialog(
        context: context,
        builder: (context) => AddMakeupEventDialog(
          onSave: (DateTime date, Map<String, dynamic> event) {
            // Telafi derslerini yine events yapısına uygun şekilde ekle
            addEvent(date, event);
          },
        ),
      );
    }
  }

  List<Map<String, dynamic>> getEventsForDay(DateTime day) {
    // 1. O gün için potansiyel dersleri al (Örn: Salı gününe ait tüm dersler)
    final potentialEvents = events[day.weekday] ?? [];

    // 2. O günde gerçekten gösterilecek dersler için boş bir liste oluştur
    final List<Map<String, dynamic>> actualEvents = [];

    // 3. Potansiyel her dersi tek tek kontrol et
    for (final event in potentialEvents) {
      final bool isRecurring = event['recurring'] == true;
      final DateTime startDate = (event['date'] as Timestamp).toDate();

      if (isRecurring) {
        // --- TEKRARLANAN DERSLER İÇİN YENİ MANTIK ---

        // a) Dersin başlama tarihi, baktığımız günden sonra ise gösterme
        if (startDate.isAfter(day)) {
          continue; // Bu dersi atla, çünkü daha başlamamış
        }

        // b) İPTAL KONTROLÜ: Dersin bu hafta için iptal edilip edilmediğini kontrol et
        final List<dynamic> cancelledTimestamps = event['cancelledDates'] ?? [];
        final bool isCancelledForThisDay = cancelledTimestamps.any((timestamp) {
          final cancelledDate = (timestamp as Timestamp).toDate();
          return cancelledDate.year == day.year &&
              cancelledDate.month == day.month &&
              cancelledDate.day == day.day;
        });

        // c) Eğer ders iptal edilmişse, listeye ekleme ve döngüde bir sonrakine geç
        if (isCancelledForThisDay) {
          continue; // Bu dersi atla
        }

        // d) Tüm kontrollerden geçtiyse, dersi o gün için listeye ekle.
        //    ÖNEMLİ: Orijinal dersin bir kopyasını oluşturup tarihini güncelliyoruz.
        //    Böylece dialog, hangi haftayı iptal edeceğini bilir.
        final eventInstance = Map<String, dynamic>.from(event);
        eventInstance['date'] = Timestamp.fromDate(day);
        actualEvents.add(eventInstance);

      } else {
        // --- TEK SEFERLİK DERSLER (Bu mantık zaten doğruydu) ---
        if (startDate.year == day.year &&
            startDate.month == day.month &&
            startDate.day == day.day) {
          actualEvents.add(event);
        }
      }
    }

    // 4. Sadece o gün gösterilmesi gereken dersleri içeren son listeyi döndür
    return actualEvents;
  }

  void _showEventDetailsDialog(
      BuildContext context,
      Map<String, dynamic> event, {
        required Function(String eventId, DateTime dateToCancel) onSingleCancel,
        required Function(String eventId) onPermanentDelete,
      }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... (Ders detaylarının gösterildiği üst kısım aynı kalabilir)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.event, color: Colors.blue.shade700, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Ders Detayları',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow(Icons.access_time, 'Saat', event['time'] ?? 'Bilinmiyor'),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.person, 'Öğrenci', event['studentName'] ?? 'Yok'),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.school, 'Eğitmen', event['teacherName'] ?? 'Yok'),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.category, 'Branş', event['branch'] ?? 'Yok'),
              if (event['isMakeup'] == true) ...[
                const SizedBox(height: 16),
                _buildDetailRow(Icons.autorenew, 'Ders Türü', 'Telafi Dersi'),
              ],
              const SizedBox(height: 32),

              // --- DEĞİŞEN BUTON BÖLÜMÜ ---
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 1. BU HAFTALIK SİL BUTONU
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Dersi İptal Et'),
                          content: const Text('Bu ders sadece bu haftalık iptal edilecektir. Onaylıyor musunuz?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                              child: const Text('Evet, İptal Et'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        // Olayın tarihini al ve tek seferlik iptal fonksiyonunu çağır
                        DateTime eventDate = (event['date'] as Timestamp).toDate();
                        onSingleCancel(event['id'], eventDate);
                        Navigator.pop(context); // Detay dialog'unu kapat
                      }
                    },
                    child: Text('Bu Haftalık Sil', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                  ),

                  // 2. PROGRAMDAN SİL BUTONU
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Programdan Sil'),
                          content: const Text('Bu ders tüm haftalardan kalıcı olarak silinecektir. Emin misiniz?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              child: const Text('Evet, Kalıcı Sil'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        onPermanentDelete(event['id']);
                        Navigator.pop(context); // Detay dialog'unu kapat
                      }
                    },
                    child: Text('Programdan Sil', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.blueGrey.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.blueGrey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = getCurrentWeekDates();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Ders Programı",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            onPressed: () => setState(() => pageIndex--),
          ),
          Text(
            DateFormat('d MMMM', 'tr_TR').format(weekDays.first) +
                ' - ' +
                DateFormat('d MMMM yyyy', 'tr_TR').format(weekDays.last),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            onPressed: () => setState(() => pageIndex++),
          ),
        ],
      ),
      backgroundColor: Colors.blue[50],
      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: weekDays.map((day) {
                final eventsForDay = getEventsForDay(day);
                print('Gün: $day, Ders sayısı: ${eventsForDay.length}');
                return DayRow(
                  day: day,
                  dayEvents: eventsForDay,
                  onEventTap: (event) => _showEventDetailsDialog(
                    context,
                    event,
                    onSingleCancel: cancelSingleLesson,   // 'Bu Haftalık Sil' için bu fonksiyonu veriyoruz.
                    onPermanentDelete: deleteEvent,     // 'Programdan Sil' için bu fonksiyonu veriyoruz.
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptionsDialog,
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class AddMakeupEventDialog extends StatefulWidget {
  final Function(DateTime, Map<String, dynamic>) onSave;
  final String? initialTeacherId;
  final String? initialTeacherName;
  final String? initialStudentId;
  final String? initialStudentName;

  const AddMakeupEventDialog({
    super.key,
    required this.onSave,
    this.initialTeacherId,
    this.initialTeacherName,
    this.initialStudentId,
    this.initialStudentName,
  });

  @override
  State<AddMakeupEventDialog> createState() => _AddMakeupEventDialogState();
}

class _AddMakeupEventDialogState extends State<AddMakeupEventDialog> {
  DateTime? selectedDate;
  String? selectedTeacherId;
  String? selectedTime;
  String? selectedStudentId;
  String? selectedStudentName;
  List<Map<String, dynamic>> filteredStudents = [];

  @override
  void initState() {
    super.initState();
    selectedTeacherId = widget.initialTeacherId;
    selectedStudentId = widget.initialStudentId;
    selectedStudentName = widget.initialStudentName;

    // If initial values are provided, we should load the filtered students
    if (widget.initialTeacherId != null) {
      _loadStudentsForTeacher(widget.initialTeacherId!);
    }
  }

  Future<void> _loadStudentsForTeacher(String teacherId) async {
    final firestore = FirebaseFirestore.instance;
    final teacherDoc = await firestore.collection('users').doc(teacherId).get();
    // Corrected: Retrieve 'branches' as a List<String>
    final List<String> teacherBranches = List<String>.from(teacherDoc['branches'] ?? []);

    final parentSnapshot = await firestore
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .get();

    List<Map<String, dynamic>> matchingStudents = [];

    for (var doc in parentSnapshot.docs) {
      final parent = doc.data();
      final parentId = doc.id;
      final students = List<Map<String, dynamic>>.from(parent['students'] ?? []);

      for (var student in students) {
        final studentBranches = List<String>.from(student['branches'] ?? []);
        // Corrected: Check for intersection of teacher and student branches
        if (teacherBranches.any((branch) => studentBranches.contains(branch))) {
          matchingStudents.add({
            'parentId': parentId, // Changed 'id' to 'parentId' for consistency with AddEventDialog
            'name': student['name'],
          });
        }
      }
    }

    setState(() {
      filteredStudents = matchingStudents;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final timeSlots = List.generate(48, (i) {
      final hour = i ~/ 2;
      final minute = (i % 2) * 30;
      final formatted = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      return {'label': formatted, 'hour': hour, 'minute': minute};
    });

    return AlertDialog(
      title: const Text("Telafi Dersi Ekle"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            // Tarih seçici
            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Tarih Seç',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  locale: const Locale('tr', 'TR'),
                  initialDate: selectedDate ?? now,
                  firstDate: now.subtract(const Duration(days: 365)),
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = picked;
                  });
                }
              },
              controller: TextEditingController(
                text: selectedDate != null ? DateFormat('dd.MM.yyyy').format(selectedDate!) : '',
              ),
            ),

            const SizedBox(height: 10),

            FutureBuilder<QuerySnapshot>(
              future: firestore.collection('users').where('role', isEqualTo: 'teacher').get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final teachers = snapshot.data!.docs;

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
                      // Clear previously filtered students when teacher changes
                      filteredStudents = [];
                      selectedStudentId = null;
                      selectedStudentName = null;
                    });
                    if (val != null) {
                      await _loadStudentsForTeacher(val);
                    }
                  },
                );
              },
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Saat Seç'),
              items: timeSlots.map((slot) {
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
                value: selectedStudentId != null && filteredStudents.any((s) => s['parentId'] == selectedStudentId && s['name'] == selectedStudentName)
                    ? "${selectedStudentId}_$selectedStudentName"
                    : null, // Set to null if current student isn't in filtered list
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
            child: const Text('İptal')),
        ElevatedButton(
          onPressed: () async {
            if (selectedTeacherId != null &&
                selectedTime != null &&
                selectedStudentId != null &&
                selectedDate != null) {
              final teacherDoc = await firestore.collection('users').doc(selectedTeacherId).get();
              final teacherName = teacherDoc['name'];
              // Corrected: Retrieve 'branches' and use the first branch if available
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
                'date': Timestamp.fromDate(selectedDate!),
                'time': selectedTime,
                'teacherId': selectedTeacherId,
                'teacherName': teacherName,
                'branch': branch,
                'studentId': selectedStudentId,
                'studentName': selectedStudentName,
                'recurring': false,
                'isMakeup': true,
              };

              await newDocRef.set(event);
              widget.onSave(selectedDate!, event);
              Navigator.pop(context);
            }
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}