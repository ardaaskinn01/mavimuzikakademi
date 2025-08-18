import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
    _fetchStatsAndDetails();
  }

  Future<void> _fetchStatsAndDetails() async {
    final firestore = FirebaseFirestore.instance;
    final lessonsSnap = await firestore
        .collection('lessons')
        .where('teacherId', isEqualTo: widget.teacherId)
        .get();

    Map<String, Map<String, int>> tempStats = {};
    Map<String, List<Map<String, dynamic>>> tempDetails = {};

    for (var lessonDoc in lessonsSnap.docs) {
      final lessonData = lessonDoc.data();
      final Timestamp? ts = lessonData['date'];
      if (ts == null) continue;

      final date = ts.toDate();
      final monthKey = DateFormat('yyyy-MM').format(date);
      final formattedDate = DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
      final formattedTime = lessonData['time'] ?? 'Bilinmiyor';

      tempStats.putIfAbsent(
        monthKey,
            () => {"var": 0, "yok": 0, "izinli": 0, "bilgiYok": 0},
      );
      tempDetails.putIfAbsent(monthKey, () => []);

      final attendanceSnap = await lessonDoc.reference.collection('attendances').get();

      if (attendanceSnap.docs.isEmpty) {
        tempStats[monthKey]!["bilgiYok"] = tempStats[monthKey]!["bilgiYok"]! + 1;
        tempDetails[monthKey]!.add({
          'studentName': lessonData['studentName'] ?? 'Bilinmiyor',
          'teacherName': lessonData['teacherName'] ?? 'Bilinmiyor',
          'branch': lessonData['branch'] ?? 'Bilinmiyor',
          'date': date, // Sıralama için tam tarih objesini kullan
          'formattedDate': formattedDate,
          'time': formattedTime,
          'status': 'bilgi yok',
        });
      } else {
        for (var attDoc in attendanceSnap.docs) {
          final attData = attDoc.data();
          final status = attData['status'] ?? 'bilgiYok';

          if (status == "izinli") {
            tempStats[monthKey]!["izinli"] = tempStats[monthKey]!["izinli"]! + 1;
          } else if (status == "var") {
            tempStats[monthKey]!["var"] = tempStats[monthKey]!["var"]! + 1;
          } else if (status == "yok") {
            tempStats[monthKey]!["yok"] = tempStats[monthKey]!["yok"]! + 1;
          } else {
            tempStats[monthKey]!["bilgiYok"] = tempStats[monthKey]!["bilgiYok"]! + 1;
          }

          tempDetails[monthKey]!.add({
            'studentName': lessonData['studentName'] ?? 'Bilinmiyor',
            'teacherName': lessonData['teacherName'] ?? 'Bilinmiyor',
            'branch': lessonData['branch'] ?? 'Bilinmiyor',
            'date': date, // Sıralama için tam tarih objesini kullan
            'formattedDate': formattedDate,
            'time': formattedTime,
            'status': status,
          });
        }
      }
    }

    // Her ayın ders detaylarını tarihe göre sırala (en eskiden en yeniye)
    tempDetails.forEach((monthKey, lessons) {
      lessons.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    });

    setState(() {
      monthlyStats = tempStats.map((key, value) => MapEntry(key, value.cast<String, dynamic>()));
      monthlyDetails = tempDetails;
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
            Icon(Icons.assignment_outlined, size: 60, color: Colors.blueGrey[300]),
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
            final monthName = DateFormat('MMMM yyyy', 'tr_TR').format(DateFormat('yyyy-MM').parse(monthKey));

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
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                  collapsedBackgroundColor: Colors.white,
                  backgroundColor: Colors.white,
                  title: Text(
                    monthName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isCurrentMonth ? const Color(0xFF0D47A1) : Colors.black87,
                    ),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statBox("Geldi", stats["var"] as int, const Color(0xFF2E7D32)),
                          _statBox("Gelmedi", stats["yok"] as int, const Color(0xFFC62828)),
                          _statBox("İzinli", stats["izinli"] as int, const Color(0xFFEF6C00)),
                          _statBox("Bilgi Yok", stats["bilgiYok"] as int, const Color(0xFF455A64)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: monthlyDetails[monthKey]!.length,
                        itemBuilder: (context, index) {
                          final details = monthlyDetails[monthKey]![index];
                          Color statusColor;
                          String statusText;

                          switch (details['status']) {
                            case 'var':
                              statusColor = const Color(0xFF2E7D32);
                              statusText = 'Geldi';
                              break;
                            case 'yok':
                              statusColor = const Color(0xFFC62828);
                              statusText = 'Gelmedi';
                              break;
                            case 'izinli':
                              statusColor = const Color(0xFFEF6C00);
                              statusText = 'İzinli';
                              break;
                            default:
                              statusColor = const Color(0xFF455A64);
                              statusText = 'Bilinmiyor';
                          }

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueGrey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Card(
                              elevation: 0,
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
                                      details['studentName'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    _detailRow(
                                      Icons.person_outline,
                                      'Öğretmen: ${details['teacherName']}',
                                      Colors.blueGrey,
                                    ),
                                    const SizedBox(height: 4),
                                    _detailRow(
                                      Icons.category_outlined,
                                      'Branş: ${details['branch']}',
                                      Colors.blueGrey,
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: Colors.black12),
                                    const SizedBox(height: 12),
                                    _detailRow(
                                      Icons.calendar_today_outlined,
                                      details['formattedDate'],
                                      const Color(0xFF1976D2),
                                    ),
                                    const SizedBox(height: 4),
                                    _detailRow(
                                      Icons.access_time_outlined,
                                      details['time'],
                                      const Color(0xFF1976D2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blueGrey[700],
            fontWeight: FontWeight.w500,
          ),
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
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.blueGrey[700],
            ),
          ),
        ),
      ],
    );
  }
}