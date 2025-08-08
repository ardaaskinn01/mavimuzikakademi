import 'package:cloud_firestore/cloud_firestore.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addEvent(Map<String, dynamic> eventData) async {
    await _firestore.collection('lessons').add(eventData);
  }

  Future<void> deleteEvent(String eventId) async {
    await _firestore.collection('lessons').doc(eventId).delete();
  }

  Future<List<Map<String, dynamic>>> getAllEvents() async {
    final snapshot = await FirebaseFirestore.instance.collection('lessons').get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}