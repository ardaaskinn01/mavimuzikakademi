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

  Stream<QuerySnapshot> getLessons(String teacherId) {
    return FirebaseFirestore.instance
        .collection('lessons')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('date')
        .snapshots();
  }

  bool isInFilterRange(DateTime lessonDate, FilterType filter) {
    final now = DateTime.now();

    switch (filter) {
      case FilterType.daily:
        return lessonDate.day == now.day &&
            lessonDate.month == now.month &&
            lessonDate.year == now.year;
      case FilterType.weekly:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return lessonDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            lessonDate.isBefore(endOfWeek.add(const Duration(days: 1)));
      case FilterType.monthly:
        return lessonDate.month == now.month && lessonDate.year == now.year;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final teacherId = currentUser?.uid;

    if (teacherId == null) {
      return Center(
        child: Text('Giriş yapmış kullanıcı bulunamadı.',
            style: TextStyle(
                color: Colors.blue[800],
                fontSize: 18,
                fontWeight: FontWeight.w500)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.blue[50],
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: FilterType.values.map((filter) {
                  final isSelected = selectedFilter == filter;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: ChoiceChip(
                      label: Text(
                        filter.displayName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.blue[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      selectedColor: Colors.blue[700],
                      backgroundColor: Colors.blue[50],
                      selected: isSelected,
                      onSelected: (_) => setState(() => selectedFilter = filter),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getLessons(teacherId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Hata oluştu.',
                        style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 18,
                            fontWeight: FontWeight.w500)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                      strokeWidth: 3,
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                final filteredLessons = docs.where((doc) {
                  final date = (doc['date'] as Timestamp).toDate();
                  return isInFilterRange(date, selectedFilter);
                }).toList();

                if (filteredLessons.isEmpty) {
                  return Center(
                    child: Text("Ders bulunamadı.",
                        style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 18,
                            fontWeight: FontWeight.w500)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filteredLessons.length,
                  itemBuilder: (context, index) {
                    final lesson = filteredLessons[index];
                    final title = lesson['branch'];
                    final date = (lesson['date'] as Timestamp).toDate();
                    final formattedDate =
                    DateFormat('dd MMMM yyyy - EEEE', 'tr_TR').format(date);

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.school,
                                        color: Colors.blue[800], size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      lesson['branch'],
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      lesson['time'] ?? '',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 20, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.blue[800]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.person, size: 20, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    lesson['studentName'] ?? 'Öğrenci',
                                    style: TextStyle(fontSize: 15, color: Colors.blue[800]),
                                  ),
                                ],
                              ),
                            ],
                          ),
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