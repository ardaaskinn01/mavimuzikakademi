import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class Dersler extends StatefulWidget {
  const Dersler({Key? key}) : super(key: key);

  @override
  _DerslerState createState() => _DerslerState();
}

class _DerslerState extends State<Dersler> {
  FilterType selectedFilter = FilterType.daily;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  Stream<QuerySnapshot> getLessons(String teacherId) {
    return FirebaseFirestore.instance
        .collection('lessons')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('date')
        .snapshots();
  }

  // filtre penceresinin başlangıç ve bitiş tarihlerini döndürür (end exclusive)
  Map<String, DateTime> _getWindowRange(FilterType filter) {
    final now = DateTime.now();
    if (filter == FilterType.daily) {
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      return {'start': start, 'end': end};
    } else if (filter == FilterType.weekly) {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Pazartesi başlangıç
      final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      final end = start.add(const Duration(days: 7));
      return {'start': start, 'end': end};
    } else {
      // monthly
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 1);
      return {'start': start, 'end': end};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Center(child: Text("Kullanıcı kimliği bulunamadı."));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ders Programı",
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
          // Filtre seçenekleri
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: FilterType.values.map((filter) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedFilter = filter;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selectedFilter == filter
                          ? Colors.blue[700]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      filter.displayName,
                      style: TextStyle(
                        color: selectedFilter == filter
                            ? Colors.white
                            : Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getLessons(userId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Bir hata oluştu: ${snapshot.error}',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "Henüz dersiniz bulunmamaktadır.",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filtre penceresi
                final window = _getWindowRange(selectedFilter);
                final windowStart = window['start']!;
                final windowEnd = window['end']!;

                // Tüm ders dökümanlarından pencereye düşen (ve recurring hesaba katılmış) örnekler oluştur.
                final List<Map<String, dynamic>> occurrences = [];

                for (final doc in snapshot.data!.docs) {
                  final lessonData = doc.data() as Map<String, dynamic>;
                  final Timestamp ts = lessonData['date'] as Timestamp;
                  final DateTime originalDate = ts.toDate();

                  // time alanı varsa parse et, yoksa timestamp içindeki saati kullan
                  final String timeStr = (lessonData['time'] ?? '').toString();
                  int hour = originalDate.hour;
                  int minute = originalDate.minute;
                  if (timeStr.isNotEmpty) {
                    try {
                      final parts = timeStr.split(':');
                      hour = int.parse(parts[0]);
                      minute = int.parse(parts.length > 1 ? parts[1] : '0');
                    } catch (e) {
                      // parse hatası olursa fallback: timestamp saatini kullan
                    }
                  }

                  DateTime firstOccurrence = DateTime(
                    originalDate.year,
                    originalDate.month,
                    originalDate.day,
                    hour,
                    minute,
                  );

                  final bool recurring = lessonData['recurring'] ?? false;

                  if (recurring) {
                    // Eğer ilk occurrence pencere başlangıcından önceyse, pencereye yakın ilk haftalık occurrence'a ilerle
                    DateTime occ = firstOccurrence;
                    if (occ.isBefore(windowStart)) {
                      // Haftalık ilerle
                      final daysDiff = windowStart.difference(occ).inDays;
                      final weeksToAdd = (daysDiff / 7).floor();
                      occ = occ.add(Duration(days: weeksToAdd * 7));
                      while (occ.isBefore(windowStart)) {
                        occ = occ.add(const Duration(days: 7));
                      }
                    }

                    // pencere sonuna kadar haftalık ekle
                    while (!occ.isAfter(windowEnd.subtract(const Duration(seconds: 1)))) {
                      // occ pencere içinde ise ekle
                      if (!occ.isBefore(windowStart) && occ.isBefore(windowEnd)) {
                        occurrences.add({
                          'id': doc.id,
                          'date': occ,
                          'time': DateFormat('HH:mm').format(occ),
                          'branch': lessonData['branch'] ?? '',
                          'isGroupLesson': lessonData['isGroupLesson'] ?? false,
                          'studentNames': lessonData['isGroupLesson'] == true
                              ? List<String>.from((lessonData['studentNames'] ?? []) as List<dynamic>)
                              : [lessonData['studentName'] ?? ''],
                          'teacherName': lessonData['teacherName'] ?? '',
                          'teacherId': lessonData['teacherId'] ?? '',
                        });
                      }
                      occ = occ.add(const Duration(days: 7));
                      // Güvenlik: sonsuz döngüyü önlemek için çok ileri gitmeyi kes
                      if (occ.year > windowEnd.year + 1) break;
                    }
                  } else {
                    // Tek seferlik ders: date pencerede ise ekle
                    if (!firstOccurrence.isBefore(windowStart) && firstOccurrence.isBefore(windowEnd)) {
                      occurrences.add({
                        'id': doc.id,
                        'date': firstOccurrence,
                        'time': DateFormat('HH:mm').format(firstOccurrence),
                        'branch': lessonData['branch'] ?? '',
                        'isGroupLesson': lessonData['isGroupLesson'] ?? false,
                        'studentNames': lessonData['isGroupLesson'] == true
                            ? List<String>.from((lessonData['studentNames'] ?? []) as List<dynamic>)
                            : [lessonData['studentName'] ?? ''],
                        'teacherName': lessonData['teacherName'] ?? '',
                        'teacherId': lessonData['teacherId'] ?? '',
                      });
                    }
                  }
                }

                // Tarihe göre sırala (erken -> geç)
                occurrences.sort((a, b) {
                  final DateTime da = a['date'] as DateTime;
                  final DateTime db = b['date'] as DateTime;
                  return da.compareTo(db);
                });

                if (occurrences.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "Bu filtreye uygun ders bulunamadı.",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: occurrences.length,
                  itemBuilder: (context, index) {
                    final lesson = occurrences[index];
                    final lessonDate = lesson['date'] as DateTime;
                    final formattedDate = DateFormat('dd MMMM yyyy', 'tr_TR').format(lessonDate);
                    final formattedTime = DateFormat('HH:mm', 'tr_TR').format(lessonDate);
                    final isGroupLesson = lesson['isGroupLesson'] as bool;

                    String studentNameText;
                    if (isGroupLesson) {
                      final List<String> studentNames = List<String>.from(lesson['studentNames'] ?? []);
                      studentNameText = studentNames.join(', ');
                    } else {
                      final sn = (lesson['studentNames'] as List).isNotEmpty ? (lesson['studentNames'] as List)[0] : 'Öğrenci';
                      studentNameText = sn;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sol taraftaki zaman bilgisi
                            Container(
                              width: 70,
                              child: Column(
                                children: [
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Dikey ayırıcı çizgi
                            Container(
                              width: 2,
                              height: 80,
                              color: Colors.blue[100],
                            ),

                            const SizedBox(width: 16),

                            // Ders bilgileri
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Branş ve grup/bireysel ikonu
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          lesson['branch'] ?? 'Branş yok',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[900],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isGroupLesson
                                              ? Colors.purple[50]
                                              : Colors.blue[50],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isGroupLesson
                                                  ? FontAwesomeIcons.users
                                                  : FontAwesomeIcons.user,
                                              size: 12,
                                              color: isGroupLesson
                                                  ? Colors.purple[700]
                                                  : Colors.blue[700],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isGroupLesson ? 'Grup' : 'Bireysel',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isGroupLesson
                                                    ? Colors.purple[700]
                                                    : Colors.blue[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // Öğrenci bilgisi
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 16,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          studentNameText,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // Öğretmen bilgisi (varsa)
                                  if ((lesson['teacherName'] ?? '').toString().isNotEmpty)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.school_outlined,
                                          size: 16,
                                          color: Colors.blue[700],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          lesson['teacherName'] ?? '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum FilterType { daily, weekly, monthly }

extension FilterTypeExtension on FilterType {
  String get displayName {
    switch (this) {
      case FilterType.daily:
        return 'Günlük';
      case FilterType.weekly:
        return 'Haftalık';
      case FilterType.monthly:
        return 'Aylık';
    }
  }
}