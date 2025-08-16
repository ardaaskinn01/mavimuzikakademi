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
  Map<String, Map<String, int>> monthlyStats =
      {}; // { "2025-08": { "islenen": 0, "gelmedi": 0, "izinli": 0, "bilgiYok": 0 } }

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final firestore = FirebaseFirestore.instance;
    final lessonsSnap =
        await firestore
            .collection('lessons')
            .where('teacherId', isEqualTo: widget.teacherId)
            .get();

    Map<String, Map<String, int>> tempStats = {};

    for (var lessonDoc in lessonsSnap.docs) {
      final data = lessonDoc.data();
      final Timestamp? ts = data['date'];
      if (ts == null) continue;

      final date = ts.toDate();
      final monthKey = DateFormat('yyyy-MM').format(date);

      tempStats.putIfAbsent(
        monthKey,
        () => {"var": 0, "yok": 0, "izinli": 0, "bilgiYok": 0},
      );

      final attendanceSnap =
          await lessonDoc.reference.collection('attendances').get();

      if (attendanceSnap.docs.isEmpty) {
        tempStats[monthKey]!["bilgiYok"] =
            tempStats[monthKey]!["bilgiYok"]! + 1;
      } else {
        for (var attDoc in attendanceSnap.docs) {
          final attData = attDoc.data();
          if (attData['izinli'] == true) {
            tempStats[monthKey]!["izinli"] =
                tempStats[monthKey]!["izinli"]! + 1;
          } else if (attData['status'] == true) {
            tempStats[monthKey]!["var"] = tempStats[monthKey]!["var"]! + 1;
          } else {
            tempStats[monthKey]!["yok"] = tempStats[monthKey]!["yok"]! + 1;
          }
        }
      }
    }

    setState(() {
      monthlyStats = tempStats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nowKey = DateFormat('yyyy-MM').format(DateTime.now());
    final sortedMonths =
    monthlyStats.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ders İstatistikleri"),
        backgroundColor: Colors.blue[800],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : monthlyStats.isEmpty
          ? const Center(
        child: Text(
          "Devamsızlık kaydı yok",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView(
        children: sortedMonths.map((monthKey) {
          final stats = monthlyStats[monthKey]!;
          final isCurrentMonth = monthKey == nowKey;
          final monthName = DateFormat('MMMM yyyy', 'tr_TR')
              .format(DateFormat('yyyy-MM').parse(monthKey));

          return ExpansionTile(
            initiallyExpanded: isCurrentMonth,
            title: Text(
              monthName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                isCurrentMonth ? Colors.blue[800] : Colors.black,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBox("İşlenmiş", stats["var"]!, Colors.green),
                    _statBox("Öğrenci Yok", stats["yok"]!, Colors.red),
                    _statBox(
                        "Öğrenci İzinli",
                        stats["izinli"]!,
                        Colors.orange),
                    _statBox(
                        "Bilgi Yok",
                        stats["bilgiYok"]!,
                        Colors.grey),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _statBox(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
