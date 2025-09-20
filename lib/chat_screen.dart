import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'audio.dart'; // Bu dosyanın mevcut olduğunu varsayıyoruz.

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final bool isReadOnly;
  final List<String>? chatParticipants; // 👈 supervisor için opsiyonel

  const ChatScreen({
    super.key,
    required this.receiverId,
    this.isReadOnly = false,
    this.chatParticipants, // 👈
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _user = FirebaseAuth.instance.currentUser;
  late FocusNode _focusNode;
  final _encryptionKey = 'mkqcjwefsxgerbwhxmmlfnfdqrjbbadb';
  late final encrypt.Encrypter _encrypter;
  final _iv = encrypt.IV.fromUtf8('1234567890123456');
  AudioRecorderService _audioService = AudioRecorderService();
  bool _isRecording = false;
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  String? _currentlyPlayingUrl;

  @override
  void initState() {
    super.initState();
    final key = encrypt.Key.fromUtf8(_encryptionKey);
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _audioPlayerService.dispose();
    super.dispose();
  }

  final List<String> kaynaklar = [
    "Alfred’s Basic Piano Library",
    "Bastien Piano Basics",
    "Faber & Faber (Piano Adventures)",
    "Carl Czerny Etütleri",
    "Hanon",
    "Renklerle Piyano Öğretimi",
    "Enver Tufan & Selmin Tufan – Piyano Metodu 1, 2",
    "Gençler ve Yetişkinler İçin Başlangıç Piyano Metodu",
    "Piyano Albümü",
    "Yalçın İman – Piyano Metodu",
    "Sevinç Ereren – Kolay Piyano 1, 2 / Kolay Solfej",
  ];

  bool isUrl(String text) {
    final urlPattern = r'^(https?:\/\/)[\w\-\.]+\.\w{2,}(\/\S*)?$';
    final result = RegExp(urlPattern, caseSensitive: false).hasMatch(text);
    return result;
  }

  Stream<QuerySnapshot> _buildMessageStream() {
    final base = FirebaseFirestore.instance.collection('messages');

    String chatId;

    if (widget.isReadOnly && widget.chatParticipants != null && widget.chatParticipants!.length == 2) {
      // Supervisor modu, chatParticipants listesini kullan
      final user1 = widget.chatParticipants![0];
      final user2 = widget.chatParticipants![1];
      chatId = getChatId(user1, user2);
    } else {
      // Normal kullanıcı modu, kendi UID'sini ve receiverId'yi kullan
      chatId = getChatId(_user!.uid, widget.receiverId);
    }

    return base
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  void sendMessage(String text, {bool isFile = false}) async {
    if (widget.isReadOnly || text.trim().isEmpty) return;

    final encrypted = _encrypter.encrypt(text, iv: _iv);
    final chatId = getChatId(_user!.uid, widget.receiverId);

    final messageDoc = {
      'senderId': _user!.uid,
      'receiverId': widget.receiverId,
      'text': encrypted.base64,
      'timestamp': FieldValue.serverTimestamp(),
      'isFile': isFile,
      'participants': [_user!.uid, widget.receiverId],
      'chatId': chatId,
    };

    await FirebaseFirestore.instance.collection('messages').add(messageDoc);

    // 🔹 Update or create chat metadata (lastMessage)
    String previewText = text;

    if (isFile) {
      final lower = text.toLowerCase();
      if (lower.endsWith('.jpg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.gif')) {
        previewText = '🖼️ Görsel';
      } else if (lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.webm')) {
        previewText = '🎥 Video';
      } else if (isAudio(lower)) {
        previewText = '🎤 Ses';
      } else {
        previewText = '📎 Belge';
      }
    }

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMessage': previewText,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': [_user!.uid, widget.receiverId],
    });

    _controller.clear();
  }

  bool isAudio(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.m4a') ||
        lowerUrl.endsWith('.mp3') ||
        lowerUrl.endsWith('.wav') ||
        lowerUrl.endsWith('.aac') ||
        lowerUrl.endsWith('.ogg');
  }

  Future<bool> _isteMedyaDosyaIzni() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;

      if (sdkVersion >= 33) {
        // Android 13 (API 33) ve sonrası için daha spesifik izinler
        final statusImages = await Permission.photos.request();
        final statusVideos = await Permission.videos.request();
        // Ek olarak, kullanıcıya belirli görselleri seçme izni için
        // Permission.photos.request() yeterlidir.
        return statusImages.isGranted || statusVideos.isGranted;
      } else if (sdkVersion >= 29) {
        // Android 10 (API 29) ve sonrası için Scoped Storage geçerli,
        // FilePicker otomatik olarak çalışır.
        return true;
      } else {
        // Android 9 (API 28) ve öncesi için
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    // iOS için her zaman true döndür
    return true;
  }

// pickAndSendFile fonksiyonunun güncellenmiş hali
  Future<void> pickAndSendFile() async {
    if (widget.isReadOnly) return;

    final izinVar = await _isteMedyaDosyaIzni();
    if (!izinVar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Dosya göndermek için gerekli izinler alınamadı."),
        ),
      );
      return;
    }

    // Mevcut FilePicker kodu bu satırdan sonra devam edebilir
    final result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final file = File(path);
      final fileName = path.split('/').last;

      final senderId = _user!.uid;
      final receiverId = widget.receiverId;

      final subPath = "mesajlar/${senderId}_to_${receiverId}/$fileName";

      // Supabase'e klasörlü şekilde yükle
      await Supabase.instance.client.storage
          .from('kuyumcu')
          .upload(subPath, file);

      // URL'yi al
      final publicUrl = Supabase.instance.client.storage
          .from('kuyumcu')
          .getPublicUrl(subPath);

      // Mesaj olarak gönder
      sendMessage(publicUrl, isFile: true);
    }
  }

  void handleFileTap(BuildContext context, String url) {
    final uri = Uri.parse(url);
    final lowerUrl = url.toLowerCase();

    // Görsel dosya
    if (lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.gif')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FullscreenImageViewer(imageUrl: url)),
      );
    }
    // Video dosyası (videoplayer kullanabilirsin istersen)
    else if (lowerUrl.endsWith('.mp4') ||
        lowerUrl.endsWith('.mov') ||
        lowerUrl.endsWith('.webm')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoUrl: url)),
      );
    }
    // Diğer dosyalar → dış uygulama ile aç
    else {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Stream<QuerySnapshot> getChatStream() {
    return FirebaseFirestore.instance
        .collection('messages')
        .where('participants', arrayContains: _user!.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return "${sorted[0]}_${sorted[1]}";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.receiverId)
              .get(),
      builder: (context, snapshot) {
        String title = "Yükleniyor...";

        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          title = snapshot.data!.get('name') ?? 'Bilinmeyen Kişi';
        }

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.blue[50],
          appBar: AppBar(
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.blue[800],
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),
          body: Column(
            children: [
              // --- Mesajlar Listesi ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _buildMessageStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue[700]!,
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          "Henüz mesaj yok",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final msg = docs[index];
                        final isMe = msg['senderId'] == _user!.uid;
                        final encryptedText = msg['text'];
                        final decryptedText = _encrypter.decrypt64(
                          encryptedText,
                          iv: _iv,
                        );
                        final isFile = msg['isFile'] == true;
                        final timestamp = msg['timestamp'] as Timestamp?;
                        final timeString =
                            timestamp != null
                                ? DateFormat('HH:mm').format(timestamp.toDate())
                                : '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment:
                                isMe
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.8,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        isMe ? Colors.blue[700] : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft:
                                          isMe
                                              ? const Radius.circular(16)
                                              : Radius.zero,
                                      bottomRight:
                                          isMe
                                              ? Radius.zero
                                              : const Radius.circular(16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        isMe
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                    children: [
                                      if (isFile)
                                        InkWell(
                                          onTap:
                                              () => handleFileTap(
                                                context,
                                                decryptedText,
                                              ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.attach_file,
                                                color:
                                                    isMe
                                                        ? Colors.white
                                                        : Colors.blue[700],
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "Belge veya Medya",
                                                style: TextStyle(
                                                  color:
                                                      isMe
                                                          ? Colors.white
                                                          : Colors.blue[800],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (isAudio(decryptedText))
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                _currentlyPlayingUrl ==
                                                        decryptedText
                                                    ? Icons.stop
                                                    : Icons.play_arrow,
                                                color:
                                                    isMe
                                                        ? Colors.white
                                                        : Colors.blue[700],
                                              ),
                                              onPressed: () async {
                                                if (_currentlyPlayingUrl ==
                                                    decryptedText) {
                                                  await _audioPlayerService
                                                      .stop();
                                                  setState(() {
                                                    _currentlyPlayingUrl = null;
                                                  });
                                                } else {
                                                  await _audioPlayerService
                                                      .play(decryptedText);
                                                  setState(() {
                                                    _currentlyPlayingUrl =
                                                        decryptedText;
                                                  });
                                                }
                                              },
                                            ),
                                            Text(
                                              "Ses Mesajı",
                                              style: TextStyle(
                                                color:
                                                    isMe
                                                        ? Colors.white
                                                        : Colors.blue[800],
                                              ),
                                            ),
                                          ],
                                        )
                                      else if (isUrl(decryptedText))
                                        InkWell(
                                          onTap:
                                              () => launchCustomUrl(
                                                context,
                                                decryptedText,
                                              ),
                                          child: Text(
                                            decryptedText,
                                            style: TextStyle(
                                              color:
                                                  isMe
                                                      ? Colors.white
                                                      : Colors.blue[700],
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        )
                                      else
                                        Text(
                                          decryptedText,
                                          style: TextStyle(
                                            color:
                                                isMe
                                                    ? Colors.white
                                                    : Colors.blue[900],
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        timeString,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              isMe
                                                  ? Colors.white70
                                                  : Colors.blue[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // --- Mesaj Giriş Alanı (sadece isReadOnly == false ise) ---
              if (!widget.isReadOnly)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.attach_file, color: Colors.blue[700]),
                        onPressed: pickAndSendFile,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: "Mesaj gönder...",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.blue[50],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () => sendMessage(_controller.text),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                        ),
                      ),
                      IconButton(
                        icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                        color: Colors.blueAccent,
                        onPressed: () async {
                          if (!_isRecording) {
                            await _audioService.startRecording();
                            setState(() {
                              _isRecording = true;
                            });
                          } else {
                            final shouldSend = await showDialog<bool>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Ses Kaydı'),
                                    content: const Text(
                                      'Ses kaydını göndermek istiyor musunuz?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, false),
                                        child: const Text('İptal'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, true),
                                        child: const Text('Gönder'),
                                      ),
                                    ],
                                  ),
                            );

                            if (shouldSend == true) {
                              final audioUrl =
                                  await _audioService.stopRecording();
                              if (audioUrl != null) {
                                sendMessage(audioUrl, isFile: true);
                              }
                            } else {
                              await _audioService.stopRecording();
                            }
                            setState(() {
                              _isRecording = false;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// FullscreenImageViewer ve VideoPlayerScreen gibi yardımcı widget'ların burada tanımlı olduğunu varsayıyoruz.
// launchCustomUrl fonksiyonu da muhtemelen url_launcher kullanıyordur.
void launchCustomUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('URL açılamıyor')));
  }
}

class FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullscreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
      ),
    );
  }
}

class CustomOverlayAutocomplete extends StatefulWidget {
  final List<String> options;
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onSelected;

  const CustomOverlayAutocomplete({
    required this.options,
    required this.controller,
    required this.focusNode,
    required this.onSelected,
    super.key,
  });

  @override
  State<CustomOverlayAutocomplete> createState() =>
      _CustomOverlayAutocompleteState();
}

class _CustomOverlayAutocompleteState extends State<CustomOverlayAutocomplete> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<String> _filteredOptions = [];

  void _openOverlay() {
    _closeOverlay();
    _filteredOptions = _getFilteredOptions(widget.controller.text);
    _overlayEntry = _createOverlay();
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  List<String> _getFilteredOptions(String query) {
    if (query.length < 2) return [];
    return widget.options
        .where((o) => o.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  OverlayEntry _createOverlay() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    const overlayHeight = 200.0;
    final spaceBelow =
        screenHeight - position.dy - size.height - keyboardHeight;
    final spaceAbove = position.dy;

    // Tercihe göre yukarı ya da aşağı göster
    final showAbove = spaceBelow < overlayHeight && spaceAbove > overlayHeight;

    final top =
        showAbove
            ? position.dy - overlayHeight
            : position.dy - overlayHeight + 40;

    return OverlayEntry(
      builder:
          (context) => Positioned(
            left: position.dx,
            top: top,
            width: size.width,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: overlayHeight),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children:
                      _filteredOptions.map((option) {
                        return ListTile(
                          title: Text(option),
                          onTap: () {
                            widget.onSelected(option);
                            widget.controller.text = option;
                            widget
                                .controller
                                .selection = TextSelection.fromPosition(
                              TextPosition(offset: option.length),
                            );
                            _closeOverlay();
                          },
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (widget.focusNode.hasFocus) {
        _openOverlay();
      } else {
        _closeOverlay();
      }
    });
    widget.controller.addListener(() {
      if (widget.focusNode.hasFocus) {
        _openOverlay();
      }
    });
  }

  @override
  void dispose() {
    _closeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        decoration: InputDecoration(
          hintText: 'Mesaj yaz...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.blue[400]),
        ),
        style: TextStyle(color: Colors.blue[900]),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Oynatıcı')),
      backgroundColor: Colors.black,
      body: Center(
        child:
            _initialized
                ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      VideoPlayer(_controller),
                      VideoProgressIndicator(_controller, allowScrubbing: true),
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.black54,
                          onPressed: () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                          },
                          child: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.grey[300],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                : const CircularProgressIndicator(),
      ),
    );
  }
}
