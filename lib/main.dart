import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
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

// ============================================================================
// GLOBAL CONTROLLERS & THEME
// ============================================================================
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);
final ValueNotifier<Color> appPrimaryColor = ValueNotifier(const Color(0xFFE91E63));
final ValueNotifier<bool> isHindiLanguage = ValueNotifier(false);

class AppLang {
  static String tr(String key) {
    final bool hi = isHindiLanguage.value;
    final Map<String, List<String>> dict = {
      'docs': ['Documents', 'दस्तावेज़'],
      'tools': ['Studio Tools', 'स्टूडियो टूल्स'],
      'search': ['Search documents...', 'दस्तावेज़ खोजें...'],
      'total_files': ['Total Files', 'कुल फाइलें'],
      'scanned_pages': ['Pages Scanned', 'स्कैन पेज'],
      'new_folder': ['+ New Folder', '+ नया फ़ोल्डर'],
      'save': ['Save Document', 'दस्तावेज़ सेव करें'],
      'cancel': ['Cancel', 'रद्द करें'],
      'create': ['Create', 'बनाएं'],
      'delete': ['Delete', 'हटाएं'],
      'no_docs': ['No documents saved yet', 'अभी तक कोई दस्तावेज़ नहीं है'],
      'scan_now': ['Scan Document Now', 'डॉक्यूमेंट स्कैन करें'],
      'select_all': ['Select All', 'सभी चुनें'],
      'add_more': ['+ Add More Pages', '+ और पेज जोड़ें'],
      'from_gallery': ['Import from Gallery', 'गैलरी से चुनें'],
      'from_camera': ['Scan from Camera', 'कैमरे से स्कैन करें'],
    };
    if (dict.containsKey(key)) {
      return hi ? dict[key]![1] : dict[key]![0];
    }
    return key;
  }
}

// ============================================================================
// ADVANCED BOOK & DOCUMENT FILTER ENGINE WITH DYNAMIC INTENSITY
// ============================================================================
class DocFilterPreset {
  final String id;
  final String title;
  final IconData icon;

  const DocFilterPreset({
    required this.id,
    required this.title,
    required this.icon,
  });

  List<double>? getMatrix(double intensity) {
    // intensity is 0.0 to 1.0 (0.5 is balanced default)
    final factor = 0.5 + (intensity * 1.5); // 0.5 to 2.0 multiplier

    switch (id) {
      case 'magic_book':
        // High-end CamScanner / Adobe Scan book whitener
        final contrast = 1.75 * factor;
        final offset = -48.0 * factor + (intensity * 55.0);
        return [
          contrast, 0.0, 0.0, 0.0, offset,
          0.0, contrast, 0.0, 0.0, offset,
          0.0, 0.0, contrast, 0.0, offset,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];

      case 'bw_sharp':
        // Extreme dark ink & pure paper white for old documents
        final c = 2.9 * factor;
        final off = -370.0 * factor;
        return [
          c, c, c, 0.0, off,
          c, c, c, 0.0, off,
          c, c, c, 0.0, off,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];

      case 'deshadow':
        // Removes shadows caused by mobile or fingers
        final b = 50.0 * factor;
        return [
          1.25, 0.0, 0.0, 0.0, b,
          0.0, 1.25, 0.0, 0.0, b,
          0.0, 0.0, 1.25, 0.0, b,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];

      case 'vibrant_color':
        // High saturation for color IDs, stamps, seals, certificates
        final s = 1.45 * factor;
        return [
          s, -0.12, -0.12, 0.0, -12,
          -0.12, s, -0.12, 0.0, -12,
          -0.12, -0.12, s, 0.0, -12,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];

      case 'greyscale':
        // Clean monochrome
        final g = 1.15 * factor;
        return [
          0.299 * g, 0.587 * g, 0.114 * g, 0.0, 8,
          0.299 * g, 0.587 * g, 0.114 * g, 0.0, 8,
          0.299 * g, 0.587 * g, 0.114 * g, 0.0, 8,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];

      case 'original':
      default:
        return null;
    }
  }
}

final List<DocFilterPreset> kDocFilters = [
  const DocFilterPreset(id: 'original', title: 'Original', icon: Icons.image_outlined),
  const DocFilterPreset(id: 'magic_book', title: 'Magic Book', icon: Icons.auto_awesome_rounded),
  const DocFilterPreset(id: 'bw_sharp', title: 'Deep B&W', icon: Icons.contrast_rounded),
  const DocFilterPreset(id: 'deshadow', title: 'De-Shadow', icon: Icons.wb_sunny_outlined),
  const DocFilterPreset(id: 'vibrant_color', title: 'Vivid Color', icon: Icons.color_lens_outlined),
  const DocFilterPreset(id: 'greyscale', title: 'Grayscale', icon: Icons.filter_b_and_w_rounded),
];

// ============================================================================
// AI DESKEW ENGINE
// ============================================================================
class AIDeskewEngine {
  static Future<double> detectSkewAngle(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      List<double> angles = [];
      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          if (line.cornerPoints.length >= 2) {
            final p1 = line.cornerPoints[0];
            final p2 = line.cornerPoints[1];
            final dx = (p2.x - p1.x).toDouble();
            final dy = (p2.y - p1.y).toDouble();
            double angleDeg = atan2(dy, dx) * 180 / pi;
            while (angleDeg > 45) angleDeg -= 90;
            while (angleDeg < -45) angleDeg += 90;
            angles.add(angleDeg);
          }
        }
      }
      if (angles.isNotEmpty) {
        angles.sort();
        return angles[angles.length ~/ 2];
      }
    } catch (e) {
      debugPrint("Deskew angle err: $e");
    }
    return 0.0;
  }

  static Future<String> rotateAndDeskewImage(String sourcePath, double angleDegrees) async {
    try {
      final file = File(sourcePath);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;

      final angleRad = angleDegrees * pi / 180.0;
      final absCos = cos(angleRad).abs();
      final absSin = sin(angleRad).abs();
      final newW = (img.width * absCos + img.height * absSin).round();
      final newH = (img.width * absSin + img.height * absCos).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, newW.toDouble(), newH.toDouble()));
      canvas.drawRect(Rect.fromLTWH(0, 0, newW.toDouble(), newH.toDouble()), Paint()..color = Colors.white);
      canvas.translate(newW / 2, newH / 2);
      canvas.rotate(angleRad);
      canvas.drawImage(img, Offset(-img.width / 2, -img.height / 2), Paint());

      final picture = recorder.endRecording();
      final outputImg = await picture.toImage(newW, newH);
      final byteData = await outputImg.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final scansDir = Directory('${appDir.path}/scans');
        if (!await scansDir.exists()) await scansDir.create(recursive: true);
        final outF = File('${scansDir.path}/deskew_${DateTime.now().millisecondsSinceEpoch}.png');
        await outF.writeAsBytes(byteData.buffer.asUint8List());
        return outF.path;
      }
    } catch (e) {
      debugPrint("Rotate Deskew err: $e");
    }
    return sourcePath;
  }
}

