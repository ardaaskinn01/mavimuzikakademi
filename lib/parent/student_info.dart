import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentInfoScreen extends StatefulWidget {
  final String parentUserId;

  const StudentInfoScreen({Key? key, required this.parentUserId})
      : super(key: key);

  @override
  State<StudentInfoScreen> createState() => _StudentInfoScreenState();
}

class _StudentInfoScreenState extends State<StudentInfoScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> attendanceRecords = [];
  List<Map<String, dynamic>> students = [];
  String? selectedStudentId;

  @override
  void initState() {
    super.initState();
    loadParentData();
  }

  Future<void> loadParentData() async {
    final parentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.parentUserId)
        .get();

    if (!parentDoc.exists) {
      setState(() => isLoading = false);
      return;
    }

    final parentData = parentDoc.data();
    setState(() {
      students = List<Map<String, dynamic>>.from(parentData?['students'] ?? []);
      if (students.isNotEmpty) {
        selectedStudentId = students.first['name']; // Öğrenci adını kullanıyoruz
      }
    });

    if (selectedStudentId != null) {
      await loadStudentAttendance(selectedStudentId!);
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> loadStudentAttendance(String studentName) async {
    setState(() => isLoading = true);
    List<Map<String, dynamic>> tempAttendance = [];

    final lessonsSnapshot = await FirebaseFirestore.instance
        .collection('lessons')
        .where('studentName', isEqualTo: studentName)
        .get();

    for (var lessonDoc in lessonsSnapshot.docs) {
      final lessonId = lessonDoc.id;
      final lessonData = lessonDoc.data();

      final attendanceDoc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(lessonId)
          .collection('attendances')
          .doc(widget.parentUserId)
          .get();

      if (attendanceDoc.exists) {
        final attData = attendanceDoc.data();
        tempAttendance.add({
          'lessonId': lessonId,
          'lessonBranch': lessonData['branch'] ?? '',
          'date': (lessonData['date'] as Timestamp).toDate(),
          'status': attData?['status'] ?? 'unknown',
          'studentName': studentName,
        });
      }
    }

    tempAttendance.sort((a, b) => b['date'].compareTo(a['date']));

    setState(() {
      attendanceRecords = tempAttendance;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Öğrenci Takip',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      backgroundColor: Colors.blue[50],
      body: Column(
        children: [
          // Öğrenci Seçim Dropdown
          if (students.length > 1)
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
                  items: students.map((student) {
                    return DropdownMenuItem<String>(
                      value: student['name'],
                      child: Text(
                        student['name'],
                        style: TextStyle(color: Colors.blue[900]),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => selectedStudentId = newValue);
                      loadStudentAttendance(newValue);
                    }
                  },
                ),
              ),
            ),
          Expanded(
            child: isLoading
                ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
              ),
            )
                : attendanceRecords.isEmpty
                ? Center(
              child: Text(
                'Devamsızlık bilgisi bulunamadı.',
                style: TextStyle(color: Colors.blue[800], fontSize: 16),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              itemCount: attendanceRecords.length,
              itemBuilder: (context, index) {
                final record = attendanceRecords[index];
                final rawStatus = record['status'];
                String statusLabel;
                Color statusColor;
                IconData statusIcon;

                if (rawStatus == 'var') {
                  statusLabel = 'Katıldı';
                  statusColor = Colors.green[700]!;
                  statusIcon = Icons.check_circle;
                } else if (rawStatus == 'izinli') {
                  statusLabel = 'İzinli';
                  statusColor = Colors.orange[700]!;
                  statusIcon = Icons.event_available;
                } else {
                  statusLabel = 'Katılmadı';
                  statusColor = Colors.red[700]!;
                  statusIcon = Icons.cancel;
                }

                final dateStr = record['date'] != null
                    ? DateFormat('dd MMMM yyyy, EEEE', 'tr_TR')
                    .format(record['date'])
                    : 'Tarih belirtilmemiş';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 8,
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
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              statusIcon,
                              color: statusColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record['studentName'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  record['lessonBranch'],
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateStr,
                                  style: TextStyle(color: Colors.blue[600]),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}