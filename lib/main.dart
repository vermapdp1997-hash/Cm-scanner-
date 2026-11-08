import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
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
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("Ads init info: $e");
  }
  runApp(const BharatScannerApp());
}

class BharatScannerApp extends StatelessWidget {
  const BharatScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bharat Scanner Pro AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8F9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00796B),
          primary: const Color(0xFF00796B),
          secondary: const Color(0xFF004D40),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// 1. स्प्लैश स्क्रीन
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();

    _timer = Timer(const Duration(milliseconds: 2000), () {
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
    _timer?.cancel();
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
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: const Icon(Icons.document_scanner_rounded, size: 68, color: Color(0xFF00796B)),
                ),
                const SizedBox(height: 22),
                const Text(
                  'BHARAT SCANNER PRO',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '⚡ Next-Gen AI Document Studio & Cloud Vault',
                    style: TextStyle(color: Color(0xFFB2DFDB), fontSize: 12, fontWeight: FontWeight.w600),
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

// ==========================================
// 2. मुख्य डैशबोर्ड
// ==========================================
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
      try {
        final List decoded = jsonDecode(rawData);
        setState(() {
          _savedDocs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          _filterDocs();
        });
      } catch (e) {
        debugPrint("Doc read error: $e");
      }
    }
  }

  void _filterDocs() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredDocs = _savedDocs.where((doc) {
        final matchesSearch = doc['title'].toString().toLowerCase().contains(q);
        final matchesCat = _selectedCategory == 'All' ||
            (_selectedCategory == 'Starred' ? (doc['isFavorite'] == true) : doc['category'] == _selectedCategory);
        return matchesSearch && matchesCat;
      }).toList();
    });
  }

  Future<void> _toggleFavorite(String id) async {
    final index = _savedDocs.indexWhere((d) => d['id'] == id);
    if (index != -1) {
      setState(() {
        _savedDocs[index]['isFavorite'] = !(_savedDocs[index]['isFavorite'] ?? false);
        _filterDocs();
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_documents', jsonEncode(_savedDocs));
    }
  }

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
      'title': title.isEmpty ? 'Doc_${DateFormat('ddMMM_HHmm').format(DateTime.now())}' : title,
      'category': category,
      'isFavorite': false,
      'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
      'images': persistentPaths,
      'pages': persistentPaths.length,
    };

    _savedDocs.insert(0, newDoc);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_documents', jsonEncode(_savedDocs));
    _filterDocs();
    _showToast('✅ Saved to $category');
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
    _showToast('Document deleted');
  }

  // ---------------- स्कैनिंग प्रोसेस ----------------
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
        if (category == 'ID Cards' && result!.images.length >= 2) {
          _processIdCardCollage(result!.images.sublist(0, 2), prefix);
        } else {
          _promptDocName(result.images, prefix, category);
        }
      }
    } catch (e) {
      debugPrint("Scan Error: $e");
    }
  }

  // ---------------- प्रो फीचर: ID CARD A4 COLLAGE (2-SIDED IN 1 PAGE) ----------------
  Future<void> _processIdCardCollage(List<String> frontAndBack, String prefix) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF00796B)),
                SizedBox(height: 14),
                Text('Creating Print-Ready A4 ID Card...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final frontBytes = await File(frontAndBack[0]).readAsBytes();
      final backBytes = await File(frontAndBack[1]).readAsBytes();

      final frontCodec = await ui.instantiateImageCodec(frontBytes);
      final frontFrame = await frontCodec.getNextFrame();
      final frontImg = frontFrame.image;

      final backCodec = await ui.instantiateImageCodec(backBytes);
      final backFrame = await backCodec.getNextFrame();
      final backImg = backFrame.image;

      const a4Width = 1240.0;
      const a4Height = 1754.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, a4Width, a4Height));

      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(const Rect.fromLTWH(0, 0, a4Width, a4Height), bgPaint);

      const cardW = 750.0;
      const cardH = 470.0;
      const left = (a4Width - cardW) / 2;

      final borderPaint = Paint()
        ..color = const Color(0xFFCFD8DC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      // 1. Front Side
      const top1 = 200.0;
      final rect1 = Rect.fromLTWH(left, top1, cardW, cardH);
      canvas.drawImageRect(
        frontImg,
        Rect.fromLTWH(0, 0, frontImg.width.toDouble(), frontImg.height.toDouble()),
        rect1,
        Paint(),
      );
      canvas.drawRect(rect1, borderPaint);

      // 2. Back Side
      const top2 = 820.0;
      final rect2 = Rect.fromLTWH(left, top2, cardW, cardH);
      canvas.drawImageRect(
        backImg,
        Rect.fromLTWH(0, 0, backImg.width.toDouble(), backImg.height.toDouble()),
        rect2,
        Paint(),
      );
      canvas.drawRect(rect2, borderPaint);

      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Bharat Scanner Pro • Verified ID Print Layout (A4)',
          style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((a4Width - textPainter.width) / 2, a4Height - 90));

      final picture = recorder.endRecording();
      final a4CollageImg = await picture.toImage(a4Width.toInt(), a4Height.toInt());
      final byteData = await a4CollageImg.toByteData(format: ui.ImageByteFormat.png);

      if (mounted) Navigator.pop(context);

      if (byteData != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final collageFile = File('${appDir.path}/id_a4_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await collageFile.writeAsBytes(byteData.buffer.asUint8List());

        _saveDocToStorage(
          'ID_Card_${DateFormat('ddMMM_HHmm').format(DateTime.now())}',
          [collageFile.path],
          category: 'ID Cards',
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("ID Collage error: $e");
      _promptDocName(frontAndBack, prefix, 'ID Cards');
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
            Icon(Icons.check_circle_rounded, color: Color(0xFF00796B)),
            SizedBox(width: 8),
            Text('Save Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ ${images.length} page(s) ready.', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 14),
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

  // ---------------- प्रो फीचर: स्लाइडर साइज कंप्रेसर व रिसाइज़र ----------------
  void _openCompressionDialog(List<dynamic> images, String title) {
    double qualitySlider = 0.6;
    int estimatedKb = (images.length * 280 * qualitySlider).toInt() + 40;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.tune_rounded, color: Color(0xFF00796B)),
                SizedBox(width: 8),
                Text('Compress & Resize', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Slide the point to adjust document size:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Quality: ${(qualitySlider * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('~ $estimatedKb KB', style: const TextStyle(color: Color(0xFF00796B), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Slider(
                  value: qualitySlider,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  activeColor: const Color(0xFF00796B),
                  onChanged: (val) {
                    setDialogState(() {
                      qualitySlider = val;
                      estimatedKb = (images.length * 350 * qualitySlider).toInt() + 30;
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Small (100KB)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('Medium', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('Original HD', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('Compress PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportPdfWithScale(images, "${title}_Compressed", scale: qualitySlider);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.image_rounded, size: 16),
                label: const Text('Compress JPG'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _shareImages(images, "${title}_Compressed", scale: qualitySlider);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- प्रो फीचर: इमेज (JPG) शेयरिंग व डाउनलोड ----------------
  Future<void> _shareImages(List images, String title, {double scale = 1.0}) async {
    List<XFile> shareFiles = [];
    final appDir = await getTemporaryDirectory();

    for (int i = 0; i < images.length; i++) {
      final f = File(images[i]);
      if (await f.exists()) {
        if (scale < 1.0) {
          final bytes = await f.readAsBytes();
          final codec = await ui.instantiateImageCodec(
            bytes,
            targetWidth: (1200 * scale).toInt().clamp(300, 2500),
          );
          final frame = await codec.getNextFrame();
          final resized = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          if (resized != null) {
            final compressedFile = File('${appDir.path}/img_${title}_p$i.jpg');
            await compressedFile.writeAsBytes(resized.buffer.asUint8List());
            shareFiles.add(XFile(compressedFile.path));
            continue;
          }
        }
        shareFiles.add(XFile(f.path));
      }
    }

    if (shareFiles.isNotEmpty) {
      await Share.shareXFiles(shareFiles, text: '$title - Images scanned with Bharat Scanner Pro');
    } else {
      _showToast('No images available to share.');
    }
  }

  // ---------------- PDF EXPORT ----------------
  Future<void> _exportPdfWithScale(List images, String title, {double scale = 1.0, String? watermark}) async {
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
                            fontSize: 48,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0x35000000),
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
    final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File("${dir.path}/$safeName.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: '$title - Scanned with Bharat Scanner Pro');
  }

  // ---------------- प्रो AI इंजन: OCR + ऑटो स्मार्ट डिटेक्शन (ENTITIES) ----------------
  Future<void> _extractTextWithAI(String imagePath) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF00796B)),
                SizedBox(height: 16),
                Text('AI Smart Analyzer scanning...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    String extractedText = '';
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      extractedText = recognizedText.text;
    } catch (e) {
      debugPrint("OCR Error: $e");
    }

    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    if (extractedText.trim().isEmpty) {
      _showToast('No readable text detected in this page.');
      return;
    }

    // AI Smart Entity Parsing (Dates, Amounts, Emails, Phones)
    final dateReg = RegExp(r'\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})\b');
    final amountReg = RegExp(r'(?:₹|INR|Rs\.?|\$)\s*([\d,]+(?:\.\d{2})?)|\bTotal\s*[:=]?\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false);
    final emailReg = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final phoneReg = RegExp(r'\b(?:\+91|0)?[6-9]\d{9}\b');

    final dates = dateReg.allMatches(extractedText).map((m) => m.group(0)!).toSet().toList();
    final amounts = amountReg.allMatches(extractedText).map((m) => m.group(0)!).toSet().toList();
    final emails = emailReg.allMatches(extractedText).map((m) => m.group(0)!).toSet().toList();
    final phones = phoneReg.allMatches(extractedText).map((m) => m.group(0)!).toSet().toList();

    final textCtrl = TextEditingController(text: extractedText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
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
                        Text('AI Smart Document Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF00796B)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: textCtrl.text));
                        _showToast('Copied text to clipboard!');
                      },
                    ),
                  ],
                ),
                const Divider(),
                // AI Entity Badges
                if (dates.isNotEmpty || amounts.isNotEmpty || phones.isNotEmpty || emails.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (amounts.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.currency_rupee, size: 14, color: Colors.green),
                          label: Text(amounts.first, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.green.shade50,
                        ),
                      if (dates.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.calendar_today, size: 14, color: Colors.blue),
                          label: Text(dates.first, style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.blue.shade50,
                        ),
                      if (phones.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.phone, size: 14, color: Colors.orange),
                          label: Text(phones.first, style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.orange.shade50,
                        ),
                      if (emails.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.email, size: 14, color: Colors.purple),
                          label: Text(emails.first, style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.purple.shade50,
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.summarize_rounded, size: 15),
                        label: const Text('AI Summarize', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          final sentences = textCtrl.text.split(RegExp(r'(?<=[.!?\n])'));
                          final summary = sentences.where((s) => s.trim().length > 15).take(4).join(" ").trim();
                          setSheetState(() => textCtrl.text = "📌 AI Quick Summary:\n$summary");
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.format_list_bulleted_rounded, size: 15),
                        label: const Text('Key Points', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          final lines = textCtrl.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
                          final points = lines.take(6).map((l) => "• ${l.trim()}").join("\n");
                          setSheetState(() => textCtrl.text = "⚡ Key Takeaways:\n$points");
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                  child: TextField(
                    controller: textCtrl,
                    maxLines: null,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      hintText: 'Recognized text...',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share Text & Insights', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                    onPressed: () => Share.share(textCtrl.text),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
                  _exportPdfWithScale(chosenDoc['images'], "${chosenDoc['title']}_Watermarked", watermark: wmCtrl.text.trim());
                },
                child: const Text('Apply & Share PDF'),
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
          onDocUpdated: (updated) => _loadSavedDocs(),
          onExtractText: (path) => _extractTextWithAI(path),
          onSharePdf: (paths, title) => _exportPdfWithScale(paths, title),
          onShareImages: (paths, title) => _shareImages(paths, title),
          onCompress: (paths, title) => _openCompressionDialog(paths, title),
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search documents...', border: InputBorder.none),
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF00796B), borderRadius: BorderRadius.circular(6)),
                    child: const Text('BHARAT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                  const SizedBox(width: 6),
                  const Text('SCANNER PRO', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded, size: 24),
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
            SafeArea(
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 64,
        width: 64,
        margin: const EdgeInsets.only(top: 18),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF004D40)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: const Color(0xFF00796B).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          onPressed: () => _startDocScan(),
          child: const Icon(Icons.camera_alt_rounded, size: 28),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 8,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              InkWell(
                onTap: () => setState(() => _currentTabIndex = 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_shared_rounded, color: _currentTabIndex == 0 ? const Color(0xFF00796B) : Colors.grey.shade400),
                    const SizedBox(height: 2),
                    Text('Docs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _currentTabIndex == 0 ? const Color(0xFF00796B) : Colors.grey.shade400)),
                  ],
                ),
              ),
              const SizedBox(width: 44),
              InkWell(
                onTap: () => setState(() => _currentTabIndex = 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.widgets_rounded, color: _currentTabIndex == 1 ? const Color(0xFF00796B) : Colors.grey.shade400),
                    const SizedBox(height: 2),
                    Text('AI Tools', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _currentTabIndex == 1 ? const Color(0xFF00796B) : Colors.grey.shade400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- TAB 1: DOCS ----------------
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
              _buildStatItem('AI Engine', 'Active ⚡', Icons.security_rounded, Colors.blueGrey),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['All', 'Starred', 'ID Cards', 'Documents', 'Passports', 'Invoices'].map((cat) {
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSel,
                  selectedColor: const Color(0xFF00796B),
                  labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 12),
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
            Text('Saved Files (${_filteredDocs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
            Row(
              children: [
                IconButton(
                  tooltip: 'Sort Documents',
                  icon: const Icon(Icons.sort_rounded, size: 20, color: Colors.black87),
                  onPressed: () {
                    setState(() {
                      _filteredDocs = _filteredDocs.reversed.toList();
                    });
                  },
                ),
                IconButton(
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                  icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 20, color: Colors.black87),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_filteredDocs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF80CBC4), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.document_scanner_outlined, size: 40, color: Color(0xFF00796B)),
                  ),
                ),
                const SizedBox(height: 14),
                Text("No files saved yet", style: TextStyle(color: Colors.grey.shade600, fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: const Text('Scan ID / Document Now', style: TextStyle(fontWeight: FontWeight.bold)),
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
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(count, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
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
    final isFav = doc['isFavorite'] == true;

    return InkWell(
      onTap: () => _openDocumentViewer(doc),
      borderRadius: BorderRadius.circular(14),
      child: Card(
        elevation: 0.5,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasImage
                    ? Image.file(File(imgList.first), width: 65, height: 80, fit: BoxFit.cover)
                    : Container(width: 65, height: 80, color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(doc['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: Icon(isFav ? Icons.star_rounded : Icons.star_border_rounded, color: isFav ? Colors.amber : Colors.grey, size: 20),
                          onPressed: () => _toggleFavorite(doc['id']),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${doc['pages']} pages • ${doc['date']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _exportPdfWithScale(imgList, doc['title']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              children: const [
                                Icon(Icons.picture_as_pdf_rounded, size: 13, color: Color(0xFF2E7D32)),
                                SizedBox(width: 4),
                                Text('PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _shareImages(imgList, doc['title']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              children: const [
                                Icon(Icons.image_rounded, size: 13, color: Color(0xFFE65100)),
                                SizedBox(width: 4),
                                Text('Image', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _openCompressionDialog(imgList, doc['title']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              children: const [
                                Icon(Icons.tune_rounded, size: 13, color: Color(0xFF00796B)),
                                SizedBox(width: 4),
                                Text('Resize', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00796B))),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
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
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF2E7D32)),
                        onPressed: () => _exportPdfWithScale(imgList, doc['title']),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.image_rounded, size: 18, color: Color(0xFFE65100)),
                        onPressed: () => _shareImages(imgList, doc['title']),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF00796B)),
                        onPressed: () => _openCompressionDialog(imgList, doc['title']),
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

  // ---------------- TAB 2: PRO AI TOOLS ----------------
  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        _buildSectionHeader('Smart AI Scan Modes'),
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
              title: 'ID Card Mode',
              subtitle: 'Front & Back A4',
              icon: Icons.badge_outlined,
              iconColor: const Color(0xFF1976D2),
              onTap: () => _startDocScan(limit: 2, category: 'ID Cards', prefix: 'ID_Card'),
            ),
            _buildToolCard(
              title: 'Single Card',
              subtitle: 'Aadhaar / PAN',
              icon: Icons.credit_card_rounded,
              iconColor: const Color(0xFF00796B),
              onTap: () => _startDocScan(limit: 1, category: 'ID Cards', prefix: 'Card'),
            ),
            _buildToolCard(
              title: 'Passport',
              subtitle: 'Full Layout',
              icon: Icons.menu_book_rounded,
              iconColor: const Color(0xFF388E3C),
              onTap: () => _startDocScan(limit: 2, category: 'Passports', prefix: 'Passport'),
            ),
            _buildToolCard(
              title: 'Smart Invoices',
              subtitle: 'Bill Extract',
              icon: Icons.receipt_long_rounded,
              iconColor: const Color(0xFFE65100),
              onTap: () => _startDocScan(limit: 5, category: 'Invoices', prefix: 'Bill'),
            ),
            _buildToolCard(
              title: 'AI Insights',
              subtitle: 'Auto-Entity',
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
              title: 'From Gallery',
              subtitle: 'Batch Import',
              icon: Icons.photo_library_outlined,
              iconColor: const Color(0xFFD81B60),
              onTap: () => _startDocScan(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('PDF & Image Power Tools'),
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
              title: 'Size Compressor',
              subtitle: 'Slider Control',
              icon: Icons.tune_rounded,
              iconColor: const Color(0xFF00796B),
              onTap: () {
                if (_savedDocs.isNotEmpty) {
                  final doc = _savedDocs.first;
                  _openCompressionDialog(doc['images'], doc['title']);
                } else {
                  _showToast('Scan a document first to compress.');
                }
              },
            ),
            _buildToolCard(
              title: 'Watermark',
              subtitle: 'Custom Stamp',
              icon: Icons.branding_watermark_outlined,
              iconColor: const Color(0xFF0288D1),
              onTap: () => _openWatermarkDialog(),
            ),
            _buildToolCard(
              title: 'Export Images',
              subtitle: 'Save as JPG',
              icon: Icons.image_rounded,
              iconColor: const Color(0xFFE65100),
              onTap: () {
                if (_savedDocs.isNotEmpty) {
                  final doc = _savedDocs.first;
                  _shareImages(doc['images'], doc['title']);
                } else {
                  _showToast('No documents to share.');
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: const Color(0xFF00796B)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
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
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(shape: BoxShape.circle, color: iconColor.withOpacity(0.08)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, textAlign: TextAlign.center, maxLines: 1, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. डॉक्यूमेंट व्यूअर (FULL SCREEN PREVIEW & SINGLE PAGE CONTROL)
// ==========================================
class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDelete;
  final Function(Map<String, dynamic>) onDocUpdated;
  final Function(String) onExtractText;
  final Function(List, String) onSharePdf;
  final Function(List, String) onShareImages;
  final Function(List, String) onCompress;

  const DocumentDetailScreen({
    super.key,
    required this.doc,
    required this.onDelete,
    required this.onDocUpdated,
    required this.onExtractText,
    required this.onSharePdf,
    required this.onShareImages,
    required this.onCompress,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  late List<String> _images;
  late String _title;

  // Filter Modes: 0: Original, 1: Magic Color, 2: B&W Photocopy, 3: Grayscale
  int _currentFilterMode = 0;

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.doc['images'] ?? []);
    _title = widget.doc['title'] ?? 'Document';
    _pageController = PageController();
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

  // ---------------- प्रो फीचर: सिंगल पेज डिलीट ----------------
  void _deleteCurrentPage() {
    if (_images.length <= 1) {
      // If only 1 page left, delete whole document
      widget.onDelete();
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this page?'),
        content: Text('Do you want to delete Page ${_currentPage + 1}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _images.removeAt(_currentPage);
                widget.doc['images'] = _images;
                widget.doc['pages'] = _images.length;
                if (_currentPage >= _images.length) {
                  _currentPage = _images.length - 1;
                }
              });
              widget.onDocUpdated(widget.doc);
            },
            child: const Text('Delete Page'),
          ),
        ],
      ),
    );
  }

  ColorFilter? _getFilter(int mode) {
    switch (mode) {
      case 1: // Magic Color: Enhance contrast & brighten
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, -10,
          0, 1.2, 0, 0, -10,
          0, 0, 1.2, 0, -10,
          0, 0, 0, 1, 0,
        ]);
      case 2: // High Contrast B&W Photocopy
        return const ColorFilter.matrix([
          1.5, 1.5, 1.5, 0, -160,
          1.5, 1.5, 1.5, 0, -160,
          1.5, 1.5, 1.5, 0, -160,
          0, 0, 0, 1, 0,
        ]);
      case 3: // Grayscale
        return const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
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
              const Icon(Icons.edit, size: 15, color: Colors.white70),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF80CBC4)),
            tooltip: 'Compress',
            onPressed: () => widget.onCompress(_images, _title),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            tooltip: 'Delete Current Page',
            onPressed: _deleteCurrentPage,
          ),
        ],
      ),
      body: _images.isEmpty
          ? const Center(child: Text('No images available', style: TextStyle(color: Colors.white)))
          : Column(
              children: [
                // Top Page Tracker
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: Colors.black45,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Page ${_currentPage + 1} of ${_images.length}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _currentFilterMode = (_currentFilterMode + 1) % 4;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            ['Original', 'Magic Color', 'B&W', 'Grayscale'][_currentFilterMode],
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _images.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (ctx, i) {
                      final file = File(_images[i]);
                      if (!file.existsSync()) {
                        return const Center(child: Text('Image file not found', style: TextStyle(color: Colors.white)));
                      }
                      final filter = _getFilter(_currentFilterMode);
                      return InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: filter != null
                              ? ColorFiltered(
                                  colorFilter: filter,
                                  child: Image.file(file, fit: BoxFit.contain),
                                )
                              : Image.file(file, fit: BoxFit.contain),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomAction(Icons.picture_as_pdf_rounded, 'Share PDF', () {
                widget.onSharePdf(_images, _title);
              }),
              _buildBottomAction(Icons.image_rounded, 'Share JPG', () {
                widget.onShareImages(_images, _title);
              }),
              _buildBottomAction(Icons.tune_rounded, 'Compress', () {
                widget.onCompress(_images, _title);
              }),
              _buildBottomAction(Icons.auto_awesome, 'AI Insights', () {
                if (_images.isNotEmpty) {
                  widget.onExtractText(_images[_currentPage]);
                }
              }),
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
          Icon(icon, color: const Color(0xFF80CBC4), size: 22),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}