// ============================================================================
// MAIN ENTRY POINT
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("AdMob Init: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  appThemeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;

  final colorVal = prefs.getInt('primary_color_val');
  if (colorVal != null) {
    appPrimaryColor.value = Color(colorVal);
  }

  isHindiLanguage.value = prefs.getBool('app_language_hindi') ?? false;
  runApp(const BharatDocScannerApp());
}

class BharatDocScannerApp extends StatelessWidget {
  const BharatDocScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appPrimaryColor,
      builder: (_, color, __) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: appThemeMode,
          builder: (_, mode, ___) {
            return MaterialApp(
              title: 'Bharat Document Scanner PDF AI',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                scaffoldBackgroundColor: const Color(0xFFF8F9FA),
                colorSchemeSeed: color,
                appBarTheme: const AppBarTheme(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF121212),
                colorSchemeSeed: color,
                appBarTheme: const AppBarTheme(
                  elevation: 0,
                  backgroundColor: Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                ),
              ),
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// 1. SPLASH SCREEN
// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1E36),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: appPrimaryColor.value,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 8))],
              ),
              child: const Icon(Icons.document_scanner_rounded, size: 54, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'BHARAT SCANNER',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ultra Clarity & AI Studio Edition',
              style: TextStyle(fontSize: 12, color: Colors.white70, letterSpacing: 1.0),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 2. MAIN DASHBOARD SCREEN
// ============================================================================
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});
  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentTabIndex = 0;
  List<Map<String, dynamic>> _savedDocs = [];
  List<Map<String, dynamic>> _filteredDocs = [];
  List<String> _userFolders = ['All', 'General', 'Personal', 'Work', 'Invoices', 'Starred'];
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserFolders();
    _loadSavedDocs();
    _loadBannerAd();
    _searchController.addListener(_filterDocs);
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: kDebugMode
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-7940311763952252/4182204348',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();
  }

  Future<void> _loadUserFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? customFolders = prefs.getStringList('custom_user_folders_v2');
    if (customFolders != null && customFolders.isNotEmpty) {
      setState(() {
        _userFolders = ['All', ...customFolders, 'Starred'];
      });
    }
  }

  Future<void> _loadSavedDocs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString('saved_documents_v5');
    if (rawData != null && mounted) {
      try {
        final List decoded = jsonDecode(rawData);
        setState(() {
          _savedDocs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          _filterDocs();
        });
      } catch (e) {
        debugPrint("Error loading docs: $e");
      }
    }
  }

  Future<void> _commitDocsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_documents_v5', jsonEncode(_savedDocs));
  }

  void _filterDocs() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredDocs = _savedDocs.where((doc) {
        final title = (doc['title'] ?? '').toString().toLowerCase();
        final matchesSearch = title.contains(q);
        final matchesCat = _selectedCategory == 'All' ||
            (_selectedCategory == 'Starred' ? (doc['isFavorite'] == true) : (doc['category'] ?? 'General') == _selectedCategory);
        return matchesSearch && matchesCat;
      }).toList();
    });
  }

  // Scanning flow preserving FULL camera resolution
  Future<void> _startDocScan({int limit = 50, String category = 'General', String prefix = 'Doc', bool galleryOnly = false}) async {
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
      if (!mounted || result?.images == null || result!.images.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory('${appDir.path}/scans');
      if (!await scansDir.exists()) await scansDir.create(recursive: true);

      List<String> persistentRawPaths = [];
      for (int i = 0; i < result.images.length; i++) {
        final f = File(result.images[i]);
        if (await f.exists()) {
          final time = DateTime.now().millisecondsSinceEpoch;
          final target = await f.copy('${scansDir.path}/raw_${time}_$i.jpg');
          persistentRawPaths.add(target.path);
        }
      }

      if (!mounted || persistentRawPaths.isEmpty) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanFilterReviewScreen(
            rawImagePaths: persistentRawPaths,
            onApplyAndProceed: (filteredImages) {
              _promptSaveDoc(filteredImages, persistentRawPaths, prefix, category);
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint("Scan error: $e");
    }
  }

  void _promptSaveDoc(List<String> enhancedImages, List<String> rawImages, String prefix, String defaultCat) {
    final nameCtrl = TextEditingController(text: "${prefix}_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    String chosenFolder = (defaultCat == 'All' || defaultCat == 'Starred') ? 'General' : defaultCat;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Save Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Document Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: chosenFolder,
              decoration: const InputDecoration(labelText: 'Folder', border: OutlineInputBorder()),
              items: _userFolders.where((f) => f != 'All' && f != 'Starred').map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (val) {
                if (val != null) chosenFolder = val;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final newDoc = {
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'title': nameCtrl.text.trim().isEmpty ? 'Doc_${DateTime.now().millisecondsSinceEpoch}' : nameCtrl.text.trim(),
                'category': chosenFolder,
                'isFavorite': false,
                'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                'images': List<String>.from(enhancedImages),
                'originalImages': List<String>.from(rawImages),
                'pages': enhancedImages.length,
              };
              setState(() {
                _savedDocs.insert(0, newDoc);
                _filterDocs();
              });
              await _commitDocsToPrefs();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Document Saved in High Quality!')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _extractTextOCR(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return;
      if (recognizedText.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No readable text detected.')));
        return;
      }

      final textCtrl = TextEditingController(text: recognizedText.text);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Extracted OCR Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: textCtrl.text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
                    },
                  ),
                ],
              ),
              const Divider(),
              TextField(controller: textCtrl, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder())),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(44)),
                icon: const Icon(Icons.share),
                label: const Text('Share Extracted Text'),
                onPressed: () => Share.share(textCtrl.text),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint("OCR Err: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bharat Document Scanner AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: _showThemePicker,
          ),
        ],
      ),
      body: _currentTabIndex == 0 ? _buildDocsTab() : _buildToolsTab(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: appPrimaryColor.value,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('Scan Now', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _startDocScan(),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomNavigationBar(
            currentIndex: _currentTabIndex,
            selectedItemColor: appPrimaryColor.value,
            onTap: (i) => setState(() => _currentTabIndex = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.folder_special_rounded), label: 'Documents'),
              BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_mosaic_rounded), label: 'Studio Tools'),
            ],
          ),
          if (_isBannerLoaded && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  Widget _buildDocsTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search documents...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _userFolders.map((cat) {
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSel,
                  selectedColor: appPrimaryColor.value,
                  labelStyle: TextStyle(color: isSel ? Colors.white : null),
                  onSelected: (_) => setState(() {
                    _selectedCategory = cat;
                    _filterDocs();
                  }),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (_filteredDocs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: Text('No documents found. Tap Scan Now to start!')),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            itemBuilder: (ctx, i) {
              final doc = _filteredDocs[i];
              final imgs = doc['images'] as List;
              return Card(
                elevation: 0.5,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: imgs.isNotEmpty && File(imgs.first).existsSync()
                        ? Image.file(File(imgs.first), width: 50, height: 60, fit: BoxFit.cover)
                        : Container(width: 50, height: 60, color: Colors.grey.shade200),
                  ),
                  title: Text(doc['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${doc['pages']} pages • ${doc['category']} • ${doc['date']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentDetailScreen(
                          doc: doc,
                          onDocUpdated: (updated) {
                            setState(() {
                              final idx = _savedDocs.indexWhere((d) => d['id'] == updated['id']);
                              if (idx != -1) _savedDocs[idx] = updated;
                              _filterDocs();
                            });
                            _commitDocsToPrefs();
                          },
                          onDelete: () {
                            setState(() {
                              _savedDocs.removeWhere((d) => d['id'] == doc['id']);
                              _filterDocs();
                            });
                            _commitDocsToPrefs();
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  // Complete List of All Studio Tools
  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolSectionHeader('Scan & OCR Modes'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.88,
          children: [
            _buildMiniToolCard(Icons.badge_outlined, 'ID Card Mode', Colors.blue, () => _startDocScan(limit: 2, category: 'Personal', prefix: 'ID_Card')),
            _buildMiniToolCard(Icons.menu_book_rounded, 'Book Scan', Colors.green, () => _startDocScan(prefix: 'Book_Page')),
            _buildMiniToolCard(Icons.auto_awesome, 'AI OCR Text', Colors.purple, () {
              if (_savedDocs.isNotEmpty && _savedDocs.first['images'].isNotEmpty) {
                _extractTextOCR(_savedDocs.first['images'][0]);
              } else {
                _startDocScan();
              }
            }),
          ],
        ),
        const SizedBox(height: 20),
        _buildToolSectionHeader('Office & Productivity Suite'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.88,
          children: [
            _buildMiniToolCard(Icons.assignment_ind_rounded, 'Resume Maker', const Color(0xFF0277BD), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeBuilderScreen()))),
            _buildMiniToolCard(Icons.receipt_long_rounded, 'GST Invoice', const Color(0xFF2E7D32), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceMakerProScreen()))),
            _buildMiniToolCard(Icons.slideshow_rounded, 'Slides Maker', const Color(0xFFD84315), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PowerPointStudioScreen()))),
            _buildMiniToolCard(Icons.mail_outline_rounded, 'Letters Maker', const Color(0xFF6A1B9A), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LetterTemplatesScreen()))),
            _buildMiniToolCard(Icons.edit_note_rounded, 'Notes & TXT', const Color(0xFF00796B), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen()))),
            _buildMiniToolCard(Icons.photo_library_outlined, 'From Gallery', const Color(0xFFD81B60), () => _startDocScan(galleryOnly: true)),
          ],
        ),
        const SizedBox(height: 20),
        _buildToolSectionHeader('Image & PDF Studio'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.88,
          children: [
            _buildMiniToolCard(Icons.portrait_rounded, 'Passport Photo', Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportPhotoStudioScreen()))),
            _buildMiniToolCard(Icons.draw_rounded, 'Digital Sign', Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalSignatureScreen()))),
            _buildMiniToolCard(Icons.picture_as_pdf_rounded, 'PDF Merge', Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfStudioScreen(savedDocs: _savedDocs)))),
            _buildMiniToolCard(Icons.branding_watermark_outlined, 'Watermark', Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => WatermarkToolScreen(savedDocs: _savedDocs)))),
            _buildMiniToolCard(Icons.crop_rotate_rounded, 'Photo Rotate', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalImageToolScreen()))),
          ],
        ),
      ],
    );
  }

  Widget _buildToolSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: appPrimaryColor.value),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMiniToolCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 20, backgroundColor: color.withOpacity(0.12), foregroundColor: color, child: Icon(icon, size: 20)),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showThemePicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Theme Color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Colors.pink,
            Colors.indigo,
            Colors.teal,
            Colors.deepOrange,
            Colors.purple,
            Colors.blueGrey,
          ].map((c) => GestureDetector(
            onTap: () async {
              appPrimaryColor.value = c;
              final p = await SharedPreferences.getInstance();
              await p.setInt('primary_color_val', c.value);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: CircleAvatar(backgroundColor: c, radius: 20),
          )).toList(),
        ),
      ),
    );
  }
}

