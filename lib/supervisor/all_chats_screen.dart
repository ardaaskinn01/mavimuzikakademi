// all_chats_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chat_screen.dart';

class ChatLogPage extends StatefulWidget {
  const ChatLogPage({super.key});

  @override
  State<ChatLogPage> createState() => _ChatLogPageState();
}

class _ChatLogPageState extends State<ChatLogPage> {
  String searchQuery = '';
  Map<String, String?> userNames = {};
  final _key = encrypt.Key.fromUtf8('mkqcjwefsxgerbwhxmmlfnfdqrjbbadb');
  final _iv = encrypt.IV.fromUtf8('1234567890123456');
  late final encrypt.Encrypter _encrypter;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;
  late Stream<Duration> _positionStream;
  late Stream<Duration?> _durationStream;
  late Stream<bool> _playingStream;

  @override
  void initState() {
    super.initState();
    _encrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.cbc),
    );
    _initAudioPlayer();
    _fetchUserNames();
  }

  void _initAudioPlayer() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _positionStream = _audioPlayer.positionStream;
    _durationStream = _audioPlayer.durationStream;
    _playingStream = _audioPlayer.playingStream;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchUserNames() async {
    final chatDocs = await FirebaseFirestore.instance.collection('chats').get();
    final userIds = chatDocs.docs.map((doc) => doc.id.split('_')).expand((ids) => ids).toSet().toList();

    for (var userId in userIds) {
      if (!userNames.containsKey(userId)) {
        await getUserName(userId);
      }
    }
    setState(() {});
  }

  bool isAudioFile(String url) {
    return url.endsWith('.mp3') ||
        url.endsWith('.wav') ||
        url.endsWith('.m4a') ||
        url.endsWith('.aac') ||
        url.endsWith('.ogg');
  }

  Future<String?> getUserName(String userId) async {
    if (userNames.containsKey(userId)) {
      return userNames[userId];
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        final name = doc.data()?['name'];
        if (name != null && name.isNotEmpty) {
          userNames[userId] = name;
          return name;
        }
      }
      return null; // Kullanıcı bulunamazsa null döndür
    } catch (e) {
      print("Error fetching user name: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tüm Sohbetler',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Sohbetlerde ara',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').snapshots(),
              builder: (context, chatSnapshot) {
                if (!chatSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chatDocs = chatSnapshot.data!.docs;

                return ListView.builder(
                  itemCount: chatDocs.length,
                  itemBuilder: (context, index) {
                    final chatDoc = chatDocs[index];
                    final chatRoomId = chatDoc.id;
                    final users = chatRoomId.split('_');
                    final user1Id = users[0];
                    final user2Id = users[1];

                    return FutureBuilder<List<String?>>(
                      future: Future.wait([
                        getUserName(user1Id),
                        getUserName(user2Id),
                      ]),
                      builder: (context, nameSnapshot) {
                        if (!nameSnapshot.hasData) {
                          return const ListTile(title: Text('Yükleniyor...'));
                        }

                        final names = nameSnapshot.data!;
                        final user1Name = names[0];
                        final user2Name = names[1];

                        if (user1Name == null || user2Name == null) {
                          // Eğer kullanıcılardan biri bulunamazsa bu sohbeti gösterme
                          return const SizedBox.shrink();
                        }

                        // Arama filtresi
                        if (searchQuery.isNotEmpty) {
                          if (!user1Name.toLowerCase().contains(searchQuery.toLowerCase()) &&
                              !user2Name.toLowerCase().contains(searchQuery.toLowerCase())) {
                            return const SizedBox.shrink();
                          }
                        }

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              '$user1Name & $user2Name', // Hata bu satırda düzeltildi
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onTap: () {
                              final currentUser = FirebaseAuth.instance.currentUser;
                              if (currentUser == null) return;

                              final isSupervisorsChat = user1Id == currentUser.uid || user2Id == currentUser.uid;

                              String otherUserId = user1Id;
                              if (user1Id == currentUser.uid) {
                                otherUserId = user2Id;
                              } else if (user2Id == currentUser.uid) {
                                otherUserId = user1Id;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    receiverId: otherUserId,
                                    isReadOnly: !isSupervisorsChat,
                                    chatParticipants: [user1Id, user2Id],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> _toggleAudioPlayback(String audioUrl) async {
    if (_currentlyPlayingUrl == audioUrl && _audioPlayer.playing) {
      await _audioPlayer.pause();
      setState(() => _currentlyPlayingUrl = null);
    } else {
      if (_currentlyPlayingUrl != audioUrl) {
        await _audioPlayer.setUrl(audioUrl);
      }
      await _audioPlayer.play();
      setState(() => _currentlyPlayingUrl = audioUrl);
    }
  }

  Widget _buildAudioMessage(String audioUrl) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<bool>(
              stream: _playingStream,
              builder: (context, playingSnapshot) {
                final isPlaying = playingSnapshot.data ?? false;
                final isCurrentAudio = _currentlyPlayingUrl == audioUrl;

                return IconButton(
                  icon: Icon(
                    isCurrentAudio && isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
                  onPressed: () => _toggleAudioPlayback(audioUrl),
                );
              },
            ),
            Expanded(
              child: StreamBuilder<Duration?>(
                stream: _durationStream,
                builder: (context, durationSnapshot) {
                  final duration = durationSnapshot.data ?? Duration.zero;
                  return StreamBuilder<Duration>(
                    stream: _positionStream,
                    builder: (context, positionSnapshot) {
                      var position = positionSnapshot.data ?? Duration.zero;
                      if (position > duration) position = duration;
                      return LinearProgressIndicator(
                        value: duration.inMilliseconds > 0
                            ? position.inMilliseconds / duration.inMilliseconds
                            : 0,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        StreamBuilder<Duration?>(
          stream: _durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            return StreamBuilder<Duration>(
              stream: _positionStream,
              builder: (context, positionSnapshot) {
                var position = positionSnapshot.data ?? Duration.zero;
                if (position > duration) position = duration;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position)),
                    Text(_formatDuration(duration)),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}