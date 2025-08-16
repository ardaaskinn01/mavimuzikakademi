import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DayRow extends StatelessWidget {
  final DateTime day;
  final List<Map<String, dynamic>> dayEvents;
  final Function(Map<String, dynamic>) onEventTap;

  const DayRow({
    super.key,
    required this.day,
    required this.dayEvents,
    required this.onEventTap,
  });

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
          // Gün başlığı (daha kompakt)
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
            child: dayEvents.isEmpty
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
              crossAxisCount: 4, // 4 sütunlu grid
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.9, // Daha kareye yakın oran
              crossAxisSpacing: 6, // Yatay boşluk
              mainAxisSpacing: 6, // Dikey boşluk
              padding: EdgeInsets.zero,
              children: dayEvents.map((event) {
                final time = event['time'] ?? '??:??';
                final isMakeup = event['isMakeup'] == true;
                final studentName = event['studentName'] ?? 'Öğrenci';

                return GestureDetector(
                  onTap: () => onEventTap(event),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isMakeup ? Colors.orange[50] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isMakeup ? Colors.orange : Colors.blue,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isMakeup ? Colors.orange[100] : Colors.blue[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isMakeup ? Icons.autorenew : Icons.school,
                            color: isMakeup ? Colors.orange[800] : Colors.blue[800],
                            size: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          time,
                          style: TextStyle(
                            color: isMakeup ? Colors.orange[900] : Colors.blue[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          studentName.length > 10
                              ? '${studentName.substring(0, 8)}..'
                              : studentName,
                          style: TextStyle(
                            color: isMakeup ? Colors.orange[800] : Colors.blue[800],
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