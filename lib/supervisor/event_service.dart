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
    // 1. Tüm dersleri 'lessons' koleksiyonundan çek.
    final lessonSnapshot = await _firestore.collection('lessons').get();

    // 2. Dersler için boş bir liste oluştur.
    List<Map<String, dynamic>> allLessons = [];

    // 3. Her bir ders belgesi üzerinde döngüye gir.
    for (var lessonDoc in lessonSnapshot.docs) {
      final lessonData = lessonDoc.data();
      final String teacherId = lessonData['teacherId'];

      // 4. İlgili öğretmenin 'users' koleksiyonundaki belgesini çek.
      final teacherDoc = await _firestore.collection('users').doc(teacherId).get();

      // 5. Öğretmen verisini kontrol et ve rengi al.
      final String? teacherColor = teacherDoc.data()?['color'];

      // 6. Ders verisine rengi ekle. Eğer renk tanımlı değilse varsayılan bir değer ata.
      lessonData['teacherColor'] = teacherColor ?? 'Gri';

      // 7. Ders belgesinin ID'sini de ekle (güncelleme veya silme işlemleri için gerekli).
      lessonData['id'] = lessonDoc.id;

      // 8. Son olarak, güncellenmiş ders verisini listeye ekle.
      allLessons.add(lessonData);
    }

    // 9. Tamamlanan ders listesini döndür.
    return allLessons;
  }
}