import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class PaylasimlarScreen extends StatefulWidget {
  const PaylasimlarScreen({super.key});

  @override
  State<PaylasimlarScreen> createState() => _PaylasimlarScreenState();
}

class _PaylasimlarScreenState extends State<PaylasimlarScreen> {
  String? _kullaniciRol;
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

  @override
  void initState() {
    super.initState();
    _kullaniciRolGetir();
  }

  void _kullaniciRolGetir() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
    setState(() {
      _kullaniciRol = userDoc.data()?['role'];
    });
  }

  Future<String> _uploadToSupabase(File file, String pathPrefix) async {
    final supabase = Supabase.instance.client;
    final fileName =
        "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
    final path = "$pathPrefix/$fileName";

    await supabase.storage.from('kuyumcu').upload(path, file);
    return supabase.storage.from('kuyumcu').getPublicUrl(path);
  }

  void _yeniPaylasimEkle() async {
    String baslik = "";
    String metin = "";
    List<File> medyaList = [];
    File? belge;
    String? medyaPreviewPath;
    String? belgeName;

    // Autocomplete için controller ve focus node
    final metinController = TextEditingController();
    final metinFocusNode = FocusNode();

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: StatefulBuilder(
              builder: (context, setState) {
                return SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Yeni Paylaşım",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextField(
                        decoration: const InputDecoration(labelText: "Başlık"),
                        onChanged: (value) => baslik = value,
                      ),

                      // İşte autocomplete metin alanı burada
                      CustomOverlayAutocomplete(
                        options: kaynaklar,
                        controller: metinController,
                        focusNode: metinFocusNode,
                        onSelected: (value) {
                          metin = value;
                        },
                      ),

                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final izinVar = await _isteMedyaIzni();
                          if (!izinVar) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Medya seçmek için depolama izni gerekli.")),
                            );
                            return;
                          }

                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['jpg','jpeg','png','gif','mp4','mov','webm'],
                            allowMultiple: true,
                          );

                          if (result != null) {
                            medyaList = result.paths.whereType<String>().map((p) => File(p)).toList();
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: const Text("Medya Seç", style: TextStyle(color: Colors.blue),),
                      ),
                      if (medyaList.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: medyaList.map((file) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  file,
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.cover,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final izinVar = await _isteBelgeIzni();

                          if (!izinVar) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Belge seçmek için dosya erişim izni gerekli."),
                              ),
                            );
                            return;
                          }

                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                          );

                          if (result != null) {
                            belge = File(result.files.single.path!);
                            setState(() {
                              belgeName = belge!.path.split('/').last;
                            });
                          }
                        },
                        icon: const Icon(Icons.attach_file),
                        label: const Text("Belge Seç", style: TextStyle(color: Colors.blue),),
                      ),

                      if (belgeName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  belgeName!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue, // Yazı rengini mavi yapar
                            ),
                            child: const Text("İptal"),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              // Metin controller'dan alınmalı
                              metin = metinController.text;

                              String? belgeUrl;
                              List<String> medyaUrls = [];

                              final safeBaslik = baslik.replaceAll(' ', '_');
                              final currentUser = FirebaseAuth.instance.currentUser;
                              if (currentUser == null) return;

                              for (int i = 0; i < medyaList.length; i++) {
                                final file = medyaList[i];
                                final url = await _uploadToSupabase(
                                  file,
                                  'paylasimlar/$safeBaslik/img_$i',
                                );
                                if (url != null) medyaUrls.add(url);
                              }

                              if (belge != null) {
                                belgeUrl = await _uploadToSupabase(
                                  belge!,
                                  'paylasimlar/$safeBaslik',
                                );
                              }

                              final userDoc = await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUser.uid)
                                  .get();

                              final kullaniciAdi =
                                  userDoc.data()?['name'] ?? 'Bilinmeyen Kullanıcı';

                              await FirebaseFirestore.instance
                                  .collection('paylasimlar')
                                  .add({
                                'baslik': baslik,
                                'metin': metin,
                                'medyaUrls': medyaUrls,
                                'belgeUrl': belgeUrl,
                                'belgeName': belgeName,
                                'timestamp': FieldValue.serverTimestamp(),
                                'kullaniciAdi': kullaniciAdi,
                              });

                              if (mounted) Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.blue, // Yazı ve ikon rengini mavi yapar
                            ),
                            child: const Text("Paylaş"),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<bool> _isteMedyaIzni() async {
    if (Platform.isAndroid) {
      final androidVersion = (await DeviceInfoPlugin().androidInfo).version.sdkInt;

      if (androidVersion >= 33) {
        // Android 13 ve sonrası için
        final photosStatus = await Permission.photos.request();
        final videosStatus = await Permission.videos.request();
        return photosStatus.isGranted && videosStatus.isGranted;
      } else {
        // Android 12 ve öncesi için
        final storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      }
    }
    return true; // iOS için her zaman true döndür
  }

  Future<bool> _isteBelgeIzni() async {
    if (Platform.isAndroid) {
      final androidVersion = (await DeviceInfoPlugin().androidInfo).version.sdkInt;

      if (androidVersion >= 33) {
        return true;
      } else {
        // Android 12 ve öncesi için eski depolama izni yeterli
        final storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      }
    }
    return true; // iOS için her zaman true döndür
  }

  void _paylasimiSilSor(String docId) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Paylaşımı Sil"),
        content: const Text("Bu paylaşımı silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil", style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );

    if (onay == true) {
      await FirebaseFirestore.instance.collection('paylasimlar').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Paylaşım silindi.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Duyurular",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      floatingActionButton: _kullaniciRol == 'parent'
          ? null // Parentlar için FAB gösterme
          : FloatingActionButton(
        onPressed: _yeniPaylasimEkle,
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add, color: Colors.white, size: 28),
        tooltip: "Yeni Paylaşım",
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('paylasimlar')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                strokeWidth: 3,
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final item = docs[index].data() as Map<String, dynamic>;
              final timestamp = (item['timestamp'] as Timestamp?)?.toDate();

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {},
                    onLongPress: _kullaniciRol == 'supervisor'
                        ? () => _paylasimiSilSor(docs[index].id)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.person,
                                    color: Colors.blue[800], size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['kullaniciAdi'] ?? 'Anonim',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (timestamp != null)
                                      Text(
                                        DateFormat(
                                          'dd MMMM yyyy, HH:mm',
                                          'tr_TR',
                                        ).format(timestamp),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item['baslik'] ?? '',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item['metin'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: Colors.blue[800],
                            ),
                          ),
                          if (item['medyaUrls'] != null &&
                              item['medyaUrls'] is List) ...[
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: (item['medyaUrls'] as List).length,
                                itemBuilder: (context, imgIndex) {
                                  final url = (item['medyaUrls'] as List)[imgIndex];
                                  return Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    child: GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => Dialog(
                                            insetPadding: const EdgeInsets.all(20),
                                            backgroundColor: Colors.transparent,
                                            child: InteractiveViewer(
                                              child: Image.network(
                                                url,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          url,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (item['belgeUrl'] != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue[100]!,
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () async {
                                  final url = Uri.parse(item['belgeUrl']);
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text("Dosya açılamadı."),
                                        backgroundColor: Colors.red[400],
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.insert_drive_file,
                                        color: Colors.blue[800],
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['belgeName'] ?? 'Belge',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[900],
                                            ),
                                          ),
                                          Text(
                                            'Dosyayı görüntüle',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.blue[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.blue[700],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
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
  State<CustomOverlayAutocomplete> createState() => _CustomOverlayAutocompleteState();
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
    final spaceBelow = screenHeight - position.dy - size.height - keyboardHeight;
    final spaceAbove = position.dy;

    // Tercihe göre yukarı ya da aşağı göster
    final showAbove = spaceBelow < overlayHeight && spaceAbove > overlayHeight;

    final top = showAbove
        ? position.dy - overlayHeight
        : position.dy - overlayHeight + 40;

    return OverlayEntry(
      builder: (context) => Positioned(
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
              children: _filteredOptions.map((option) {
                return ListTile(
                  title: Text(option),
                  onTap: () {
                    widget.onSelected(option);
                    widget.controller.text = option;
                    widget.controller.selection = TextSelection.fromPosition(
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