// ============================================================================
// 3. SCAN FILTER & BOOK REVIEW SCREEN (SLIDER + MINI CAROUSEL)
// ============================================================================
class ScanFilterReviewScreen extends StatefulWidget {
  final List<String> rawImagePaths;
  final Function(List<String> filteredPaths) onApplyAndProceed;

  const ScanFilterReviewScreen({
    super.key,
    required this.rawImagePaths,
    required this.onApplyAndProceed,
  });

  @override
  State<ScanFilterReviewScreen> createState() => _ScanFilterReviewScreenState();
}

class _ScanFilterReviewScreenState extends State<ScanFilterReviewScreen> {
  int _curPageIndex = 0;
  bool _isProcessing = false;
  late List<String> _workingPaths;
  late Map<int, String> _pageFilterSelections;
  late Map<int, double> _pageFilterIntensities;

  @override
  void initState() {
    super.initState();
    _workingPaths = List<String>.from(widget.rawImagePaths);
    _pageFilterSelections = {for (var i = 0; i < widget.rawImagePaths.length; i++) i: 'magic_book'};
    _pageFilterIntensities = {for (var i = 0; i < widget.rawImagePaths.length; i++) i: 0.6}; // 60% optimal clarity
  }

  DocFilterPreset get _currentPreset => kDocFilters.firstWhere(
        (f) => f.id == (_pageFilterSelections[_curPageIndex] ?? 'magic_book'),
        orElse: () => kDocFilters[1],
      );

  double get _currentIntensity => _pageFilterIntensities[_curPageIndex] ?? 0.6;

