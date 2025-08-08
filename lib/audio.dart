import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart'; // Veya AudioRecorder, paketin güncel adına göre

class AudioRecorderService {
  // `Record()` yerine `AudioRecorder()` veya paketin güncel adı olabilir
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<String?> startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      final dir = await getTemporaryDirectory();
      // Dosya adını ve uzantısını kontrol edin. Bazı sürümler farklı formatları destekleyebilir.
      final filePath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // 'start' metodunun parametreleri değişmiş olabilir.
      // Örneğin, bir RecordConfig nesnesi alabilir.
      // Dokümantasyona bakarak doğru parametreleri kullanın.
      try {
        // Örnek bir yapı, gerçek implementasyon farklı olabilir
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc, // Encoder tipi değişmiş olabilir
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );
        return filePath;
      } catch (e) {
        print("Kayıt başlatılırken hata oluştu: $e");
        return null;
      }
    } else {
      print("Mikrofon izni verilmedi.");
      return null;
    }
  }

  Future<String?> stopRecording() async {
    // `isRecording()` ve `stop()` metodlarının kullanımı değişmiş olabilir.
    try {
      if (await _audioRecorder.isRecording()) {
        final path = await _audioRecorder.stop();
        return path;
      }
    } catch (e) {
      print("Kayıt durdurulurken hata oluştu: $e");
    }
    return null;
  }

  Future<bool> isRecording() async {
    try {
      return await _audioRecorder.isRecording();
    } catch (e) {
      print("Kayıt durumu kontrol edilirken hata oluştu: $e");
      return false;
    }
  }

  // Kaynakları serbest bırakmak için bir dispose metodu eklemek iyi bir pratiktir.
  void dispose() {
    _audioRecorder.dispose();
  }
}