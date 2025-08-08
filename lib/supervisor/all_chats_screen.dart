import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

class ChatLogPage extends StatefulWidget {
  const ChatLogPage({super.key});

  @override
  State<ChatLogPage> createState() => _ChatLogPageState();
}

class _ChatLogPageState extends State<ChatLogPage> {
  String searchQuery = '';
  Map<String, String> userNames = {};
  final _key = encrypt.Key.fromUtf8('mkqcjwefsxgerbwhxmmlfnfdqrjbbadb'); // Aynı key
  final _iv = encrypt.IV.fromUtf8('1234567890123456'); // Aynı IV
  late final encrypt.Encrypter _encrypter;

  @override
  void initState() {
    super.initState();
    _fetchUserNames();
    _encrypter = encrypt.Encrypter(encrypt.AES(_key));
  }

  Future<void> _fetchUserNames() async {
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final namesMap = {
      for (var doc in usersSnapshot.docs) doc.id: doc['name'] ?? 'Bilinmeyen'
    };

    setState(() {
      userNames = namesMap.map((key, value) => MapEntry(key, value.toString()));
    });

  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, HH:mm', 'tr_TR').format(date);
  }

  String decryptMessage(String encrypted) {
    try {
      return _encrypter.decrypt64(encrypted, iv: _iv);
    } catch (e) {
      return '[Şifreli Mesaj]';
    }
  }

  void _launchURL(String url) async {
    if (!url.startsWith('http')) url = 'https://$url';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("URL açılamıyor.")),
      );
    }
  }

  bool isUrl(String text) {
    final urlPattern = r'^(https?:\/\/)[\w\-\.]+\.\w{2,}(\/\S*)?$';
    final result = RegExp(urlPattern, caseSensitive: false).hasMatch(text);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesaj Kayıtları',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            )),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      backgroundColor: Colors.blue[50],
      body: Column(
          children: [
      Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
        BoxShadow(
        color: Colors.blue.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 4),
        )],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Mesaj ara...",
          prefixIcon: Icon(Icons.search, color: Colors.blue[700]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          setState(() {
            searchQuery = value.toLowerCase();
          });
        },
      ),
    ),
    ),
    Expanded(
    child: StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
    if (!snapshot.hasData || userNames.isEmpty) {
    return Center(
    child: CircularProgressIndicator(
    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
    ),
    );
    }

    final messages = snapshot.data!.docs;

    final filteredMessages = messages.where((doc) {
    final rawText = (doc['text'] ?? '').toString();
    final decrypted = decryptMessage(rawText);
    return searchQuery.isEmpty || decrypted.toLowerCase().contains(searchQuery);
    }).toList();

    if (filteredMessages.isEmpty) {
    return Center(
    child: Text(
    "Hiç mesaj bulunamadı.",
    style: TextStyle(
    color: Colors.blue[800],
    fontSize: 16,
    ),
    ),
    );
    }

    return ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
    itemCount: filteredMessages.length,
    itemBuilder: (context, index) {
    final doc = filteredMessages[index];
    final senderId = doc['senderId'];
    final receiverId = doc['receiverId'];
    final isFile = doc['isFile'] ?? false;
    final rawText = doc['text'] ?? '';
    final decryptedText = isFile ? "[Dosya gönderildi]" : decryptMessage(rawText);
    final timestamp = doc['timestamp'] as Timestamp?;
    final timeString = timestamp != null
    ? DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(timestamp.toDate())
        : '';

    final senderName = userNames[senderId] ?? senderId;
    final receiverName = userNames[receiverId] ?? receiverId;

    return Container(
    margin: const EdgeInsets.only(bottom: 12),
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
    padding: const EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    children: [
    Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
    color: Colors.blue[50],
    borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(Icons.person,
    color: Colors.blue[700], size: 18),
    ),
    const SizedBox(width: 8),
    Expanded(
    child: Text(
    "$senderName → $receiverName",
    style: TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.blue[900],
    ),
    ),
    ),
    ],
    ),
    const SizedBox(height: 12),
    if (isFile)
    InkWell(
    onTap: () => _launchURL(decryptedText),
    child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
    color: Colors.blue[50],
    borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
    children: [
    Icon(Icons.insert_drive_file,
    color: Colors.blue[700]),
    const SizedBox(width: 12),
    const Text("Dosyayı Aç",
    style: TextStyle(color: Colors.blue)),
    ],
    ),
    ),
    )
    else if (isUrl(decryptedText))
    InkWell(
    onTap: () => _launchURL(decryptedText),
    child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
    color: Colors.blue[50],
    borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
    decryptedText,
    style: const TextStyle(
    color: Colors.blue,
    decoration: TextDecoration.underline,
    ),
    ),
    ),
    )
    else
    Text(
    decryptedText,
    style: TextStyle(
    color: Colors.blue[800],
    ),
    ),
    const SizedBox(height: 12),
    Text(
    timeString,
    style: TextStyle(
    fontSize: 12,
    color: Colors.blue[600],
    ),
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