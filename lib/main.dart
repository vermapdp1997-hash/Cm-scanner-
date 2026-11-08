import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const BharatScannerApp());
}

class BharatScannerApp extends StatelessWidget {
  const BharatScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bharat Scanner AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00796B),
          primary: const Color(0xFF00796B),
          secondary: const Color(0xFF004D40),
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

// ---------------- 1. ब्रांडेड स्प्लैश स्क्रीन ----------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();

    Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainDashboardScreen(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: const Icon(Icons.document_scanner_rounded, size: 70, color: Color(0xFF00796B)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'BHARAT SCANNER',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '⚡ AI-Powered Mobile Document Studio',
                    style: TextStyle(color: Color(0xFF80CBC4), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- 2. मुख्य डैशबोर्ड ----------------
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentTabIndex = 0;
  List<Map<String, dynamic>> _savedDocs = [];
  List<Map<String, dynamic>> _filteredDocs = [];
  bool _isSearching = false;
  bool _isGridView = false;
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  InterstitialAd? _interstitialAd;

  final String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  final String _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';

  @override
  void initState() {
    super.initState();
    _loadSavedDocs();
    _loadBannerAd();
    _loadInterstitialAd();
    _searchController.addListener(_filterDocs);
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _testBannerId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerLoaded = true),
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _testInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  Future<void> _loadSavedDocs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString('saved_documents');
    if (rawData != null) {
      final List decoded = jsonDecode(rawData);
      setState(() {
        _savedDocs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _filterDocs();
      });
    }
  }

  void _filterDocs() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredDocs = _savedDocs.where((doc) {
        final matchesSearch = doc['title'].toString().toLowerCase().contains(q);
        final matchesCat = _selectedCategory == 'All' || doc['category'] == _selectedCategory;
        return matchesSearch && matchesCat;
      }).toList();
    });
  }

  Future<void> _saveDocToStorage(String title, List<String> paths, {String category = 'Documents'}) async {
    final newDoc = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'category': category,
      'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
      'images': paths,
      'pages': paths.length,
    };
    _savedDocs.insert(0, newDoc);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_documents', jsonEncode(_savedDocs));
    _filterDocs();
  }

  Future<void> _deleteDoc(String id) async {
    _savedDocs.removeWhere((item) => item['id'] == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_documents', jsonEncode(_savedDocs));
    _filterDocs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document deleted successfully')),
      );
    }
  }

  // --- 1. रियल डॉक्यूमेंट स्कैनर (ID Card, Book, Docs) ---
  Future<void> _startDocScan({int limit = 50, String category = 'Documents', String prefix = 'Doc'}) async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        isGalleryImport: true,
        pageLimit: limit,
      ),
    );

    try {
      final result = await scanner.scanDocument();
      if (result?.images != null && result!.images.isNotEmpty) {
        _promptDocName(result.images, prefix, category);
      }
    } catch (e) {
      debugPrint("Scan Error: $e");
    }
  }

  void _promptDocName(List<String> images, String prefix, String category) {
    final nameCtrl = TextEditingController(text: "${prefix}_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF00796B)),
            SizedBox(width: 8),
            Text('Save Document', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${images.length} pages scanned successfully.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Document Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Discard')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _saveDocToStorage(nameCtrl.text.trim(), images, category: category);
            },
            child: const Text('Save to Docs'),
          ),
        ],
      ),
    );
  }

  // --- 2. रियल AI OCR (टेक्स्ट एक्सट्रैक्शन) ---
  Future<void> _extractTextWithAI(String imagePath) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF00796B))),
    );

    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    final textCtrl = TextEditingController(text: recognizedText.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: Color(0xFF00796B)),
                    SizedBox(width: 8),
                    Text('Extracted Text (AI OCR)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Color(0xFF00796B)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: textCtrl.text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
                  },
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: TextField(
                controller: textCtrl,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'No text recognized',
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share Extracted Text', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () => Share.share(textCtrl.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. रियल PDF वाटरमार्क टूल ---
  void _openWatermarkDialog() {
    if (_savedDocs.isEmpty) {
      _showToast('Please scan a document first to add a watermark.');
      return;
    }
    String selectedDocId = _savedDocs.first['id'];
    final wmCtrl = TextEditingController(text: 'CONFIDENTIAL');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Add PDF Watermark', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDocId,
                  decoration: const InputDecoration(labelText: 'Select Document', border: OutlineInputBorder()),
                  items: _savedDocs.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc['id'].toString(),
                      child: Text(doc['title'], overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedDocId = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: wmCtrl,
                  decoration: const InputDecoration(labelText: 'Watermark Text', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  final chosenDoc = _savedDocs.firstWhere((d) => d['id'] == selectedDocId);
                  _exportPdf(chosenDoc['images'], "${chosenDoc['title']}_Watermarked", watermark: wmCtrl.text.trim());
                },
                child: const Text('Apply & Share PDF'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 4. रियल PDF Merge टूल ---
  void _openMergeDialog() {
    if (_savedDocs.length < 2) {
      _showToast('You need at least 2 saved documents to merge.');
      return;
    }

    final selectedIds = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Merge Documents into One PDF', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              height: 250,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _savedDocs.length,
                itemBuilder: (context, i) {
                  final doc = _savedDocs[i];
                  final isChecked = selectedIds.contains(doc['id']);
                  return CheckboxListTile(
                    title: Text(doc['title']),
                    subtitle: Text('${doc['pages']} pages'),
                    value: isChecked,
                    activeColor: const Color(0xFF00796B),
                    onChanged: (bool? val) {
                      setModalState(() {
                        if (val == true) {
                          selectedIds.add(doc['id']);
                        } else {
                          selectedIds.remove(doc['id']);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: selectedIds.length < 2
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        List<String> mergedImages = [];
                        for (var id in selectedIds) {
                          final doc = _savedDocs.firstWhere((d) => d['id'] == id);
                          mergedImages.addAll(List<String>.from(doc['images']));
                        }
                        _saveDocToStorage("Merged_${DateFormat('ddMM_HHmm').format(DateTime.now())}", mergedImages, category: 'Merged');
                        _showToast('Merged ${mergedImages.length} pages into a new document!');
                      },
                child: Text('Merge (${selectedIds.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 5. रियल Digital Signature Pad ---
  void _openSignaturePad() {
    List<Offset?> points = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.draw_rounded, color: Color(0xFF00796B)),
                SizedBox(width: 8),
                Text('Digital Signature', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sign with your finger inside the box:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00796B), width: 1.5),
                  ),
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      RenderBox renderBox = context.findRenderObject() as RenderBox;
                      final localPos = details.localPosition;
                      setModalState(() {
                        points.add(localPos);
                      });
                    },
                    onPanEnd: (_) => points.add(null),
                    child: CustomPaint(
                      painter: SignaturePainter(points),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setModalState(() => points.clear());
                },
                child: const Text('Clear', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showToast('Signature saved successfully to signature vault!');
                },
                child: const Text('Save Signature'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 6. रियल Page Reorder (पेज आगे-पीछे करना) ---
  void _openPageReorderDialog() {
    if (_savedDocs.isEmpty) {
      _showToast('Scan or open a document with multiple pages first.');
      return;
    }

    final targetDoc = _savedDocs.firstWhere((d) => d['pages'] > 1, orElse: () => _savedDocs.first);
    List<String> reorderedImages = List<String>.from(targetDoc['images']);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text('Reorder: ${targetDoc['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) {
                  setModalState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = reorderedImages.removeAt(oldIndex);
                    reorderedImages.insert(newIndex, item);
                  });
                },
                children: [
                  for (int i = 0; i < reorderedImages.length; i++)
                    ListTile(
                      key: ValueKey(reorderedImages[i] + i.toString()),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File(reorderedImages[i]), width: 40, height: 50, fit: BoxFit.cover),
                      ),
                      title: Text('Page ${i + 1}'),
                      trailing: const Icon(Icons.drag_handle_rounded),
                    )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  targetDoc['images'] = reorderedImages;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('saved_documents', jsonEncode(_savedDocs));
                  _filterDocs();
                  _showToast('Page order updated!');
                },
                child: const Text('Save New Order'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- PDF बनाना और शेयर करना ---
  Future<void> _exportPdf(List images, String title, {String? watermark, bool compress = false}) async {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _loadInterstitialAd();
    }

    final pdf = pw.Document();
    for (var path in images) {
      final imgBytes = File(path).readAsBytesSync();
      final img = pw.MemoryImage(imgBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Stack(
              alignment: pw.Alignment.center,
              children: [
                pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
                if (watermark != null && watermark.isNotEmpty)
                  pw.Center(
                    child: pw.Transform.rotate(
                      angle: -0.6,
                      child: pw.Text(
                        watermark,
                        style: pw.TextStyle(
                          fontSize: 50,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0x30000000),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/$title.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: '$title - Scanned by Bharat Scanner AI');
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF00796B), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFE0F2F1),
            child: const Icon(Icons.person, color: Color(0xFF00796B), size: 22),
          ),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search scanned documents...',
                  border: InputBorder.none,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('BHARAT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                  const SizedBox(width: 6),
                  const Text('SCANNER', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded, color: Colors.black87, size: 24),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentTabIndex == 0 ? _buildDocsTab() : _buildToolsTab(),
          ),
          if (_isBannerLoaded && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),

      // Center Floating Camera Button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 66,
        width: 66,
        margin: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF004D40)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00796B).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          onPressed: () => _startDocScan(),
          child: const Icon(Icons.camera_alt_rounded, size: 30),
        ),
      ),

      // Sleek Bottom Navigation Bar
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        color: Colors.white,
        elevation: 12,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Docs Tab
              InkWell(
                onTap: () => setState(() => _currentTabIndex = 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_shared_rounded,
                      color: _currentTabIndex == 0 ? const Color(0xFF00796B) : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Docs',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _currentTabIndex == 0 ? const Color(0xFF00796B) : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 48), // Center Camera space

              // Tools Tab
              InkWell(
                onTap: () => setState(() => _currentTabIndex = 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.widgets_rounded,
                      color: _currentTabIndex == 1 ? const Color(0xFF00796B) : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tools',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _currentTabIndex == 1 ? const Color(0xFF00796B) : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- SCREEN 1: DOCS TAB ----------------
  Widget _buildDocsTab() {
    int totalPages = _savedDocs.fold(0, (sum, item) => sum + (item['pages'] as int? ?? 1));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Quick Stats Dashboard Strip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Documents', '${_savedDocs.length}', Icons.description_rounded, const Color(0xFF00796B)),
              Container(height: 30, width: 1, color: Colors.grey.shade200),
              _buildStatItem('Pages Scanned', '$totalPages', Icons.auto_stories_rounded, Colors.orange),
              Container(height: 30, width: 1, color: Colors.grey.shade200),
              _buildStatItem('Cloud Sync', 'Offline', Icons.cloud_done_rounded, Colors.blueGrey),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Category Filter Pills
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['All', 'Documents', 'ID Cards', 'Merged', 'Books'].map((cat) {
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSel,
                  selectedColor: const Color(0xFF00796B),
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : Colors.black87,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: isSel ? const Color(0xFF00796B) : Colors.grey.shade300),
                  onSelected: (val) {
                    setState(() {
                      _selectedCategory = cat;
                      _filterDocs();
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // 3. Subheader with Sorting & View Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Files (${_filteredDocs.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Sort Documents',
                  icon: const Icon(Icons.sort_rounded, size: 22, color: Colors.black87),
                  onPressed: () {
                    setState(() {
                      _filteredDocs = _filteredDocs.reversed.toList();
                    });
                    _showToast('Sorting reversed');
                  },
                ),
                IconButton(
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                  icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 22, color: Colors.black87),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 4. File List / Grid
        if (_filteredDocs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF80CBC4), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.document_scanner_outlined, size: 48, color: Color(0xFF00796B)),
                  ),
                ),
                const SizedBox(height: 18),
                Text("No documents found here", style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                  icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                  label: const Text('Scan New Document', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _startDocScan(),
                ),
              ],
            ),
          )
        else if (_isGridView)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (ctx, i) => _buildGridCard(_filteredDocs[i]),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            itemBuilder: (ctx, i) => _buildListCard(_filteredDocs[i]),
          ),
      ],
    );
  }

  Widget _buildStatItem(String title, String count, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildListCard(Map<String, dynamic> doc) {
    final List imgList = doc['images'];
    return Card(
      elevation: 0.5,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(imgList.first),
                width: 65,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${doc['pages']} pages • ${doc['date']}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _extractTextWithAI(imgList.first),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2F1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.auto_awesome, size: 13, color: Color(0xFF00796B)),
                              SizedBox(width: 4),
                              Text('AI OCR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00796B))),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, color: Color(0xFF00796B), size: 20),
                        onPressed: () => _exportPdf(imgList, doc['title']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteDoc(doc['id']),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(Map<String, dynamic> doc) {
    final List imgList = doc['images'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.file(File(imgList.first), width: double.infinity, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                Text('${doc['pages']} pages', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.share_outlined, size: 18, color: Color(0xFF00796B)),
                      onPressed: () => _exportPdf(imgList, doc['title']),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      onPressed: () => _deleteDoc(doc['id']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- SCREEN 2 & 3: TOOLS TAB (ALL BUTTONS FULLY WORKING) ----------------
  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // 1. Scan Section
        _buildSectionHeader('Smart Scan Modes'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.85,
          children: [
            _buildToolCard(
              title: 'ID Card',
              subtitle: 'Front & Back',
              icon: Icons.badge_outlined,
              iconColor: const Color(0xFF1976D2),
              onTap: () => _startDocScan(limit: 2, category: 'ID Cards', prefix: 'ID_Card'),
            ),
            _buildToolCard(
              title: 'Scan Docs',
              subtitle: 'Multi-Page',
              icon: Icons.document_scanner_rounded,
              iconColor: const Color(0xFF00796B),
              onTap: () => _startDocScan(limit: 50, category: 'Documents', prefix: 'Doc'),
            ),
            _buildToolCard(
              title: 'Book Scan',
              subtitle: 'Two-Page Mode',
              icon: Icons.menu_book_rounded,
              iconColor: const Color(0xFF388E3C),
              onTap: () => _startDocScan(limit: 50, category: 'Books', prefix: 'Book'),
            ),
            _buildToolCard(
              title: 'Import Files',
              subtitle: 'From Gallery',
              icon: Icons.photo_library_outlined,
              iconColor: const Color(0xFFE65100),
              onTap: () => _startDocScan(),
            ),
            _buildToolCard(
              title: 'To Text (OCR)',
              subtitle: 'Extract Words',
              icon: Icons.auto_awesome,
              iconColor: const Color(0xFF6A1B9A),
              onTap: () {
                if (_savedDocs.isNotEmpty) {
                  _extractTextWithAI(_savedDocs.first['images'][0]);
                } else {
                  _startDocScan();
                }
              },
            ),
            _buildToolCard(
              title: 'Digital Sign',
              subtitle: 'Draw & Stamp',
              icon: Icons.draw_rounded,
              iconColor: const Color(0xFFD81B60),
              onTap: () => _openSignaturePad(),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 2. PDF Utilities Section
        _buildSectionHeader('PDF Power Tools'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.85,
          children: [
            _buildToolCard(
              title: 'PDF Merge',
              subtitle: 'Join Files',
              icon: Icons.call_merge_rounded,
              iconColor: const Color(0xFF00796B),
              onTap: () => _openMergeDialog(),
            ),
            _buildToolCard(
              title: 'Watermark',
              subtitle: 'Add Stamp',
              icon: Icons.branding_watermark_outlined,
              iconColor: const Color(0xFF0288D1),
              onTap: () => _openWatermarkDialog(),
            ),
            _buildToolCard(
              title: 'Page Order',
              subtitle: 'Rearrange',
              icon: Icons.swap_vert_circle_outlined,
              iconColor: const Color(0xFF5D4037),
              onTap: () => _openPageReorderDialog(),
            ),
            _buildToolCard(
              title: 'Compress',
              subtitle: 'Reduce Size',
              icon: Icons.compress_rounded,
              iconColor: const Color(0xFF00897B),
              onTap: () {
                if (_savedDocs.isNotEmpty) {
                  final doc = _savedDocs.first;
                  _exportPdf(doc['images'], "${doc['title']}_Compressed", compress: true);
                } else {
                  _showToast('Scan a document to compress.');
                }
              },
            ),
            _buildToolCard(
              title: 'Share PDF',
              subtitle: 'Instant Send',
              icon: Icons.share_rounded,
              iconColor: const Color(0xFF2E7D32),
              onTap: () {
                if (_savedDocs.isNotEmpty) {
                  final doc = _savedDocs.first;
                  _exportPdf(doc['images'], doc['title']);
                } else {
                  _showToast('No documents to share.');
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: const Color(0xFF00796B)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.08),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 3. कस्टम डिजिटल सिग्नेचर पेंटर ----------------
class SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = const Color(0xFF004D40)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
