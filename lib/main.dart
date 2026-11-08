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
      ),
      home: const SplashScreen(),
    );
  }
}

// ---------------- 1. स्प्लैश स्क्रीन ----------------
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

    Timer(const Duration(milliseconds: 2200), () {
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
                  padding: const EdgeInsets.all(22),
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
                const SizedBox(height: 22),
                const Text(
                  'BHARAT SCANNER',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3),
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

  // स्थायी रूप से तस्वीरें स्टोर करना ताकि वे कभी डिलीट न हों
  Future<List<String>> _copyImagesToPermanentStorage(List<String> tempPaths) async {
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!await scansDir.exists()) {
      await scansDir.create(recursive: true);
    }

    List<String> persistentPaths = [];
    for (int i = 0; i < tempPaths.length; i++) {
      final tempFile = File(tempPaths[i]);
      if (await tempFile.exists()) {
        final fileName = 'doc_${DateTime.now().millisecondsSinceEpoch}_p$i.jpg';
        final savedFile = await tempFile.copy('${scansDir.path}/$fileName');
        persistentPaths.add(savedFile.path);
      }
    }
    return persistentPaths;
  }

  Future<void> _saveDocToStorage(String title, List<String> rawPaths, {String category = 'Documents'}) async {
    final persistentPaths = await _copyImagesToPermanentStorage(rawPaths);

    if (persistentPaths.isEmpty) {
      _showToast('Failed to save scanned images.');
      return;
    }

    final newDoc = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'category': category,
      'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
      'images': persistentPaths,
      'pages': persistentPaths.length,
    };

    _savedDocs.insert(0, newDoc);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_documents', jsonEncode(_savedDocs));
    _filterDocs();
  }

  Future<void> _updateDoc(Map<String, dynamic> updatedDoc) async {
    final index = _savedDocs.indexWhere((d) => d['id'] == updatedDoc['id']);
    if (index != -1) {
      _savedDocs[index] = updatedDoc;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_documents', jsonEncode(_savedDocs));
      _filterDocs();
    }
  }

  Future<void> _deleteDoc(String id) async {
    final docToDelete = _savedDocs.firstWhere((d) => d['id'] == id, orElse: () => {});
    if (docToDelete.isNotEmpty && docToDelete['images'] != null) {
      for (String p in docToDelete['images']) {
        final f = File(p);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    }

    _savedDocs.removeWhere((item) => item['id'] == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_documents', jsonEncode(_savedDocs));
    _filterDocs();
    _showToast('Document deleted successfully');
  }

  // स्कैनर चालू करना
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

  // AI OCR
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

  // फोन के Downloads में सीधे PDF सेव करना
  Future<String?> _savePdfToDeviceStorage(List images, String title) async {
    try {
      final pdf = pw.Document();
      for (var path in images) {
        final f = File(path);
        if (await f.exists()) {
          final imgBytes = await f.readAsBytes();
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context ctx) => pw.Center(child: pw.Image(pw.MemoryImage(imgBytes), fit: pw.BoxFit.contain)),
            ),
          );
        }
      }

      final bytes = await pdf.save();

      Directory? targetDir;
      if (Platform.isAndroid) {
        targetDir = Directory('/storage/emulated/0/Download/BharatScanner');
        if (!await targetDir.exists()) {
          try {
            await targetDir.create(recursive: true);
          } catch (_) {
            targetDir = Directory('/storage/emulated/0/Download');
          }
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savedFile = File('${targetDir.path}/$safeName.pdf');
      await savedFile.writeAsBytes(bytes);

      _showToast('✅ Saved: Download/${savedFile.path.split('/').last}');
      return savedFile.path;
    } catch (e) {
      _showToast('Saving to storage...');
      _exportPdf(images, title);
      return null;
    }
  }

  // PDF शेयर करना
  Future<void> _exportPdf(List images, String title, {String? watermark}) async {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _loadInterstitialAd();
    }

    final pdf = pw.Document();
    for (var path in images) {
      final f = File(path);
      if (await f.exists()) {
        final imgBytes = await f.readAsBytes();
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
    }

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/$title.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: '$title - Scanned by Bharat Scanner AI');
  }

  void _openWatermarkDialog() {
    if (_savedDocs.isEmpty) {
      _showToast('Please scan a document first.');
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
                    : () async {
                        Navigator.pop(ctx);
                        List<String> mergedImages = [];
                        for (var id in selectedIds) {
                          final doc = _savedDocs.firstWhere((d) => d['id'] == id);
                          mergedImages.addAll(List<String>.from(doc['images']));
                        }
                        await _saveDocToStorage(
                          "Merged_${DateFormat('ddMM_HHmm').format(DateTime.now())}",
                          mergedImages,
                          category: 'Merged',
                        );
                        _showToast('Merged into a new document!');
                      },
                child: Text('Merge (${selectedIds.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

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
                onPressed: () => setModalState(() => points.clear()),
                child: const Text('Clear', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showToast('Signature saved successfully!');
                },
                child: const Text('Save Signature'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openDocumentViewer(Map<String, dynamic> doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          doc: doc,
          onDelete: () => _deleteDoc(doc['id']),
          onDocUpdated: (updated) => _updateDoc(updated),
          onExtractText: (path) => _extractTextWithAI(path),
          onSharePdf: (paths, title) => _exportPdf(paths, title),
          onSaveToStorage: (paths, title) => _savePdfToDeviceStorage(paths, title),
        ),
      ),
    );
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
              const SizedBox(width: 48),
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
              _buildStatItem('Total Docs', '${_savedDocs.length}', Icons.description_rounded, const Color(0xFF00796B)),
              Container(height: 30, width: 1, color: Colors.grey.shade200),
              _buildStatItem('Pages Scanned', '$totalPages', Icons.auto_stories_rounded, Colors.orange),
              Container(height: 30, width: 1, color: Colors.grey.shade200),
              _buildStatItem('Storage', 'Saved Locally', Icons.save_rounded, Colors.blueGrey),
            ],
          ),
        ),
        const SizedBox(height: 16),

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
    final List imgList = doc['images'] ?? [];
    final hasImage = imgList.isNotEmpty && File(imgList.first).existsSync();

    return InkWell(
      onTap: () => _openDocumentViewer(doc),
      borderRadius: BorderRadius.circular(14),
      child: Card(
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
                child: hasImage
                    ? Image.file(
                        File(imgList.first),
                        width: 65,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 65,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
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
                          onTap: () => _savePdfToDeviceStorage(imgList, doc['title']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.download_rounded, size: 14, color: Color(0xFF2E7D32)),
                                SizedBox(width: 4),
                                Text('Save PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _extractTextWithAI(imgList.first),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.auto_awesome, size: 13, color: Color(0xFF00796B)),
                                SizedBox(width: 4),
                                Text('OCR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00796B))),
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
      ),
    );
  }

  Widget _buildGridCard(Map<String, dynamic> doc) {
    final List imgList = doc['images'] ?? [];
    final hasImage = imgList.isNotEmpty && File(imgList.first).existsSync();

    return InkWell(
      onTap: () => _openDocumentViewer(doc),
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
                child: hasImage
                    ? Image.file(File(imgList.first), width: double.infinity, fit: BoxFit.cover)
                    : Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image))),
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
                        icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF2E7D32)),
                        onPressed: () => _savePdfToDeviceStorage(imgList, doc['title']),
                      ),
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
      ),
    );
  }

  // ---------------- SCREEN 2 & 3: TOOLS TAB ----------------
  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
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
              title: 'Save to Phone',
              subtitle: 'Download PDF',
              icon: Icons.download_for_offline_rounded,
              iconColor: const Color(0xFF2E7D32),
              onTap: () {
                if (_savedDocs.isNotEmpty) {
                  final doc = _savedDocs.first;
                  _savePdfToDeviceStorage(doc['images'], doc['title']);
                } else {
                  _showToast('Scan a document to save.');
                }
              },
            ),
            _buildToolCard(
              title: 'Share PDF',
              subtitle: 'Instant Send',
              icon: Icons.share_rounded,
              iconColor: const Color(0xFF5E35B1),
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

// ---------------- 3. डॉक्यूमेंट व्यूअर (FULL SCREEN DOCUMENT VIEWER) ----------------
class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDelete;
  final Function(Map<String, dynamic>) onDocUpdated;
  final Function(String) onExtractText;
  final Function(List, String) onSharePdf;
  final Function(List, String) onSaveToStorage;

  const DocumentDetailScreen({
    super.key,
    required this.doc,
    required this.onDelete,
    required this.onDocUpdated,
    required this.onExtractText,
    required this.onSharePdf,
    required this.onSaveToStorage,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  late List<String> _images;
  late String _title;

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.doc['images'] ?? []);
    _title = widget.doc['title'] ?? 'Document';
    _pageController = PageController();
  }

  Future<void> _addMorePages() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        isGalleryImport: true,
        pageLimit: 20,
      ),
    );

    try {
      final result = await scanner.scanDocument();
      if (result?.images != null && result!.images.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final scansDir = Directory('${appDir.path}/scans');

        List<String> newAdded = [];
        for (int i = 0; i < result!.images.length; i++) {
          final tempFile = File(result.images[i]);
          if (await tempFile.exists()) {
            final fileName = 'doc_${DateTime.now().millisecondsSinceEpoch}_p$i.jpg';
            final saved = await tempFile.copy('${scansDir.path}/$fileName');
            newAdded.add(saved.path);
          }
        }

        setState(() {
          _images.addAll(newAdded);
          widget.doc['images'] = _images;
          widget.doc['pages'] = _images.length;
        });

        widget.onDocUpdated(widget.doc);
      }
    } catch (e) {
      debugPrint("Add pages error: $e");
    }
  }

  void _renameDoc() {
    final ctrl = TextEditingController(text: _title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _title = ctrl.text.trim();
                widget.doc['title'] = _title;
              });
              widget.onDocUpdated(widget.doc);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: InkWell(
          onTap: _renameDoc,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(_title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit, size: 16, color: Colors.white70),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Add Pages',
            onPressed: _addMorePages,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete',
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
          ),
        ],
      ),
      body: _images.isEmpty
          ? const Center(child: Text('No images available', style: TextStyle(color: Colors.white)))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.black45,
                  child: Center(
                    child: Text(
                      'Page ${_currentPage + 1} of ${_images.length}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _images.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (ctx, i) {
                      final path = _images[i];
                      final file = File(path);
                      if (!file.existsSync()) {
                        return const Center(child: Text('Image file not found', style: TextStyle(color: Colors.white)));
                      }
                      return InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.file(file, fit: BoxFit.contain),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomAction(Icons.download_rounded, 'Save to Phone', () {
                widget.onSaveToStorage(_images, _title);
              }),
              _buildBottomAction(Icons.share_rounded, 'Share PDF', () {
                widget.onSharePdf(_images, _title);
              }),
              _buildBottomAction(Icons.auto_awesome, 'Page OCR', () {
                if (_images.isNotEmpty) {
                  widget.onExtractText(_images[_currentPage]);
                }
              }),
              _buildBottomAction(Icons.add_a_photo_rounded, 'Add Page', _addMorePages),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF80CBC4), size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

// ---------------- 4. डिजिटल सिग्नेचर पेंटर ----------------
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