  Future<void> _applyAllPagesSameFilter() async {
    final activeFilter = _pageFilterSelections[_curPageIndex] ?? 'magic_book';
    final activeIntensity = _currentIntensity;
    setState(() {
      for (int i = 0; i < _workingPaths.length; i++) {
        _pageFilterSelections[i] = activeFilter;
        _pageFilterIntensities[i] = activeIntensity;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Applied this filter & intensity to ALL pages!')));
  }

  Future<void> _autoStraightenCurrentPage() async {
    setState(() => _isProcessing = true);
    final curImg = _workingPaths[_curPageIndex];
    final angle = await AIDeskewEngine.detectSkewAngle(curImg);
    if (angle.abs() > 0.4) {
      final straightened = await AIDeskewEngine.rotateAndDeskewImage(curImg, -angle);
      setState(() {
        _workingPaths[_curPageIndex] = straightened;
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✨ AI Straightened by ${angle.toStringAsFixed(1)}°')));
    } else {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Document is already straight!')));
    }
  }

  // Preserves FULL Original Camera Resolution while applying the filter
  Future<void> _finishAndExport() async {
    setState(() => _isProcessing = true);
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!await scansDir.exists()) await scansDir.create(recursive: true);

    List<String> enhancedPaths = [];
    for (int i = 0; i < _workingPaths.length; i++) {
      final filterId = _pageFilterSelections[i] ?? 'magic_book';
      final intensity = _pageFilterIntensities[i] ?? 0.6;
      final preset = kDocFilters.firstWhere((f) => f.id == filterId, orElse: () => kDocFilters[1]);

      final matrix = preset.getMatrix(intensity);
      if (matrix == null) {
        enhancedPaths.add(_workingPaths[i]);
      } else {
        final bytes = await File(_workingPaths[i]).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final img = frame.image;

        // Render at EXACT image dimensions without downscaling
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()));
        final paint = Paint()..colorFilter = ColorFilter.matrix(matrix);
        canvas.drawImage(img, Offset.zero, paint);

        final pic = recorder.endRecording();
        final outputImg = await pic.toImage(img.width, img.height);
        final byteData = await outputImg.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final outFile = File('${scansDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}_p$i.png');
          await outFile.writeAsBytes(byteData.buffer.asUint8List());
          enhancedPaths.add(outFile.path);
        } else {
          enhancedPaths.add(_workingPaths[i]);
        }
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      Navigator.pop(context);
      widget.onApplyAndProceed(enhancedPaths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePreset = _currentPreset;
    final activeMatrix = activePreset.getMatrix(_currentIntensity);
    final curImg = File(_workingPaths[_curPageIndex]);

    return Scaffold(
      backgroundColor: const Color(0xFF181A1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181A1F),
        foregroundColor: Colors.white,
        title: Text('Page ${_curPageIndex + 1} of ${_workingPaths.length}', style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            icon: const Icon(Icons.straighten),
            tooltip: 'Auto Straighten AI',
            onPressed: _autoStraightenCurrentPage,
          ),
          TextButton(
            onPressed: _applyAllPagesSameFilter,
            child: const Text('Apply All', style: TextStyle(color: Color(0xFF8AB4F8), fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.greenAccent, size: 28),
            onPressed: _finishAndExport,
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                // 1. MAIN DOCUMENT PREVIEW
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: activeMatrix != null
                            ? ColorFiltered(
                                colorFilter: ColorFilter.matrix(activeMatrix),
                                child: Image.file(curImg, fit: BoxFit.contain),
                              )
                            : Image.file(curImg, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),

                // 2. REAL-TIME INTENSITY ADJUSTMENT SLIDER
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: const Color(0xFF21242B),
                  child: Row(
                    children: [
                      const Text('Text/White Contrast:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: _currentIntensity,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          activeColor: const Color(0xFF8AB4F8),
                          inactiveColor: Colors.grey.shade700,
                          onChanged: (val) {
                            setState(() {
                              _pageFilterIntensities[_curPageIndex] = val;
                            });
                          },
                        ),
                      ),
                      Text('${(_currentIntensity * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                // 3. FILTER PRESET SELECTION
                Container(
                  height: 80,
                  color: const Color(0xFF21242B),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: kDocFilters.length,
                    itemBuilder: (ctx, i) {
                      final f = kDocFilters[i];
                      final isSel = activePreset.id == f.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _pageFilterSelections[_curPageIndex] = f.id;
                          });
                        },
                        child: Container(
                          width: 76,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF32486E) : const Color(0xFF2B2E37),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSel ? const Color(0xFF8AB4F8) : Colors.transparent, width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(f.icon, color: isSel ? const Color(0xFF8AB4F8) : Colors.white70, size: 22),
                              const SizedBox(height: 4),
                              Text(f.title, style: TextStyle(color: isSel ? Colors.white : Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 4. MINI PAGE THUMBNAILS CAROUSEL
                Container(
                  height: 82,
                  color: const Color(0xFF181A1F),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _workingPaths.length,
                    itemBuilder: (ctx, idx) {
                      final isSelectedPage = _curPageIndex == idx;
                      final pageImg = File(_workingPaths[idx]);

                      return GestureDetector(
                        onTap: () => setState(() => _curPageIndex = idx),
                        child: Container(
                          width: 58,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelectedPage ? const Color(0xFF8AB4F8) : Colors.grey.shade700,
                              width: isSelectedPage ? 2.5 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(pageImg, fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                left: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'P${idx + 1}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ============================================================================
// 4. DOCUMENT DETAIL SCREEN (WITH MULTI-PAGE SELECTION & ACTIONS)
// ============================================================================
class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doc;
  final Function(Map<String, dynamic>) onDocUpdated;
  final VoidCallback onDelete;

  const DocumentDetailScreen({
    super.key,
    required this.doc,
    required this.onDocUpdated,
    required this.onDelete,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late List<String> _images;
  late String _title;

  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.doc['images'] ?? []);
    _title = widget.doc['title'] ?? 'Document';
  }

  List<String> get _targetImages {
    if (_isSelectionMode && _selectedIndices.isNotEmpty) {
      final sorted = _selectedIndices.toList()..sort();
      return sorted.map((i) => _images[i]).toList();
    }
    return _images;
  }

  // Real 10 KB to 5 MB Compressor
  void _openTargetCompressorDialog() {
    double targetKb = 150;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Target Compressor (10KB - 5MB)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Target Limit:'),
                    Text(
                      targetKb >= 1000 ? '${(targetKb / 1000).toStringAsFixed(1)} MB' : '${targetKb.toInt()} KB',
                      style: TextStyle(fontWeight: FontWeight.bold, color: appPrimaryColor.value),
                    ),
                  ],
                ),
                Slider(
                  value: targetKb,
                  min: 10,
                  max: 5000,
                  divisions: 100,
                  activeColor: appPrimaryColor.value,
                  onChanged: (v) => setDialogState(() => targetKb = v),
                ),
                Wrap(
                  spacing: 6,
                  children: [20, 50, 100, 200, 500, 1000].map((preset) {
                    return ActionChip(
                      label: Text('$preset KB', style: const TextStyle(fontSize: 10)),
                      onPressed: () => setDialogState(() => targetKb = preset.toDouble()),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportCompressedPdf(_targetImages, targetKb.toInt());
                },
                child: const Text('Compress & Share'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportCompressedPdf(List<String> imgs, int targetKb) async {
    final pdf = pw.Document();
    final double perPageKb = targetKb / (imgs.isEmpty ? 1 : imgs.length);

    for (var path in imgs) {
      final f = File(path);
      if (await f.exists()) {
        final rawBytes = await f.readAsBytes();

        int targetW = 1200;
        if (perPageKb < 40) {
          targetW = 500;
        } else if (perPageKb < 100) {
          targetW = 750;
        } else if (perPageKb < 250) {
          targetW = 950;
        }

        final codec = await ui.instantiateImageCodec(rawBytes, targetWidth: targetW);
        final frame = await codec.getNextFrame();
        final resizedData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        final finalBytes = resizedData != null ? resizedData.buffer.asUint8List() : rawBytes;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) => pw.Center(child: pw.Image(pw.MemoryImage(finalBytes), fit: pw.BoxFit.contain)),
          ),
        );
      }
    }

    final tempDir = await getTemporaryDirectory();
    final file = File("${tempDir.path}/${_title}_compressed_${targetKb}KB.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: '$_title (Compressed to $targetKb KB)');
  }

  Future<void> _shareImagesDirectly() async {
    final imgs = _targetImages;
    List<XFile> xFiles = imgs.map((p) => XFile(p)).toList();
    if (xFiles.isNotEmpty) {
      await Share.shareXFiles(xFiles, text: '$_title Photos');
    }
  }

  Future<void> _saveJpgToPhone() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final galleryDir = Directory('${appDir.path}/BharatScanner_Saved');
      if (!await galleryDir.exists()) await galleryDir.create(recursive: true);

      int count = 0;
      for (int i = 0; i < _targetImages.length; i++) {
        final f = File(_targetImages[i]);
        if (await f.exists()) {
          final target = File('${galleryDir.path}/${_title}_p${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await f.copy(target.path);
          count++;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Successfully saved $count image(s)!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _deleteSelectedPages() {
    if (_selectedIndices.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pages?'),
        content: Text('Delete ${_selectedIndices.length} selected page(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
              for (var idx in sorted) {
                _images.removeAt(idx);
              }
              if (_images.isEmpty) {
                widget.onDelete();
                Navigator.pop(context);
              } else {
                setState(() {
                  widget.doc['images'] = _images;
                  widget.doc['pages'] = _images.length;
                  _isSelectionMode = false;
                  _selectedIndices.clear();
                });
                widget.onDocUpdated(widget.doc);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? '${_selectedIndices.length} Selected' : _title),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select All',
              onPressed: () {
                setState(() {
                  if (_selectedIndices.length == _images.length) {
                    _selectedIndices.clear();
                  } else {
                    _selectedIndices.addAll(List.generate(_images.length, (i) => i));
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedIndices.clear();
              }),
            ),
          ] else ...[
            TextButton.icon(
              icon: const Icon(Icons.checklist_rounded, size: 18),
              label: const Text('Select Pages'),
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
          ],
        ],
      ),
      body: _images.isEmpty
          ? const Center(child: Text('No pages in this document.'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _images.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (ctx, idx) {
                final isSelected = _selectedIndices.contains(idx);
                final file = File(_images[idx]);

                return GestureDetector(
                  onTap: () {
                    if (_isSelectionMode) {
                      setState(() {
                        if (isSelected) {
                          _selectedIndices.remove(idx);
                        } else {
                          _selectedIndices.add(idx);
                        }
                      });
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? appPrimaryColor.value : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: file.existsSync()
                                ? Image.file(file, fit: BoxFit.cover)
                                : Container(color: Colors.grey.shade200),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                            child: Text('P${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        if (_isSelectionMode)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              color: isSelected ? appPrimaryColor.value : Colors.white,
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomAction(Icons.picture_as_pdf_rounded, 'Share PDF', () => _exportCompressedPdf(_targetImages, 800)),
              _buildBottomAction(Icons.image_rounded, 'Share JPG', _shareImagesDirectly),
              _buildBottomAction(Icons.save_alt_rounded, 'Save Phone', _saveJpgToPhone),
              _buildBottomAction(Icons.tune_rounded, 'Compress', _openTargetCompressorDialog),
              if (_isSelectionMode)
                _buildBottomAction(Icons.delete_rounded, 'Delete', _deleteSelectedPages, isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    final col = isDestructive ? Colors.redAccent : appPrimaryColor.value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: col, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: col)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 5. PASSPORT PHOTO STUDIO (INDIAN PASSPORT, PAN, US VISA, BACKGROUND COLORS)
// ============================================================================
class PassportPhotoStudioScreen extends StatefulWidget {
  const PassportPhotoStudioScreen({super.key});
  @override
  State<PassportPhotoStudioScreen> createState() => _PassportPhotoStudioScreenState();
}

class _PassportPhotoStudioScreenState extends State<PassportPhotoStudioScreen> {
  String? _photoPath;
  int _copies = 8;
  String _presetSize = 'Indian Passport (3.5x4.5 cm)';
  String _bgChoice = 'White';

  Future<void> _pickPhoto() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 1),
    );
    final res = await scanner.scanDocument();
    if (res?.images != null && res!.images.isNotEmpty) {
      setState(() => _photoPath = res.images.first);
    }
  }

  Future<void> _exportPassportSheet() async {
    if (_photoPath == null) return;
    final pdf = pw.Document();
    final imgBytes = await File(_photoPath!).readAsBytes();
    final passImg = pw.MemoryImage(imgBytes);

    // Dimension setup
    double w = 110;
    double h = 145;
    if (_presetSize.contains('US Visa')) {
      w = 140;
      h = 140;
    } else if (_presetSize.contains('PAN Card')) {
      w = 95;
      h = 130;
    } else if (_presetSize.contains('Stamp')) {
      w = 80;
      h = 100;
    }

    PdfColor bgColor = PdfColors.white;
    if (_bgChoice == 'Studio Blue') bgColor = PdfColor.fromInt(0xFFBBDEFB);
    if (_bgChoice == 'Light Grey') bgColor = PdfColor.fromInt(0xFFECEFF1);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Wrap(
            spacing: 16,
            runSpacing: 20,
            children: List.generate(
              _copies,
              (_) => pw.Container(
                width: w,
                height: h,
                color: bgColor,
                padding: const pw.EdgeInsets.all(2),
                child: pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 1)),
                  child: pw.Image(passImg, fit: pw.BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Passport_Sheet_${_copies}_Prints.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Passport Photos Print Sheet');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passport Photo Studio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: _photoPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_photoPath!), height: 180, width: 140, fit: BoxFit.cover),
                    )
                  : Container(
                      height: 180,
                      width: 140,
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.portrait, size: 60, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Select Portrait Photo'),
              onPressed: _pickPhoto,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _presetSize,
              decoration: const InputDecoration(labelText: 'Standard Photo Size', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Indian Passport (3.5x4.5 cm)', child: Text('Indian Passport (3.5x4.5 cm)')),
                DropdownMenuItem(value: 'PAN Card (2.5x3.5 cm)', child: Text('PAN Card (2.5x3.5 cm)')),
                DropdownMenuItem(value: 'US Visa / OCI (2x2 inch)', child: Text('US Visa / OCI (2x2 inch)')),
                DropdownMenuItem(value: 'Stamp Size (2x2.5 cm)', child: Text('Stamp Size (2x2.5 cm)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _presetSize = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _bgChoice,
              decoration: const InputDecoration(labelText: 'Background Color', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'White', child: Text('Pure White')),
                DropdownMenuItem(value: 'Studio Blue', child: Text('Studio Light Blue')),
                DropdownMenuItem(value: 'Light Grey', child: Text('Light Grey')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _bgChoice = v);
              },
            ),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Number of Copies on A4:', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 4, label: Text('4')),
                ButtonSegment(value: 8, label: Text('8')),
                ButtonSegment(value: 16, label: Text('16')),
                ButtonSegment(value: 32, label: Text('32')),
              ],
              selected: {_copies},
              onSelectionChanged: (s) => setState(() => _copies = s.first),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export Printable A4 Sheet PDF'),
                onPressed: _photoPath == null ? null : _exportPassportSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 6. DIGITAL SIGNATURE (TRANSPARENT PNG, STROKE SLIDER, COLOR)
// ============================================================================
class DigitalSignatureScreen extends StatefulWidget {
  const DigitalSignatureScreen({super.key});
  @override
  State<DigitalSignatureScreen> createState() => _DigitalSignatureScreenState();
}

class _DigitalSignatureScreenState extends State<DigitalSignatureScreen> {
  final List<List<Offset>> _strokes = [];
  Color _inkColor = Colors.black;
  double _strokeWidth = 3.5;

  Future<void> _exportSignaturePng() async {
    if (_strokes.isEmpty) return;

    double minX = 10000, maxX = 0, minY = 10000, maxY = 0;
    for (var stroke in _strokes) {
      for (var p in stroke) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    const pad = 20.0;
    minX = (minX - pad).clamp(0, 5000);
    minY = (minY - pad).clamp(0, 5000);
    final width = (maxX - minX + pad * 2).clamp(60.0, 5000.0);
    final height = (maxY - minY + pad * 2).clamp(60.0, 5000.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.translate(-minX, -minY);

    final paint = Paint()
      ..color = _inkColor
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var stroke in _strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }

    final pic = recorder.endRecording();
    final img = await pic.toImage(width.toInt(), height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    if (data != null) {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/Signature_${DateTime.now().millisecondsSinceEpoch}.png");
      await file.writeAsBytes(data.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: 'My Transparent Signature');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Signature'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: () {
              if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear All',
            onPressed: () => setState(() => _strokes.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Text('Ink: ', style: TextStyle(fontWeight: FontWeight.bold)),
                ...[Colors.black, const Color(0xFF0D47A1), const Color(0xFFB71C1C), const Color(0xFF1B5E20)].map((c) => GestureDetector(
                  onTap: () => setState(() => _inkColor = c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: _inkColor == c ? Colors.amber : Colors.transparent, width: 2),
                    ),
                  ),
                )),
                const Spacer(),
                const Text('Size: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: _strokeWidth,
                  min: 1.5,
                  max: 8.0,
                  onChanged: (v) => setState(() => _strokeWidth = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
              onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
              child: CustomPaint(
                painter: _SignPainter(_strokes, _inkColor, _strokeWidth),
                size: Size.infinite,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export Transparent PNG Sign'),
                onPressed: _strokes.isEmpty ? null : _exportSignaturePng,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;
  _SignPainter(this.strokes, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================================
// 7. GST TAX INVOICE MAKER (SELLER/BUYER, QTY X PRICE, TAX SLABS)
// ============================================================================
class InvoiceMakerProScreen extends StatefulWidget {
  const InvoiceMakerProScreen({super.key});
  @override
  State<InvoiceMakerProScreen> createState() => _InvoiceMakerProScreenState();
}

class _InvoiceMakerProScreenState extends State<InvoiceMakerProScreen> {
  final _sellerCtrl = TextEditingController(text: 'My Business / Shop Name');
  final _clientCtrl = TextEditingController(text: 'Customer / Client Name');
  final _invNumCtrl = TextEditingController(text: 'INV-001');
  final _itemCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  double _gstRate = 0.18;

  List<Map<String, dynamic>> _items = [
    {'name': 'Professional Consulting', 'price': 1200.0, 'qty': 1},
  ];

  Future<void> _exportInvoicePdf() async {
    final pdf = pw.Document();
    double subtotal = _items.fold(0.0, (s, i) => s + ((i['price'] as double) * (i['qty'] as int)));
    double gstAmount = subtotal * _gstRate;
    double grandTotal = subtotal + gstAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
                  pw.Text('Invoice #: ${_invNumCtrl.text}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Text('Seller: ${_sellerCtrl.text}'),
              pw.Text('Billed To: ${_clientCtrl.text}'),
              pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
              pw.Divider(thickness: 1.5, color: PdfColors.pink),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Item / Service', 'Qty', 'Rate (INR)', 'Total (INR)'],
                data: _items.map((it) => [
                  it['name'],
                  '${it['qty']}',
                  '${it['price']}',
                  '${(it['price'] * it['qty']).toStringAsFixed(2)}',
                ]).toList(),
              ),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: INR ${subtotal.toStringAsFixed(2)}'),
                    pw.Text('GST (${(_gstRate * 100).toInt()}%): INR ${gstAmount.toStringAsFixed(2)}'),
                    pw.Divider(),
                    pw.Text('Grand Total: INR ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Tax_Invoice.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Tax Invoice PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GST Tax Invoice Maker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _sellerCtrl, decoration: const InputDecoration(labelText: 'Seller / Business Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _clientCtrl, decoration: const InputDecoration(labelText: 'Customer / Client Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _invNumCtrl, decoration: const InputDecoration(labelText: 'Invoice Number', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(flex: 3, child: TextField(controller: _itemCtrl, decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()))),
                const SizedBox(width: 6),
                Expanded(flex: 1, child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()))),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()))),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 36),
                  onPressed: () {
                    if (_itemCtrl.text.isNotEmpty && _priceCtrl.text.isNotEmpty) {
                      setState(() {
                        _items.add({
                          'name': _itemCtrl.text.trim(),
                          'qty': int.tryParse(_qtyCtrl.text.trim()) ?? 1,
                          'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
                        });
                        _itemCtrl.clear();
                        _priceCtrl.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('GST Slab Rate:'),
                DropdownButton<double>(
                  value: _gstRate,
                  items: const [
                    DropdownMenuItem(value: 0.0, child: Text('0% Exempt')),
                    DropdownMenuItem(value: 0.05, child: Text('5% GST')),
                    DropdownMenuItem(value: 0.12, child: Text('12% GST')),
                    DropdownMenuItem(value: 0.18, child: Text('18% Standard')),
                    DropdownMenuItem(value: 0.28, child: Text('28% Luxury')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _gstRate = v);
                  },
                ),
              ],
            ),
            const Divider(),
            ..._items.map((it) => ListTile(
              title: Text(it['name']),
              subtitle: Text('Qty: ${it['qty']} × INR ${it['price']}'),
              trailing: Text('INR ${(it['qty'] * it['price']).toStringAsFixed(2)}'),
            )),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
              onPressed: _items.isEmpty ? null : _exportInvoicePdf,
              child: const Text('Export Official Tax Invoice PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 8. RESUME / CV BUILDER (PROFESSIONAL ONE-PAGE CV)
// ============================================================================
class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});
  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final _name = TextEditingController(text: 'Rahul Sharma');
  final _contact = TextEditingController(text: '+91 98765 43210 | rahul.sharma@email.com | New Delhi');
  final _summary = TextEditingController(text: 'Motivated professional with expertise in operations, documentation, and team leadership.');
  final _experience = TextEditingController(text: '• 3+ Years experience in Team Coordination & IT Documentation.\n• Managed client communications and delivery targets.');
  final _education = TextEditingController(text: '• Bachelor of Science / Graduate (2021)\n• Higher Secondary Certificate (2018)');
  final _skills = TextEditingController(text: 'MS Office, Communication, Team Leadership, Problem Solving');

  Future<void> _exportCv() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_name.text, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
              pw.Text(_contact.text, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Divider(thickness: 1.5, color: PdfColors.pink),
              pw.SizedBox(height: 8),
              pw.Text('PROFESSIONAL SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(_summary.text, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Text('WORK EXPERIENCE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(_experience.text, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Text('EDUCATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(_education.text, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Text('KEY SKILLS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(_skills.text, style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Resume_${_name.text.replaceAll(' ', '_')}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Professional Resume');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resume / CV Maker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact (Phone, Email, City)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _summary, maxLines: 2, decoration: const InputDecoration(labelText: 'Profile Summary', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _experience, maxLines: 3, decoration: const InputDecoration(labelText: 'Work Experience', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _education, maxLines: 2, decoration: const InputDecoration(labelText: 'Education', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _skills, decoration: const InputDecoration(labelText: 'Skills', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
              onPressed: _exportCv,
              child: const Text('Generate Resume PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 9. POWERPOINT / SLIDES MAKER (LANDSCAPE A4 DECK)
// ============================================================================
class PowerPointStudioScreen extends StatefulWidget {
  const PowerPointStudioScreen({super.key});
  @override
  State<PowerPointStudioScreen> createState() => _PowerPointStudioScreenState();
}

class _PowerPointStudioScreenState extends State<PowerPointStudioScreen> {
  final List<Map<String, String>> _slides = [
    {'title': 'Project Overview', 'content': '• Goals and Milestones\n• Target Audience\n• Timeline'},
    {'title': 'Key Execution Steps', 'content': '• Step 1: Research & Discovery\n• Step 2: Implementation\n• Step 3: Launch'},
  ];

  Future<void> _exportDeck() async {
    final pdf = pw.Document();
    for (int i = 0; i < _slides.length; i++) {
      final s = _slides[i];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (ctx) => pw.Container(
            padding: const pw.EdgeInsets.all(36),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(s['title'] ?? '', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
                    pw.Text('Slide ${i + 1} of ${_slides.length}', style: const pw.TextStyle(color: PdfColors.grey600)),
                  ],
                ),
                pw.Divider(thickness: 2, color: PdfColors.pink),
                pw.SizedBox(height: 20),
                pw.Text(s['content'] ?? '', style: const pw.TextStyle(fontSize: 18, lineSpacing: 4)),
              ],
            ),
          ),
        ),
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Presentation_Slides.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Presentation Slides');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Slides Maker'), actions: [IconButton(icon: const Icon(Icons.share), onPressed: _exportDeck)]),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _slides.length,
        itemBuilder: (ctx, i) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextFormField(initialValue: _slides[i]['title'], decoration: const InputDecoration(labelText: 'Slide Title'), onChanged: (v) => _slides[i]['title'] = v),
                TextFormField(initialValue: _slides[i]['content'], maxLines: 3, decoration: const InputDecoration(labelText: 'Bullets / Points'), onChanged: (v) => _slides[i]['content'] = v),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: appPrimaryColor.value,
        foregroundColor: Colors.white,
        onPressed: () => setState(() => _slides.add({'title': 'New Slide', 'content': '• Point 1\n• Point 2'})),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================================
// 10. FORMAL LETTER TEMPLATES
// ============================================================================
class LetterTemplatesScreen extends StatefulWidget {
  const LetterTemplatesScreen({super.key});
  @override
  State<LetterTemplatesScreen> createState() => _LetterTemplatesScreenState();
}

class _LetterTemplatesScreenState extends State<LetterTemplatesScreen> {
  final _ctrl = TextEditingController(
    text: "To,\nThe Branch Manager,\nSubject: Application for New Cheque Book\n\nRespected Sir/Madam,\nI hold a savings account in your branch (Account No: XXXXXXXX). I kindly request you to issue a new cheque book for my account.\n\nThanking You,\nYours Sincerely,\n[Your Name]",
  );

  Future<void> _exportLetter() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(36),
          child: pw.Text(_ctrl.text, style: const pw.TextStyle(fontSize: 14, lineSpacing: 4)),
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Formal_Letter.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Formal Letter PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Letter Maker'), actions: [IconButton(icon: const Icon(Icons.share), onPressed: _exportLetter)]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Leave Letter'),
                  onPressed: () => setState(() => _ctrl.text = "To,\nThe HR Manager,\nSubject: Leave Application\n\nRespected Sir/Madam,\nI am writing to formally request 3 days of leave from [Start Date] to [End Date] due to urgent personal reasons.\n\nThank you.\nSincerely,\n[Your Name]"),
                ),
                ActionChip(
                  label: const Text('Resignation'),
                  onPressed: () => setState(() => _ctrl.text = "To,\nThe Management,\nSubject: Notice of Resignation\n\nPlease accept this letter as formal notification that I am resigning from my position as [Designation]. My last working day will be [Date].\n\nRegards,\n[Your Name]"),
                ),
                ActionChip(
                  label: const Text('Bank Manager'),
                  onPressed: () => setState(() => _ctrl.text = "To,\nThe Branch Manager,\nSubject: Request to Update Phone Number\n\nRespected Sir,\nKindly update my mobile number [New Number] in my bank account [Account No].\n\nThanking you,\n[Your Name]"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(child: TextField(controller: _ctrl, maxLines: null, expands: true, decoration: const InputDecoration(border: OutlineInputBorder()))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 11. TXT & NOTES STUDIO
// ============================================================================
class TxtEditorNotesScreen extends StatefulWidget {
  const TxtEditorNotesScreen({super.key});
  @override
  State<TxtEditorNotesScreen> createState() => _TxtEditorNotesScreenState();
}

class _TxtEditorNotesScreenState extends State<TxtEditorNotesScreen> {
  final _titleCtrl = TextEditingController(text: 'Quick Note');
  final _bodyCtrl = TextEditingController();

  Future<void> _exportTxt() async {
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/${_titleCtrl.text.replaceAll(' ', '_')}.txt");
    await file.writeAsString(_bodyCtrl.text);
    await Share.shareXFiles([XFile(file.path)], text: 'Exported Note');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes & TXT Studio'), actions: [IconButton(icon: const Icon(Icons.share), onPressed: _exportTxt)]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Expanded(child: TextField(controller: _bodyCtrl, maxLines: null, expands: true, decoration: const InputDecoration(hintText: 'Start writing notes...', border: OutlineInputBorder()))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 12. PDF MERGE STUDIO
// ============================================================================
class PdfStudioScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedDocs;
  const PdfStudioScreen({super.key, required this.savedDocs});
  @override
  State<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends State<PdfStudioScreen> {
  final Set<String> _selectedIds = {};

  Future<void> _mergeDocs() async {
    if (_selectedIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least 2 documents to merge!')));
      return;
    }
    final pdf = pw.Document();
    for (var id in _selectedIds) {
      final doc = widget.savedDocs.firstWhere((d) => d['id'] == id);
      final imgs = doc['images'] as List;
      for (var p in imgs) {
        final f = File(p);
        if (await f.exists()) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (ctx) => pw.Center(child: pw.Image(pw.MemoryImage(f.readAsBytesSync()), fit: pw.BoxFit.contain)),
            ),
          );
        }
      }
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Merged_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Merged PDF Document');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge Documents')),
      body: ListView.builder(
        itemCount: widget.savedDocs.length,
        itemBuilder: (ctx, i) {
          final doc = widget.savedDocs[i];
          final isSel = _selectedIds.contains(doc['id']);
          return CheckboxListTile(
            value: isSel,
            title: Text(doc['title']),
            subtitle: Text('${doc['pages']} pages'),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedIds.add(doc['id']);
                } else {
                  _selectedIds.remove(doc['id']);
                }
              });
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.picture_as_pdf),
          label: Text('Merge Selected (${_selectedIds.length}) into One PDF'),
          onPressed: _mergeDocs,
        ),
      ),
    );
  }
}

// ============================================================================
// 13. WATERMARK STUDIO
// ============================================================================
class WatermarkToolScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedDocs;
  const WatermarkToolScreen({super.key, required this.savedDocs});
  @override
  State<WatermarkToolScreen> createState() => _WatermarkToolScreenState();
}

class _WatermarkToolScreenState extends State<WatermarkToolScreen> {
  final _wmCtrl = TextEditingController(text: 'CONFIDENTIAL');
  String? _selectedDocId;

  Future<void> _exportWatermarkedPdf() async {
    if (_selectedDocId == null) return;
    final doc = widget.savedDocs.firstWhere((d) => d['id'] == _selectedDocId);
    final imgs = doc['images'] as List;

    final pdf = pw.Document();
    for (var path in imgs) {
      final f = File(path);
      if (await f.exists()) {
        final img = pw.MemoryImage(await f.readAsBytes());
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) => pw.Stack(
              children: [
                pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
                pw.Center(
                  child: pw.Transform.rotate(
                    angle: -0.6,
                    child: pw.Text(
                      _wmCtrl.text,
                      style: pw.TextStyle(fontSize: 48, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0x35000000)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/${doc['title']}_Watermarked.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Watermarked PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add PDF Watermark')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedDocId,
              hint: const Text('Choose Document'),
              items: widget.savedDocs.map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text(d['title']))).toList(),
              onChanged: (v) => setState(() => _selectedDocId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _wmCtrl, decoration: const InputDecoration(labelText: 'Watermark Stamp Text', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
              onPressed: _selectedDocId == null ? null : _exportWatermarkedPdf,
              child: const Text('Apply Stamp & Share PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 14. UNIVERSAL PHOTO ROTATE (90° ROTATE & SHARE)
// ============================================================================
class UniversalImageToolScreen extends StatefulWidget {
  const UniversalImageToolScreen({super.key});
  @override
  State<UniversalImageToolScreen> createState() => _UniversalImageToolScreenState();
}

class _UniversalImageToolScreenState extends State<UniversalImageToolScreen> {
  String? _imgPath;

  Future<void> _pickImage() async {
    final scanner = DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 1));
    final res = await scanner.scanDocument();
    if (res?.images != null && res!.images.isNotEmpty) {
      setState(() => _imgPath = res.images.first);
    }
  }

  Future<void> _rotate90() async {
    if (_imgPath == null) return;
    final bytes = await File(_imgPath!).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, img.height.toDouble(), img.width.toDouble()));
    canvas.translate(img.height.toDouble() / 2, img.width.toDouble() / 2);
    canvas.rotate(1.5708);
    canvas.drawImage(img, Offset(-img.width.toDouble() / 2, -img.height.toDouble() / 2), Paint());

    final outImg = await recorder.endRecording().toImage(img.height, img.width);
    final data = await outImg.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final f = File('${appDir.path}/rot_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(data.buffer.asUint8List());
      setState(() => _imgPath = f.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Rotate Studio'),
        actions: [
          if (_imgPath != null) IconButton(icon: const Icon(Icons.rotate_right), onPressed: _rotate90),
          if (_imgPath != null) IconButton(icon: const Icon(Icons.share), onPressed: () => Share.shareXFiles([XFile(_imgPath!)])),
        ],
      ),
      body: Center(
        child: _imgPath == null
            ? ElevatedButton.icon(icon: const Icon(Icons.image), label: const Text('Select Photo to Rotate'), onPressed: _pickImage)
            : Image.file(File(_imgPath!)),
      ),
    );
  }
}
