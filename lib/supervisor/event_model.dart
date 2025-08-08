import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final DateTime date;
  final String time;
  final String teacher;
  final String student;
  final bool recurring;

  Event({
    required this.id,
    required this.date,
    required this.time,
    required this.teacher,
    required this.student,
    required this.recurring,
  });

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      date: (map['date'] as Timestamp).toDate(),
      time: map['time'],
      teacher: map['teacherName'],
      student: map['studentName'],
      recurring: map['recurring'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'time': time,
      'teacherName': teacher,
      'studentName': student,
      'recurring': recurring,
    };
  }
}