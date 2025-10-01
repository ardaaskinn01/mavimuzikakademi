import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Öğrenci devamsızlık durumu sınıfı
class StudentAttendance {
  final String studentName;
  final String status;
  final Color statusColor;
  final String statusText;

  StudentAttendance(this.studentName, this.status)
      : statusColor = _getStatusColor(status),
        statusText = _getStatusText(status);

  static Color _getStatusColor(String status) {
    switch (status) {
      case 'var':
        return const Color(0xFF2E7D32);
      case 'yok':
        return const Color(0xFFC62828);
      case 'izinli':
        return const Color(0xFFEF6C00);
      default:
        return const Color(0xFF455A64);
    }
  }

  static String _getStatusText(String status) {
    switch (status) {
      case 'var':
        return 'Geldi';
      case 'yok':
        return 'Gelmedi';
      case 'izinli':
        return 'İzinli';
      default:
        return 'Bilinmiyor';
    }
  }
}

class TeacherStatsPage extends StatefulWidget {
  final String teacherId;
  const TeacherStatsPage({Key? key, required this.teacherId}) : super(key: key);

  @override
  State<TeacherStatsPage> createState() => _TeacherStatsPageState();
}

class _TeacherStatsPageState extends State<TeacherStatsPage> {
  bool _loading = true;
  Map<String, Map<String, dynamic>> monthlyStats = {};
  Map<String, List<Map<String, dynamic>>> monthlyDetails = {};

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'tr_TR';
    _fetchStatsAndDetails();
  }

  Future<void> _fetchStatsAndDetails() async {
    final firestore = FirebaseFirestore.instance;
    final lessonsSnap = await firestore
        .collection('lessons')
        .where('teacherId', isEqualTo: widget.teacherId)
        .get();

    Map<String, Map<String, int>> tempStats = {};
    Map<String, Map<String, dynamic>> groupedLessons = {};

    for (var lessonDoc in lessonsSnap.docs) {
      final lessonData = lessonDoc.data();
      final lessonId = lessonDoc.id;

      // Öğrenci Adlarını ve Grup Ders Durumunu Belirleme
      List<dynamic> studentNamesArray;
      final bool isGroupLessonFromData = lessonData['isGroupLesson'] ?? false;

      if (lessonData.containsKey('studentNames')) {
        studentNamesArray = lessonData['studentNames'] as List<dynamic>;
      } else if (lessonData.containsKey('studentName') && lessonData['studentName'] is String) {
        studentNamesArray = [lessonData['studentName']];
      } else {
        studentNamesArray = [];
      }

      final bool isGroupLesson = isGroupLessonFromData || (studentNamesArray.length > 1);

      final Timestamp? initialDateTs = lessonData['date'];
      if (initialDateTs == null) continue;
      final initialDate = initialDateTs.toDate();
      final formattedTime = lessonData['time'] ?? 'Bilinmiyor';
      final bool isRecurring = lessonData['recurring'] ?? false;

      final attendanceSnap =
      await lessonDoc.reference.collection('attendances').get();

      // Kayıtlı devamsızlıkları uniqueKey (lessonId-YYYY-MM-DD) bazında gruplandır
      Map<String, List<StudentAttendance>> recordedAttendances = {};

      // Kayıtlı devamsızlıkları işleme ve aylık istatistikleri güncelleme
      for (var attDoc in attendanceSnap.docs) {
        final attData = attDoc.data();
        final status = attData['status'] ?? 'bilgiYok';
        final occTs = attData['occurrenceDate'] as Timestamp?;
        // Devamsızlık kaydının tarihini kullan
        final occDate = occTs?.toDate() ?? initialDate;
        final attStudentName = attData['studentName'] ?? 'Bilinmiyor';

        // Aylık istatistikleri güncelle (Sadece kayıtlı olanlar)
        final monthKey = DateFormat('yyyy-MM').format(occDate);
        tempStats.putIfAbsent(
          monthKey,
              () => {"var": 0, "yok": 0, "izinli": 0, "bilgiYok": 0},
        );
        tempStats[monthKey]![status] = tempStats[monthKey]![status]! + 1;

        // Kayıtlı devamsızlıkları uniqueKey ile gruplandır
        final uniqueKey = '$lessonId-${DateFormat('yyyy-MM-dd').format(occDate)}';
        recordedAttendances.putIfAbsent(uniqueKey, () => []);
        recordedAttendances[uniqueKey]!.add(StudentAttendance(attStudentName, status));
      }

      // Tarih Tekrarlarını Hesaplama ve Liste Oluşturma
      // Bu döngü hem tek seferlik hem de tekrar eden dersler için çalışır.
      DateTime currentDate = initialDate;
      final today = DateTime.now();

      // Tek seferlik dersler için sadece başlangıç tarihini kontrol et.
      // Tekrarlayan dersler için bugüne kadar olan tüm haftalık tekrarları kontrol et.
      while (currentDate.isBefore(today.add(const Duration(days: 1)))) {
        final occDate = currentDate;
        final uniqueKey = '$lessonId-${DateFormat('yyyy-MM-dd').format(occDate)}';
        final monthKey = DateFormat('yyyy-MM').format(occDate);
        final occFormattedDate = DateFormat('dd MMMM yyyy', 'tr_TR').format(occDate);

        // 1. Ders tekrarı için kayıtlı devamsızlık var mı?
        if (recordedAttendances.containsKey(uniqueKey)) {
          // Kayıtlı devamsızlık varsa, groupedLessons'a ekle (Zaten istatistiği güncellendi)
          if (!groupedLessons.containsKey(uniqueKey)) {
            groupedLessons[uniqueKey] = {
              'lessonId': lessonId,
              'studentNames': studentNamesArray,
              'teacherName': lessonData['teacherName'] ?? 'Bilinmiyor',
              'branch': lessonData['branch'] ?? 'Bilinmiyor',
              'date': occDate,
              'formattedDate': occFormattedDate,
              'time': formattedTime,
              'isGroupLesson': isGroupLesson,
              'attendances': recordedAttendances[uniqueKey]!,
            };
          }
        }
        // 2. Kayıtlı devamsızlık yoksa ve bu tarih bugünden önceyse 'Bilgi Yok' olarak ekle.
        else if (occDate.isBefore(today)) {
          // İstatistikleri güncelle (Sadece Bilgi Yok statüsü için)
          tempStats.putIfAbsent(
            monthKey,
                () => {"var": 0, "yok": 0, "izinli": 0, "bilgiYok": 0},
          );
          tempStats[monthKey]!["bilgiYok"] = tempStats[monthKey]!["bilgiYok"]! + studentNamesArray.length;

          // Ders detayını Bilgi Yok olarak oluştur ve ekle
          if (!groupedLessons.containsKey(uniqueKey)) {
            groupedLessons[uniqueKey] = {
              'lessonId': lessonId,
              'studentNames': studentNamesArray,
              'teacherName': lessonData['teacherName'] ?? 'Bilinmiyor',
              'branch': lessonData['branch'] ?? 'Bilinmiyor',
              'date': occDate,
              'formattedDate': occFormattedDate,
              'time': formattedTime,
              'isGroupLesson': isGroupLesson,
              'attendances': studentNamesArray
                  .map((name) => StudentAttendance(name.toString(), 'bilgiYok'))
                  .toList(),
            };
          }
        }

        // Tekrar eden ders değilse, döngüyü kır (sadece 1 ders tekrarı işlendi)
        if (!isRecurring) break;

        // Sonraki haftaya geç
        currentDate = currentDate.add(const Duration(days: 7));
      }
    }

    // Gruplanmış ders detaylarını aylara göre sonlandırma
    Map<String, List<Map<String, dynamic>>> finalDetails = {};
    groupedLessons.forEach((key, lessonDetail) {
      final monthKey = DateFormat('yyyy-MM').format(lessonDetail['date']);
      finalDetails.putIfAbsent(monthKey, () => []);
      finalDetails[monthKey]!.add(lessonDetail);
    });

    finalDetails.forEach((monthKey, lessons) {
      lessons.sort(
            (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );
    });

    setState(() {
      monthlyStats = tempStats.map(
              (key, value) => MapEntry(key, value.cast<String, dynamic>()));
      monthlyDetails = finalDetails;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nowKey = DateFormat('yyyy-MM').format(DateTime.now());
    final sortedMonths = monthlyStats.keys.toList()..sort((a, b) => a.compareTo(b));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ders İstatistikleri"),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
        ),
      )
          : monthlyStats.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined,
                size: 60, color: Colors.blueGrey[300]),
            const SizedBox(height: 16),
            Text(
              "Devamsızlık kaydı bulunamadı",
              style: TextStyle(
                fontSize: 18,
                color: Colors.blueGrey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
            stops: [0.1, 0.3],
          ),
        ),
        child: ListView(
          children: sortedMonths.map((monthKey) {
            final stats = monthlyStats[monthKey]!;
            final isCurrentMonth = monthKey == nowKey;
            final monthName = DateFormat('MMMM yyyy', 'tr_TR')
                .format(DateFormat('yyyy-MM').parse(monthKey));

            return Card(
              margin: const EdgeInsets.all(12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ExpansionTile(
                  initiallyExpanded: isCurrentMonth,
                  tilePadding:
                  const EdgeInsets.symmetric(horizontal: 20),
                  collapsedBackgroundColor: Colors.white,
                  backgroundColor: Colors.white,
                  title: Text(
                    monthName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isCurrentMonth
                          ? const Color(0xFF0D47A1)
                          : Colors.black87,
                    ),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin:
                      const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceAround,
                        children: [
                          _statBox("Geldi", stats["var"] as int,
                              const Color(0xFF2E7D32)),
                          _statBox("Gelmedi", stats["yok"] as int,
                              const Color(0xFFC62828)),
                          _statBox("İzinli", stats["izinli"] as int,
                              const Color(0xFFEF6C00)),
                          _statBox("Bilgi Yok",
                              stats["bilgiYok"] as int,
                              const Color(0xFF455A64)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics:
                        const NeverScrollableScrollPhysics(),
                        itemCount: monthlyDetails[monthKey]!.length,
                        itemBuilder: (context, index) {
                          final details =
                          monthlyDetails[monthKey]![index];
                          return Padding(
                            padding:
                            const EdgeInsets.only(bottom: 12),
                            child: _buildDetailsCard(details),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(Map<String, dynamic> details) {
    final List<StudentAttendance> attendances =
    details['attendances'] as List<StudentAttendance>;
    final bool isGroupLesson = details['isGroupLesson'] as bool ?? false;
    final List<dynamic> studentNames = details['studentNames'] ?? [];

    // Bireysel derslerde tek öğrenci adı
    final String lessonTitle = !isGroupLesson && studentNames.isNotEmpty
        ? studentNames.first.toString()
        : 'Grup Dersi';

    StudentAttendance? singleAttendance =
    (!isGroupLesson && attendances.length == 1) ? attendances.first : null;

    Color statusColor = singleAttendance?.statusColor ?? const Color(0xFF1976D2);
    String statusText = singleAttendance?.statusText ?? 'Grup Dersi';

    if (singleAttendance != null && !isGroupLesson) {
      statusColor = singleAttendance.statusColor;
      statusText = singleAttendance.statusText;
    } else if (isGroupLesson && attendances.isNotEmpty) {
      statusColor = attendances.first.statusColor;
      statusText = attendances.first.statusText;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              lessonTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              maxLines: isGroupLesson ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            _detailRow(Icons.person_outline,
                'Öğretmen: ${details['teacherName']}', Colors.blueGrey),
            const SizedBox(height: 4),
            _detailRow(Icons.category_outlined,
                'Branş: ${details['branch']}', Colors.blueGrey),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: _detailRow(Icons.calendar_today_outlined,
                      details['formattedDate'], const Color(0xFF1976D2)),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: _detailRow(Icons.access_time_outlined,
                      details['time'], const Color(0xFF1976D2)),
                ),
              ],
            ),
            if (isGroupLesson && attendances.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Öğrenci Statüleri:',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: List.generate(studentNames.length, (index) {
                  final name = studentNames[index].toString();
                  final att = attendances.length > index ? attendances[index] : null;
                  final attStatusText = att?.statusText ?? 'Bilinmiyor';
                  final attStatusColor = att?.statusColor ?? const Color(0xFF455A64);

                  return Chip(
                    label: Text(
                      '$name: $attStatusText',
                      style: TextStyle(
                          fontSize: 12,
                          color: attStatusColor,
                          fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: attStatusColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                          color: attStatusColor.withOpacity(0.3), width: 1),
                    ),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.blueGrey[700], fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: Colors.blueGrey[700])),
        ),
      ],
    );
  }
}
