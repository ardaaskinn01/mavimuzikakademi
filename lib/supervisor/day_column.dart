import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DayRow extends StatelessWidget {
  final DateTime day;
  final List<Map<String, dynamic>> dayEvents;
  final Function(String) onDelete;
  final Function(Map<String, dynamic>) onEventTap;

  const DayRow({
    super.key,
    required this.day,
    required this.dayEvents,
    required this.onDelete,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('E', 'tr_TR').format(day);
    final dayNumber = DateFormat('d').format(day);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gün başlığı
          Row(
            children: [
              Text(
                '$dayName $dayNumber',
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Saat kutuları
          dayEvents.isEmpty
              ? Text(
            'Ders yok',
            style: TextStyle(
              color: Colors.blue[800],
              fontSize: 14,
            ),
          )
              : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: dayEvents.map((event) {
                final time = event['time'] ?? '??:??';
                final id = event['id'];
                final isMakeup = event['isMakeup'] == true;

                return GestureDetector(
                  onTap: () => onEventTap(event),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isMakeup ? Colors.red[50] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                        isMakeup ? Colors.red : Colors.blueAccent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            color: isMakeup
                                ? Colors.red[900]
                                : Colors.blue[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => onDelete(id),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.red),
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
