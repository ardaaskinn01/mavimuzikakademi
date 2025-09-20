import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DayRow extends StatelessWidget {
  final DateTime day;
  final List<Map<String, dynamic>>? dayEvents;
  final Function(Map<String, dynamic>) onEventTap;

  const DayRow({
    super.key,
    required this.day,
    required this.dayEvents,
    required this.onEventTap,
  });

  // Öğretmen rengini (string) Color nesnesine çeviren yardımcı fonksiyon
  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'mavi':
        return Colors.blue;
      case 'mor':
        return Colors.purple;
      case 'kırmızı':
        return Colors.red;
      case 'sarı':
        return Colors.yellow.shade700;
      case 'yeşil':
        return Colors.green;
      case 'turuncu':
        return Colors.orange;
      case 'pembe':
        return Colors.pink;
      case 'siyah':
        return Colors.black;
      case 'gri':
        return Colors.grey;
      case 'açık yeşil':
        return Colors.lightGreen;
      case 'kahverengi':
        return Colors.brown;
      case 'lacivert':
        return Colors.indigo;
      default:
        return Colors.blueGrey; // Varsayılan renk
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('E', 'tr_TR').format(day);
    final dayNumber = DateFormat('d').format(day);
    final monthName = DateFormat('MMM', 'tr_TR').format(day);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gün başlığı
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: Colors.blue[800],
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$dayName, $dayNumber $monthName',
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Dersler (4'lü grid)
          Padding(
            padding: const EdgeInsets.all(8),
            // 🟢 Burası değişti: dayEvents null ise CircularProgressIndicator göster
            child: dayEvents == null
                ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(),
              ),
            )
                : dayEvents!.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Ders yok',
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontSize: 12,
                  ),
                ),
              ),
            )
                : GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.9,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              padding: EdgeInsets.zero,
              children: dayEvents!.map((event) {
                final time = event['time'] ?? '??:??';
                final isMakeup = event['isMakeup'] == true;
                final isGroupLesson = event['isGroupLesson'] == true;
                final studentName = event['studentName'] ?? 'Öğrenci';

                final teacherColorName = (event['teacherColor'] ?? 'gri').toString();
                final teacherColor = _getColorFromString(teacherColorName);

                return GestureDetector(
                  onTap: () => onEventTap(event),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isMakeup
                          ? Colors.amber.shade200
                          : teacherColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isMakeup ? Colors.orange : teacherColor,
                        width: isMakeup ? 5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isMakeup ? Colors.orange.shade100 : teacherColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isMakeup ? Icons.autorenew : Icons.school,
                            color: isMakeup ? Colors.orange.shade500 : teacherColor,
                            size: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          time,
                          style: TextStyle(
                            color: isMakeup ? Colors.orange.shade500 : teacherColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (isGroupLesson)
                          const Text(
                            'Grup Dersi',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            studentName.length > 10
                                ? '${studentName.substring(0, 8)}..'
                                : studentName,
                            style: TextStyle(
                              color: isMakeup ? Colors.orange.shade500 : teacherColor,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}