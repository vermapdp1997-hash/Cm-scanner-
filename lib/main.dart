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
// GLOBAL CONTROLLERS & LOCALIZATION
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
      'all': ['All', 'सभी'],
      'starred': ['Starred', 'पसंदीदा'],
      'new_folder': ['+ New Folder', '+ नया फ़ोल्डर'],
      'create_folder': ['Create New Folder', 'नया फ़ोल्डर बनाएं'],
      'folder_name': ['Folder Name', 'फ़ोल्डर का नाम'],
      'cancel': ['Cancel', 'रद्द करें'],
      'create': ['Create', 'बनाएं'],
      'save': ['Save to Docs', 'सेव करें'],
      'save_pdf': ['Save PDF', 'PDF सेव करें'],
      'save_jpg': ['Save JPG', 'JPG सेव करें'],
      'share_pdf': ['Share PDF', 'PDF शेयर करें'],
      'share_jpg': ['Share JPG', 'JPG शेयर करें'],
      'delete': ['Delete', 'हटाएं'],
      'no_docs': ['No documents saved yet', 'अभी तक कोई दस्तावेज़ नहीं है'],
      'scan_now': ['Scan Document Now', 'डॉक्यूमेंट स्कैन करें'],
      'select_all': ['Select All', 'सभी चुनें'],
      'choose_folder': ['Save to Folder:', 'फ़ोल्डर चुनें:'],
      'add_more': ['+ Add More Pages', '+ और पेज जोड़ें'],
      'add_new_doc': ['Add New Document', 'नया दस्तावेज़ जोड़ें'],
      'choose_options': ['Choose from below options', 'नीचे दिए गए विकल्प चुनें'],
      'from_gallery': ['Import from Gallery', 'गैलरी से चुनें'],
      'from_camera': ['Scan from Camera', 'कैमरे से स्कैन करें'],
      'compress': ['Compress (1KB-5MB)', 'कंप्रेस करें'],
      'password_protect': ['Set PDF Password', 'पासवर्ड लगाएं'],
    };
    if (dict.containsKey(key)) {
      return hi ? dict[key]![1] : dict[key]![0];
    }
    return key;
  }
}

// ============================================================================
// ADVANCED AI COLOR FILTER PRESETS DEFINITIONS
// ============================================================================
class DocFilterPreset {
  final String id;
  final String title;
  final List<double>? matrix;
  final IconData icon;

  const DocFilterPreset({
    required this.id,
    required this.title,
    required this.matrix,
    required this.icon,
  });
}

final List<DocFilterPreset> kDocFilters = [
  const DocFilterPreset(
    id: 'original',
    title: 'Original',
    matrix: null,
    icon: Icons.insert_drive_file_outlined,
  ),
  const DocFilterPreset(
    id: 'auto',
    title: 'Auto',
    matrix: [
      1.55, 0.05, 0.05, 0, -32,
      0.05, 1.55, 0.05, 0, -32,
      0.05, 0.05, 1.55, 0, -32,
      0,    0,    0,    1, 0,
    ],
    icon: Icons.auto_awesome_rounded,
  ),
  const DocFilterPreset(
    id: 'colour',
    title: 'Colour',
    matrix: [
      1.40, -0.05, -0.05, 0, -10,
      -0.05, 1.40, -0.05, 0, -10,
      -0.05, -0.05, 1.40, 0, -10,
      0,     0,     0,    1, 0,
    ],
    icon: Icons.color_lens_outlined,
  ),
  const DocFilterPreset(
    id: 'greyscale',
    title: 'Greysc',
    matrix: [
      0.299, 0.587, 0.114, 0, 0,
      0.299, 0.587, 0.114, 0, 0,
      0.299, 0.587, 0.114, 0, 0,
      0,     0,     0,     1, 0,
    ],
    icon: Icons.filter_b_and_w_rounded,
  ),
  const DocFilterPreset(
    id: 'bw_sharp',
    title: 'B&W Ink',
    matrix: [
      2.3, 2.3, 2.3, 0, -320,
      2.3, 2.3, 2.3, 0, -320,
      2.3, 2.3, 2.3, 0, -320,
      0,   0,   0,   1, 0,
    ],
    icon: Icons.contrast_rounded,
  ),
  const DocFilterPreset(
    id: 'shadow_free',
    title: 'Shadow Free',
    matrix: [
      1.35, 0, 0, 0, 42,
      0, 1.35, 0, 0, 42,
      0, 0, 1.35, 0, 42,
      0, 0, 0, 1, 0,
    ],
    icon: Icons.wb_sunny_outlined,
  ),
  const DocFilterPreset(
    id: 'super_white',
    title: 'Super White',
    matrix: [
      1.80, 0, 0, 0, -48,
      0, 1.80, 0, 0, -48,
      0, 0, 1.80, 0, -48,
      0, 0, 0, 1, 0,
    ],
    icon: Icons.cleaning_services_rounded,
  ),
  const DocFilterPreset(
    id: 'warm',
    title: 'Warm Book',
    matrix: [
      1.20, 0, 0, 0, 25,
      0, 1.10, 0, 0, 12,
      0, 0, 0.90, 0, -12,
      0, 0, 0, 1, 0,
    ],
    icon: Icons.menu_book_rounded,
  ),
  const DocFilterPreset(
    id: 'cool',
    title: 'Cool Sharp',
    matrix: [
      1.0, 0, 0, 0, -6,
      0, 1.15, 0, 0, 2,
      0, 0, 1.38, 0, 18,
      0, 0, 0, 1, 0,
    ],
    icon: Icons.ac_unit_rounded,
  ),
];

// ============================================================================
// AI DESKEW & STRAIGHTENING ENGINE
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
            double angleRad = atan2(dy, dx);
            double angleDeg = angleRad * 180 / pi;

            while (angleDeg > 45) {
              angleDeg -= 90;
            }
            while (angleDeg < -45) {
              angleDeg += 90;
            }
            angles.add(angleDeg);
          }
        }
      }

      if (angles.isNotEmpty) {
        angles.sort();
        return angles[angles.length ~/ 2];
      }
    } catch (e) {
      debugPrint("Deskew angle detection err: $e");
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
  } else {
    appPrimaryColor.value = const Color(0xFFE91E63);
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
            return ValueListenableBuilder<bool>(
              valueListenable: isHindiLanguage,
              builder: (_, __, ____) {
                return MaterialApp(
                  title: 'Bharat Document Scanner PDF AI',
                  debugShowCheckedModeBanner: false,
                  themeMode: mode,
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.light,
                    scaffoldBackgroundColor: const Color(0xFFF9FAFB),
                    colorSchemeSeed: color,
                    appBarTheme: const AppBarTheme(
                      elevation: 0,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      iconTheme: IconThemeData(color: Colors.black87),
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
                      iconTheme: IconThemeData(color: Colors.white),
                    ),
                  ),
                  home: const SplashScreen(),
                );
              },
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

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _animController.forward();

    _timer = Timer(const Duration(milliseconds: 2100), () {
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
      backgroundColor: const Color(0xFF0F1E36),
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B2B48), Color(0xFF111D31)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFF385785), width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 15)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BHARAT',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                    color: Color(0xFFF1C40F),
                    shadows: [Shadow(color: Colors.black54, offset: Offset(1, 2), blurRadius: 4)],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'DOCUMENT SCANNER',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2.0, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text(
                  'PDF',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFFE53935)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('A', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFFA000))),
                    Icon(Icons.star, color: Color(0xFFFFA000), size: 20),
                    Text('i', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFFA000))),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF26A69A), borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                    child: Text(
                      'AI DESKEW & CLARITY',
                      style: TextStyle(color: Color(0xFF003830), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
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
  bool _isSearching = false;
  bool _isGridView = false;
  String _selectedCategory = 'All';
  bool _sortAscending = false;
  final TextEditingController _searchController = TextEditingController();

  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = {};

  final String _bannerId = kDebugMode
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-7940311763952252/4182204348';
  final String _interstitialId = kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-7940311763952252/1256658100';

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _loadUserFolders();
    _loadSavedDocs();
    _loadBannerAd();
    _loadInterstitialAd();
    _searchController.addListener(_filterDocs);
  }

  void _loadBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: _bannerId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint("Banner err: $err");
          ad.dispose();
          Future.delayed(const Duration(seconds: 15), () {
            if (mounted) _loadBannerAd();
          });
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (err) {
          debugPrint("Interstitial err: $err");
          _interstitialAd = null;
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitialAd();
    }
  }

  Future<void> _loadUserFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? customFolders = prefs.getStringList('custom_user_folders_v1');
    if (customFolders != null && customFolders.isNotEmpty) {
      setState(() {
        _userFolders = ['All', ...customFolders, 'Starred'];
      });
    }
  }

  Future<void> _createNewFolderDialog({Function(String)? onCreated}) async {
    final folderCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.create_new_folder_rounded, color: appPrimaryColor.value),
            const SizedBox(width: 8),
            Text(AppLang.tr('create_folder'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: folderCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppLang.tr('folder_name'),
            hintText: 'e.g. Bills, Personal, Office...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
            onPressed: () async {
              final name = folderCtrl.text.trim();
              if (name.isNotEmpty && !_userFolders.contains(name)) {
                final prefs = await SharedPreferences.getInstance();
                final currentCustom = _userFolders.where((f) => f != 'All' && f != 'Starred').toList();
                currentCustom.add(name);
                await prefs.setStringList('custom_user_folders_v1', currentCustom);
                setState(() {
                  _userFolders = ['All', ...currentCustom, 'Starred'];
                  _selectedCategory = name;
                });
                _filterDocs();
                Navigator.pop(ctx);
                if (onCreated != null) onCreated(name);
              }
            },
            child: Text(AppLang.tr('create')),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSavedDocs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString('saved_documents_v3');
    if (rawData != null && mounted) {
      try {
        final List decoded = jsonDecode(rawData);
        setState(() {
          _savedDocs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          _filterDocs();
        });
      } catch (e) {
        debugPrint("Doc read err: $e");
      }
    }
  }

  Future<void> _commitDocsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_documents_v3', jsonEncode(_savedDocs));
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

      if (_sortAscending) {
        _filteredDocs.sort((a, b) => (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString()));
      } else {
        _filteredDocs.sort((a, b) => (b['id'] ?? '').toString().compareTo((a['id'] ?? '').toString()));
      }
    });
  }

  Future<Directory> _getPublicStorageFolder({bool isPdf = false}) async {
    Directory? targetDir;
    if (Platform.isAndroid) {
      final base = isPdf ? '/storage/emulated/0/Download' : '/storage/emulated/0/Pictures';
      targetDir = Directory('$base/BharatScanner');
    } else {
      targetDir = await getApplicationDocumentsDirectory();
    }
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  Future<void> _saveJpgToDeviceStorage(List images, String title) async {
    try {
      final targetFolder = await _getPublicStorageFolder(isPdf: false);
      int count = 0;
      final cleanTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      for (int i = 0; i < images.length; i++) {
        final f = File(images[i]);
        if (await f.exists()) {
          final target = File('${targetFolder.path}/${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}_p${i + 1}.jpg');
          await f.copy(target.path);
          count++;
        }
      }
      _showToast('✅ Saved $count photos to Gallery: Pictures/BharatScanner');
    } catch (e) {
      _showToast('Failed to save in Gallery: $e');
    }
  }

  Future<void> _saveToDeviceStorage(List images, String title, {int? targetKb, String? userPassword}) async {
    try {
      final pdfDoc = await _generatePdfDoc(images, targetKb: targetKb);
      Uint8List pdfBytes = await pdfDoc.save();

      final targetFolder = await _getPublicStorageFolder(isPdf: true);
      final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final saveFile = File("${targetFolder.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await saveFile.writeAsBytes(pdfBytes);

      _showToast('✅ PDF saved: Download/BharatScanner');
    } catch (e) {
      _showToast('Failed to save PDF: $e');
    }
  }

  Future<void> _saveDocToStorage(String title, List<String> enhancedPaths, List<String> rawPaths, {String category = 'General'}) async {
    if (enhancedPaths.isEmpty) {
      _showToast('Failed to save scanned images.');
      return;
    }

    final newDoc = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title.isEmpty ? 'Doc_${DateFormat('ddMMM_HHmm').format(DateTime.now())}' : title,
      'category': category,
      'isFavorite': false,
      'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
      'images': List<String>.from(enhancedPaths),
      'originalImages': List<String>.from(rawPaths),
      'pages': enhancedPaths.length,
    };

    setState(() {
      _savedDocs.insert(0, newDoc);
      _filterDocs();
    });
    await _commitDocsToPrefs();
    _showToast('✅ Saved successfully in $category');
  }

  Future<void> _updateExistingDoc(Map<String, dynamic> updatedDoc) async {
    final idx = _savedDocs.indexWhere((d) => d['id'] == updatedDoc['id']);
    if (idx != -1) {
      setState(() {
        _savedDocs[idx] = updatedDoc;
        _filterDocs();
      });
      await _commitDocsToPrefs();
    }
  }

  Future<void> _deleteDoc(String id) async {
    final docToDelete = _savedDocs.firstWhere((d) => d['id'] == id, orElse: () => {});
    if (docToDelete.isNotEmpty) {
      final List allImgs = [...(docToDelete['images'] ?? []), ...(docToDelete['originalImages'] ?? [])];
      for (String p in allImgs) {
        final f = File(p);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    }

    setState(() {
      _savedDocs.removeWhere((item) => item['id'] == id);
      _selectedDocIds.remove(id);
      _filterDocs();
    });
    await _commitDocsToPrefs();
    _showToast('Document deleted permanently');
  }

  void _deleteSelectedDocs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Documents?'),
        content: Text('Are you sure you want to delete ${_selectedDocIds.length} items?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              for (String id in _selectedDocIds.toList()) {
                _deleteDoc(id);
              }
              setState(() {
                _isSelectionMode = false;
                _selectedDocIds.clear();
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _mergeAndShareSelectedDocs() async {
    if (_selectedDocIds.isEmpty) return;
    _showInterstitialAd();

    List<String> allSelectedImgs = [];
    for (String id in _selectedDocIds) {
      final doc = _savedDocs.firstWhere((d) => d['id'] == id, orElse: () => {});
      if (doc.isNotEmpty && doc['images'] != null) {
        allSelectedImgs.addAll(List<String>.from(doc['images']));
      }
    }

    if (allSelectedImgs.isNotEmpty) {
      await _exportPdfWithTargetSize(allSelectedImgs, "Merged_Docs_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    }
  }

  // ==========================================================================
  // SCANNING FLOW -> OPENS AI DESKEW & LIVE FILTER STUDIO
  // ==========================================================================
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
              if (category == 'Personal' && prefix.contains('ID_Card') && filteredImages.length >= 2) {
                _processIdCardCollage(filteredImages.sublist(0, 2), prefix);
              } else {
                _promptDocNameAndFolder(filteredImages, persistentRawPaths, prefix, category);
              }
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint("Scan Err: $e");
    }
  }

  Future<void> _processIdCardCollage(List<String> frontAndBack, String prefix) async {
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

      canvas.drawRect(const Rect.fromLTWH(0, 0, a4Width, a4Height), Paint()..color = Colors.white);

      const cardW = 760.0;
      const cardH = 480.0;
      const left = (a4Width - cardW) / 2;
      final borderPaint = Paint()
        ..color = const Color(0xFFCFD8DC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      const top1 = 200.0;
      final rect1 = Rect.fromLTWH(left, top1, cardW, cardH);
      canvas.drawImageRect(frontImg, Rect.fromLTWH(0, 0, frontImg.width.toDouble(), frontImg.height.toDouble()), rect1, Paint());
      canvas.drawRect(rect1, borderPaint);

      const top2 = 820.0;
      final rect2 = Rect.fromLTWH(left, top2, cardW, cardH);
      canvas.drawImageRect(backImg, Rect.fromLTWH(0, 0, backImg.width.toDouble(), backImg.height.toDouble()), rect2, Paint());
      canvas.drawRect(rect2, borderPaint);

      final picture = recorder.endRecording();
      final a4CollageImg = await picture.toImage(a4Width.toInt(), a4Height.toInt());
      final byteData = await a4CollageImg.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final collageFile = File('${appDir.path}/id_a4_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await collageFile.writeAsBytes(byteData.buffer.asUint8List());

        await _saveDocToStorage(
          'ID_Card_${DateFormat('ddMMM_HHmm').format(DateTime.now())}',
          [collageFile.path],
          frontAndBack,
          category: 'Personal',
        );
      }
    } catch (e) {
      if (mounted) _promptDocNameAndFolder(frontAndBack, frontAndBack, prefix, 'Personal');
    }
  }

  void _promptDocNameAndFolder(List<String> enhancedImages, List<String> rawImages, String prefix, String defaultCat) {
    final nameCtrl = TextEditingController(text: "${prefix}_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    String chosenFolder = (defaultCat == 'All' || defaultCat == 'Starred') ? 'General' : defaultCat;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final foldersAvailable = _userFolders.where((f) => f != 'All' && f != 'Starred').toList();
          if (!foldersAvailable.contains(chosenFolder)) {
            foldersAvailable.add(chosenFolder);
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: appPrimaryColor.value),
                const SizedBox(width: 8),
                Text(AppLang.tr('save'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ ${enhancedImages.length} page(s) ready with AI Clarity & Deskew.', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Document Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLang.tr('choose_folder'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('New', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        _createNewFolderDialog(onCreated: (newF) {
                          setDialogState(() {
                            chosenFolder = newF;
                          });
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: chosenFolder,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  items: foldersAvailable.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => chosenFolder = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr('cancel'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveDocToStorage(nameCtrl.text.trim(), enhancedImages, rawImages, category: chosenFolder);
                },
                child: Text(AppLang.tr('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddNewDocumentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: appPrimaryColor.value.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.note_add_rounded, color: appPrimaryColor.value, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLang.tr('add_new_doc'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(AppLang.tr('choose_options'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _buildModalListOption(
                icon: Icons.photo_size_select_actual_rounded,
                iconColor: const Color(0xFF00B0FF),
                title: AppLang.tr('from_gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startDocScan(galleryOnly: true);
                },
              ),
              _buildModalListOption(
                icon: Icons.photo_camera_rounded,
                iconColor: appPrimaryColor.value,
                title: AppLang.tr('from_camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startDocScan();
                },
              ),
              _buildModalListOption(
                icon: Icons.badge_outlined,
                iconColor: const Color(0xFF1976D2),
                title: 'ID Card Mode (Front & Back)',
                onTap: () {
                  Navigator.pop(ctx);
                  _startDocScan(limit: 2, category: 'Personal', prefix: 'ID_Card');
                },
              ),
              _buildModalListOption(
                icon: Icons.create_new_folder_rounded,
                iconColor: const Color(0xFF6A1B9A),
                title: AppLang.tr('create_folder'),
                onTap: () {
                  Navigator.pop(ctx);
                  _createNewFolderDialog();
                },
              ),
              _buildModalListOption(
                icon: Icons.auto_awesome,
                iconColor: const Color(0xFFE91E63),
                title: 'AI OCR (Extract Text)',
                onTap: () {
                  Navigator.pop(ctx);
                  if (_savedDocs.isNotEmpty && _savedDocs.first['images'].isNotEmpty) {
                    _extractTextWithAI(_savedDocs.first['images'][0]);
                  } else {
                    _startDocScan();
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalListOption({required IconData icon, required Color iconColor, required String title, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDualFabPill() {
    return ValueListenableBuilder<Color>(
      valueListenable: appPrimaryColor,
      builder: (_, themeColor, __) {
        return Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [themeColor, themeColor.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(26)),
                onTap: () => _startDocScan(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
                ),
              ),
              Container(width: 1.2, height: 24, color: Colors.white.withOpacity(0.4)),
              InkWell(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(26)),
                onTap: _openAddNewDocumentSheet,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openThemeColorPicker() {
    final colors = [
      {'name': 'Pink Blossom (Default)', 'color': const Color(0xFFE91E63)},
      {'name': 'Emerald Teal', 'color': const Color(0xFF00796B)},
      {'name': 'Ocean Cyan', 'color': const Color(0xFF0288D1)},
      {'name': 'Ruby Red', 'color': const Color(0xFFD32F2F)},
      {'name': 'Saffron Orange', 'color': const Color(0xFFFF6F00)},
      {'name': 'Royal Sapphire', 'color': const Color(0xFF1565C0)},
      {'name': 'Amethyst Purple', 'color': const Color(0xFF7B1FA2)},
      {'name': 'Forest Green', 'color': const Color(0xFF2E7D32)},
      {'name': 'Midnight Charcoal', 'color': const Color(0xFF263238)},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Choose Color Theme', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: colors.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (ctx, i) {
              final item = colors[i];
              final col = item['color'] as Color;
              final isSelected = appPrimaryColor.value.value == col.value;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  appPrimaryColor.value = col;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('primary_color_val', col.value);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: col,
                        border: Border.all(color: isSelected ? Colors.black : Colors.white, width: isSelected ? 3 : 2),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
                    ),
                    const SizedBox(height: 4),
                    Text(item['name'] as String, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 10)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openCompressionDialog(List<dynamic> images, String title) {
    double targetSizeKb = 350;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.tune_rounded, color: appPrimaryColor.value),
                const SizedBox(width: 8),
                const Text('Smart Target Compressor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set target size limit (1 KB to 5 MB):', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Target Limit:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: appPrimaryColor.value.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        targetSizeKb >= 1000 ? '${(targetSizeKb / 1000).toStringAsFixed(1)} MB' : '${targetSizeKb.toInt()} KB',
                        style: TextStyle(color: appPrimaryColor.value, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: targetSizeKb,
                  min: 50,
                  max: 5000,
                  divisions: 99,
                  activeColor: appPrimaryColor.value,
                  onChanged: (val) => setDialogState(() => targetSizeKb = val),
                ),
                Wrap(
                  spacing: 6,
                  children: [100, 200, 500, 1000, 2000].map((preset) {
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(preset >= 1000 ? '${(preset / 1000).toInt()} MB' : '$preset KB', style: const TextStyle(fontSize: 10)),
                      onPressed: () => setDialogState(() => targetSizeKb = preset.toDouble()),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Choose Action / Format:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('PDF', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _exportPdfWithTargetSize(images, "${title}_Compressed", targetKb: targetSizeKb.toInt());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.image, size: 16),
                        label: const Text('JPG Share', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _compressAndShareJpg(images, "${title}_Compressed", targetKb: targetSizeKb.toInt());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Save Compressed JPG to Gallery'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _compressAndSaveJpgToPhone(images, "${title}_Compressed", targetKb: targetSizeKb.toInt());
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _compressAndSaveJpgToPhone(List images, String title, {required int targetKb}) async {
    try {
      final targetFolder = await _getPublicStorageFolder(isPdf: false);
      List<String> compressedPaths = [];
      double perPageKb = targetKb / (images.isEmpty ? 1 : images.length);

      for (int i = 0; i < images.length; i++) {
        final f = File(images[i]);
        if (await f.exists()) {
          final rawBytes = await f.readAsBytes();
          int targetW = perPageKb < 150 ? 800 : (perPageKb < 300 ? 1100 : 1400);

          final codec = await ui.instantiateImageCodec(rawBytes, targetWidth: targetW);
          final frame = await codec.getNextFrame();
          final resized = await frame.image.toByteData(format: ui.ImageByteFormat.png);

          final outF = File('${targetFolder.path}/${title}_p$i.jpg');
          if (resized != null) {
            await outF.writeAsBytes(resized.buffer.asUint8List());
            compressedPaths.add(outF.path);
          }
        }
      }
      _showToast('✅ Saved ${compressedPaths.length} compressed JPG(s) in Gallery!');
    } catch (e) {
      _showToast('Compress error: $e');
    }
  }

  Future<void> _compressAndShareJpg(List images, String title, {required int targetKb}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      List<XFile> shareFiles = [];
      double perPageKb = targetKb / (images.isEmpty ? 1 : images.length);

      for (int i = 0; i < images.length; i++) {
        final f = File(images[i]);
        if (await f.exists()) {
          final rawBytes = await f.readAsBytes();
          int targetW = perPageKb < 150 ? 800 : (perPageKb < 300 ? 1100 : 1400);

          final codec = await ui.instantiateImageCodec(rawBytes, targetWidth: targetW);
          final frame = await codec.getNextFrame();
          final resized = await frame.image.toByteData(format: ui.ImageByteFormat.png);

          final outF = File('${tempDir.path}/${title}_p$i.jpg');
          if (resized != null) {
            await outF.writeAsBytes(resized.buffer.asUint8List());
            shareFiles.add(XFile(outF.path));
          }
        }
      }
      if (shareFiles.isNotEmpty) {
        await Share.shareXFiles(shareFiles, text: '$title - Bharat Document Scanner PDF AI');
      }
    } catch (e) {
      _showToast('Share error: $e');
    }
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
                  items: _savedDocs.map((doc) => DropdownMenuItem<String>(value: doc['id'].toString(), child: Text(doc['title'] ?? 'Untitled', overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedDocId = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(controller: wmCtrl, decoration: const InputDecoration(labelText: 'Watermark Text', border: OutlineInputBorder())),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  final chosenDoc = _savedDocs.firstWhere((d) => d['id'] == selectedDocId, orElse: () => _savedDocs.first);
                  _exportPdfWithTargetSize(chosenDoc['images'], "${chosenDoc['title']}_Watermarked", watermark: wmCtrl.text.trim());
                },
                child: const Text('Apply & Share PDF'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openPasswordProtectDialog() {
    if (_savedDocs.isEmpty) {
      _showToast('Please scan a document first.');
      return;
    }
    String selectedDocId = _savedDocs.first['id'];
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Lock PDF with Password', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDocId,
                  decoration: const InputDecoration(labelText: 'Select Document', border: OutlineInputBorder()),
                  items: _savedDocs.map((doc) => DropdownMenuItem<String>(value: doc['id'].toString(), child: Text(doc['title'] ?? 'Untitled', overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedDocId = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Enter Password', border: OutlineInputBorder())),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                onPressed: () {
                  if (passCtrl.text.trim().isEmpty) {
                    _showToast('Please enter a valid password.');
                    return;
                  }
                  Navigator.pop(ctx);
                  final chosenDoc = _savedDocs.firstWhere((d) => d['id'] == selectedDocId, orElse: () => _savedDocs.first);
                  _exportPdfWithTargetSize(chosenDoc['images'], "${chosenDoc['title']}_Protected", userPassword: passCtrl.text.trim());
                },
                child: const Text('Lock & Share PDF'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _extractTextWithAI(String imagePath) async {
    String extractedText = '';
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      extractedText = recognizedText.text;
    } catch (e) {
      debugPrint("OCR Err: $e");
    }

    if (!mounted) return;
    if (extractedText.trim().isEmpty) {
      _showToast('No readable text detected.');
      return;
    }

    final textCtrl = TextEditingController(text: extractedText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: appPrimaryColor.value),
                    const SizedBox(width: 8),
                    const Text('AI Text Extraction Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: textCtrl.text));
                    _showToast('Copied to clipboard!');
                  },
                ),
              ],
            ),
            const Divider(),
            TextField(
              controller: textCtrl,
              maxLines: 8,
              decoration: InputDecoration(filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share Extracted Text', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                onPressed: () => Share.share(textCtrl.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<pw.Document> _generatePdfDoc(List images, {int? targetKb, String? watermark}) async {
    final pdf = pw.Document();
    final double perPageKb = (targetKb != null && images.isNotEmpty) ? (targetKb / images.length) : 800;

    for (var path in images) {
      final f = File(path);
      if (await f.exists()) {
        Uint8List finalBytes;
        final rawBytes = await f.readAsBytes();

        if (perPageKb < 600) {
          int targetW = 1200;
          if (perPageKb < 150) {
            targetW = 750;
          } else if (perPageKb < 300) {
            targetW = 950;
          }

          final codec = await ui.instantiateImageCodec(rawBytes, targetWidth: targetW);
          final frame = await codec.getNextFrame();
          final resizedData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          finalBytes = resizedData != null ? resizedData.buffer.asUint8List() : rawBytes;
        } else {
          finalBytes = rawBytes;
        }

        final img = pw.MemoryImage(finalBytes);
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
    return pdf;
  }

  Future<void> _exportPdfWithTargetSize(List images, String title, {int? targetKb, String? watermark, String? userPassword}) async {
    _showInterstitialAd();
    final pdf = await _generatePdfDoc(images, targetKb: targetKb, watermark: watermark);
    Uint8List pdfBytes = await pdf.save();

    final dir = await getTemporaryDirectory();
    final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File("${dir.path}/$safeName.pdf");
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path)], text: '$title - Bharat Document Scanner PDF AI');
  }

  Future<void> _shareImages(List images, String title) async {
    List<XFile> shareFiles = [];
    for (int i = 0; i < images.length; i++) {
      final f = File(images[i]);
      if (await f.exists()) shareFiles.add(XFile(f.path));
    }
    if (shareFiles.isNotEmpty) {
      await Share.shareXFiles(shareFiles, text: '$title - Bharat Document Scanner PDF AI');
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: appPrimaryColor.value, duration: const Duration(seconds: 2)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: _buildAppDrawer(isDark),
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedDocIds.length} Selected', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
            : (_isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(hintText: AppLang.tr('search'), border: InputBorder.none),
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: appPrimaryColor.value, borderRadius: BorderRadius.circular(6)),
                        child: const Text('AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Bharat Document Scanner PDF AI',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              tooltip: AppLang.tr('select_all'),
              icon: const Icon(Icons.select_all_rounded),
              onPressed: () {
                setState(() {
                  if (_selectedDocIds.length == _filteredDocs.length) {
                    _selectedDocIds.clear();
                  } else {
                    _selectedDocIds.addAll(_filteredDocs.map((d) => d['id'].toString()));
                  }
                });
              },
            ),
            IconButton(
              tooltip: 'Share JPG',
              icon: const Icon(Icons.image_rounded),
              onPressed: _selectedDocIds.isEmpty
                  ? null
                  : () {
                      List<String> imgs = [];
                      for (var id in _selectedDocIds) {
                        final d = _savedDocs.firstWhere((e) => e['id'] == id, orElse: () => {});
                        if (d['images'] != null) imgs.addAll(List<String>.from(d['images']));
                      }
                      if (imgs.isNotEmpty) _shareImages(imgs, "Selected_Pages");
                    },
            ),
            IconButton(
              tooltip: 'Merge PDF',
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _selectedDocIds.isEmpty ? null : _mergeAndShareSelectedDocs,
            ),
            IconButton(
              tooltip: AppLang.tr('delete'),
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              onPressed: _selectedDocIds.isEmpty ? null : _deleteSelectedDocs,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedDocIds.clear();
              }),
            ),
          ] else ...[
            TextButton.icon(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.translate_rounded, size: 16),
              label: Text(isHindiLanguage.value ? 'हिन्दी' : 'EN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () async {
                final nextVal = !isHindiLanguage.value;
                isHindiLanguage.value = nextVal;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('app_language_hindi', nextVal);
              },
            ),
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search_rounded, size: 22),
              onPressed: () => setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              }),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          _currentTabIndex == 0 ? _buildDocsTab() : _buildToolsTab(),
          Positioned(
            right: 16,
            bottom: 16,
            child: _buildDualFabPill(),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: ValueListenableBuilder<Color>(
        valueListenable: appPrimaryColor,
        builder: (_, col, __) {
          return Container(
            height: 56,
            width: 56,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [col, col.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: col.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
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
          );
        },
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(AppLang.tr('docs'), Icons.folder_special_rounded, _currentTabIndex == 0, () => setState(() => _currentTabIndex = 0)),
                const SizedBox(width: 48),
                _buildNavItem(AppLang.tr('tools'), Icons.auto_awesome_mosaic_rounded, _currentTabIndex == 1, () => setState(() => _currentTabIndex = 1)),
              ],
            ),
          ),
          if (_isBannerLoaded && _bannerAd != null)
            SafeArea(
              top: false,
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String label, IconData icon, bool isSel, VoidCallback onTap) {
    final color = isSel ? appPrimaryColor.value : Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocsTab() {
    int totalPages = _savedDocs.fold(0, (sum, item) => sum + (item['pages'] as int? ?? 1));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).cardColor,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(AppLang.tr('total_files'), '${_savedDocs.length}', Icons.insert_drive_file_rounded),
              Container(width: 1, height: 24, color: Colors.grey.shade300),
              _buildStat(AppLang.tr('scanned_pages'), '$totalPages', Icons.pages_rounded),
            ],
          ),
        ),
        const SizedBox(height: 10),
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
                  labelStyle: TextStyle(color: isSel ? Colors.white : null, fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                  onSelected: (val) => setState(() {
                    _selectedCategory = cat;
                    _filterDocs();
                  }),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Documents (${_filteredDocs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Row(
              children: [
                if (!_isSelectionMode && _filteredDocs.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.checklist_rounded, size: 16),
                    label: const Text('Select', style: TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _isSelectionMode = true),
                  ),
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 18),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ),
          ],
        ),
        if (_filteredDocs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.folder_open_rounded, size: 54, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(AppLang.tr('no_docs'), style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                    label: Text(AppLang.tr('scan_now')),
                    onPressed: _openAddNewDocumentSheet,
                  ),
                ],
              ),
            ),
          )
        else if (_isGridView)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72),
            itemBuilder: (ctx, i) => _buildDocGridCard(_filteredDocs[i]),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            itemBuilder: (ctx, i) => _buildDocListTile(_filteredDocs[i]),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStat(String label, String count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: appPrimaryColor.value),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildDocListTile(Map<String, dynamic> doc) {
    final String id = doc['id'];
    final bool isSelected = _selectedDocIds.contains(id);
    final List imgs = doc['images'] ?? [];
    final bool hasImage = imgs.isNotEmpty && File(imgs.first).existsSync();

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? appPrimaryColor.value : Colors.grey.withOpacity(0.2), width: isSelected ? 2 : 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: hasImage ? Image.file(File(imgs.first), width: 50, height: 60, fit: BoxFit.cover) : Container(width: 50, height: 60, color: Colors.grey.shade200),
            ),
            if (_isSelectionMode)
              Positioned(
                top: 0,
                left: 0,
                child: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? appPrimaryColor.value : Colors.white),
              ),
          ],
        ),
        title: Text(doc['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
        subtitle: Text('${doc['pages']} pages • ${doc['category'] ?? 'General'} • ${doc['date']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        trailing: _isSelectionMode
            ? Checkbox(
                activeColor: appPrimaryColor.value,
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedDocIds.add(id);
                    } else {
                      _selectedDocIds.remove(id);
                    }
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onPressed: () => _openDocDetail(doc),
              ),
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedDocIds.remove(id);
              } else {
                _selectedDocIds.add(id);
              }
            });
          } else {
            _openDocDetail(doc);
          }
        },
        onLongPress: () {
          setState(() {
            _isSelectionMode = true;
            _selectedDocIds.add(id);
          });
        },
      ),
    );
  }

  Widget _buildDocGridCard(Map<String, dynamic> doc) {
    final String id = doc['id'];
    final bool isSelected = _selectedDocIds.contains(id);
    final List imgs = doc['images'] ?? [];
    final bool hasImg = imgs.isNotEmpty && File(imgs.first).existsSync();

    return InkWell(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedDocIds.remove(id);
            } else {
              _selectedDocIds.add(id);
            }
          });
        } else {
          _openDocDetail(doc);
        }
      },
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _selectedDocIds.add(id);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? appPrimaryColor.value : Colors.grey.withOpacity(0.2), width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: hasImg ? Image.file(File(imgs.first), fit: BoxFit.cover) : Container(color: Colors.grey.shade200),
                    ),
                  ),
                  if (_isSelectionMode)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: appPrimaryColor.value),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  Text('${doc['pages']} p • ${doc['category'] ?? 'General'}', style: const TextStyle(color: Colors.grey, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDocDetail(Map<String, dynamic> doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          doc: doc,
          onDelete: () => _deleteDoc(doc['id']),
          onDocUpdated: _updateExistingDoc,
          onExtractText: _extractTextWithAI,
          onSharePdf: (paths, title) => _exportPdfWithTargetSize(paths, title),
          onShareImages: _shareImages,
          onCompress: (paths, title) => _openCompressionDialog(paths, title),
          onSaveToPhone: _saveToDeviceStorage,
          onSaveJpgToPhone: _saveJpgToDeviceStorage,
        ),
      ),
    );
  }

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
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard(title: 'ID Card Mode', subtitle: 'Front & Back', icon: Icons.badge_outlined, iconColor: const Color(0xFF1976D2), onTap: () => _startDocScan(limit: 2, category: 'Personal', prefix: 'ID_Card')),
            _buildToolCard(title: 'Passport', subtitle: 'Full Layout', icon: Icons.menu_book_rounded, iconColor: const Color(0xFF388E3C), onTap: () => _startDocScan(limit: 2, category: 'Personal', prefix: 'Passport')),
            _buildToolCard(title: 'Invoices', subtitle: 'Bill Extract', icon: Icons.receipt_long_rounded, iconColor: const Color(0xFFE65100), onTap: () => _startDocScan(limit: 5, category: 'Invoices', prefix: 'Bill')),
            _buildToolCard(title: 'AI OCR', subtitle: 'Extract Text', icon: Icons.auto_awesome, iconColor: const Color(0xFF6A1B9A), onTap: () {
              if (_savedDocs.isNotEmpty && _savedDocs.first['images'].isNotEmpty) {
                _extractTextWithAI(_savedDocs.first['images'][0]);
              } else {
                _startDocScan();
              }
            }),
            _buildToolCard(title: 'From Gallery', subtitle: 'Import Images', icon: Icons.photo_library_outlined, iconColor: const Color(0xFFD81B60), onTap: () => _startDocScan(galleryOnly: true)),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Office & Productivity Suite'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard(title: 'PowerPoint', subtitle: 'Slides Maker', icon: Icons.slideshow_rounded, iconColor: const Color(0xFFD84315), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PowerPointStudioScreen()))),
            _buildToolCard(title: 'Resume Maker', subtitle: 'Pro CV Maker', icon: Icons.assignment_ind_rounded, iconColor: const Color(0xFF0277BD), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeBuilderScreen()))),
            _buildToolCard(title: 'Invoice Maker', subtitle: 'GST Bill & Tax', icon: Icons.receipt_rounded, iconColor: const Color(0xFF2E7D32), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceMakerProScreen()))),
            _buildToolCard(title: 'Letters', subtitle: 'Formal Templates', icon: Icons.mail_outline_rounded, iconColor: const Color(0xFF6A1B9A), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LetterTemplatesScreen()))),
            _buildToolCard(title: 'TXT Editor', subtitle: 'Create & Edit', icon: Icons.edit_note_rounded, iconColor: const Color(0xFF00796B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen(isNotes: false)))),
            _buildToolCard(title: 'Notes Maker', subtitle: 'Quick Notes', icon: Icons.note_alt_outlined, iconColor: const Color(0xFFF57C00), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen(isNotes: true)))),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Image & PDF Studio'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard(title: 'PDF Studio', subtitle: 'Merge & Split', icon: Icons.picture_as_pdf_rounded, iconColor: const Color(0xFFD32F2F), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfStudioScreen(savedDocs: _savedDocs, onExportPdf: (paths, title) => _exportPdfWithTargetSize(paths, title))))),
            _buildToolCard(title: 'Lock PDF', subtitle: 'Set Password', icon: Icons.lock_outline_rounded, iconColor: const Color(0xFF4527A0), onTap: _openPasswordProtectDialog),
            _buildToolCard(title: 'Passport Photo', subtitle: 'Print Sheet', icon: Icons.portrait_rounded, iconColor: const Color(0xFF1565C0), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportPhotoStudioScreen()))),
            _buildToolCard(title: 'Digital Sign', subtitle: 'Multi Color', icon: Icons.draw_rounded, iconColor: const Color(0xFF7B1FA2), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalSignatureScreen()))),
            _buildToolCard(title: 'Compressor', subtitle: 'PDF & JPG', icon: Icons.tune_rounded, iconColor: const Color(0xFF00796B), onTap: () {
              if (_savedDocs.isNotEmpty) {
                final doc = _savedDocs.first;
                _openCompressionDialog(doc['images'], doc['title']);
              } else {
                _showToast('Scan a document first to compress.');
              }
            }),
            _buildToolCard(title: 'Watermark', subtitle: 'Custom Stamp', icon: Icons.branding_watermark_outlined, iconColor: const Color(0xFF0288D1), onTap: _openWatermarkDialog),
            _buildToolCard(title: 'Photo Rotate', subtitle: '90° Angle', icon: Icons.crop_rotate_rounded, iconColor: const Color(0xFF00897B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalImageToolScreen()))),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: appPrimaryColor.value),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildToolCard({required String title, required String subtitle, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle, color: iconColor.withOpacity(0.15)), child: Icon(icon, color: iconColor, size: 22)),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Text(subtitle, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer(bool isDark) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: appPrimaryColor.value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.document_scanner_rounded, size: 36, color: Colors.white),
                SizedBox(height: 8),
                Text('BHARAT SCANNER PDF AI', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('AI Deskew & Ultra Clarity Edition', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          ListTile(
            leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            title: Text(isDark ? 'Light Mode' : 'Dark Mode'),
            onTap: () async {
              appThemeMode.value = isDark ? ThemeMode.light : ThemeMode.dark;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_dark_mode', !isDark);
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_rounded),
            title: const Text('Change Theme Color'),
            subtitle: const Text('Pink (Default) & 8 More Colors'),
            onTap: () {
              Navigator.pop(context);
              _openThemeColorPicker();
            },
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('Language / भाषा'),
            subtitle: Text(isHindiLanguage.value ? 'हिन्दी (Hindi)' : 'English'),
            trailing: Switch(
              value: isHindiLanguage.value,
              activeColor: appPrimaryColor.value,
              onChanged: (val) async {
                isHindiLanguage.value = val;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('app_language_hindi', val);
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.security_rounded),
            title: const Text('Privacy Policy'),
            subtitle: const Text('100% On-Device Secure'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Privacy Policy'),
                  content: const Text(
                    'Bharat Document Scanner PDF AI operates 100% locally on your device.\n\n'
                    '1. Scanned photos & PDF files stay strictly on your phone.\n'
                    '2. Zero files uploaded to external cloud servers.\n'
                    '3. All tools (AI Straightening, OCR, Compress, Sign, Resume) run offline on your device.',
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. SCAN FILTER & AI AUTO-DESKEW REVIEW SCREEN (SCREENSHOT UI)
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
  int _activeTopTab = 1;
  bool _isProcessing = false;
  double _manualDeskewAngle = 0.0;

  late List<String> _currentWorkingPaths;
  late Map<int, String> _pageFilterSelections;

  @override
  void initState() {
    super.initState();
    _currentWorkingPaths = List<String>.from(widget.rawImagePaths);
    _pageFilterSelections = {for (var i = 0; i < widget.rawImagePaths.length; i++) i: 'auto'};
  }

  DocFilterPreset get _currentPreset => kDocFilters.firstWhere(
        (f) => f.id == (_pageFilterSelections[_curPageIndex] ?? 'auto'),
        orElse: () => kDocFilters[1],
      );

  Future<void> _runAutoStraightenAI() async {
    setState(() => _isProcessing = true);
    final curImg = _currentWorkingPaths[_curPageIndex];
    final detectedAngle = await AIDeskewEngine.detectSkewAngle(curImg);

    if (detectedAngle.abs() > 0.4) {
      final straightened = await AIDeskewEngine.rotateAndDeskewImage(curImg, -detectedAngle);
      setState(() {
        _currentWorkingPaths[_curPageIndex] = straightened;
        _manualDeskewAngle = 0.0;
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✨ AI straightened document by ${detectedAngle.toStringAsFixed(1)}°')),
      );
    } else {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Document is already straight and upright!')),
      );
    }
  }

  Future<void> _rotateCurrentPage90() async {
    setState(() => _isProcessing = true);
    final curPath = _currentWorkingPaths[_curPageIndex];
    final bytes = await File(curPath).readAsBytes();
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
      final rotatedFile = File('${appDir.path}/rot_${DateTime.now().millisecondsSinceEpoch}.png');
      await rotatedFile.writeAsBytes(data.buffer.asUint8List());

      setState(() {
        _currentWorkingPaths[_curPageIndex] = rotatedFile.path;
        _isProcessing = false;
      });
    } else {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _applyAndFinish() async {
    setState(() => _isProcessing = true);
    final appDir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${appDir.path}/scans');
    if (!await outDir.exists()) await outDir.create(recursive: true);

    List<String> finalSavedPaths = [];

    for (int i = 0; i < _currentWorkingPaths.length; i++) {
      String sourceImg = _currentWorkingPaths[i];

      if (i == _curPageIndex && _manualDeskewAngle.abs() > 0.5) {
        sourceImg = await AIDeskewEngine.rotateAndDeskewImage(sourceImg, _manualDeskewAngle);
      }

      final filterId = _pageFilterSelections[i] ?? 'auto';
      final preset = kDocFilters.firstWhere((f) => f.id == filterId, orElse: () => kDocFilters[1]);

      if (preset.matrix == null) {
        finalSavedPaths.add(sourceImg);
      } else {
        final f = File(sourceImg);
        final bytes = await f.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final img = frame.image;

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()));
        final paint = Paint()..colorFilter = ColorFilter.matrix(preset.matrix!);
        canvas.drawImage(img, Offset.zero, paint);

        final pic = recorder.endRecording();
        final outImg = await pic.toImage(img.width, img.height);
        final byteData = await outImg.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final outFile = File('${outDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}_p$i.png');
          await outFile.writeAsBytes(byteData.buffer.asUint8List());
          finalSavedPaths.add(outFile.path);
        } else {
          finalSavedPaths.add(sourceImg);
        }
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      Navigator.pop(context);
      widget.onApplyAndProceed(finalSavedPaths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final curImageFile = File(_currentWorkingPaths[_curPageIndex]);
    final activePreset = _currentPreset;

    return Scaffold(
      backgroundColor: const Color(0xFF121316),
      body: SafeArea(
        child: _isProcessing
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF8AB4F8)))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTopPill(
                          title: 'Straighten AI',
                          icon: Icons.auto_awesome,
                          isSelected: _activeTopTab == 0,
                          onTap: () {
                            setState(() => _activeTopTab = 0);
                            _runAutoStraightenAI();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildTopPill(
                          title: 'Filters',
                          icon: Icons.auto_fix_high_rounded,
                          isSelected: _activeTopTab == 1,
                          onTap: () => setState(() => _activeTopTab = 1),
                        ),
                        const SizedBox(width: 8),
                        _buildTopPill(
                          title: 'Crop & Rotate',
                          icon: Icons.crop_rotate_rounded,
                          isSelected: _activeTopTab == 2,
                          onTap: () => setState(() => _activeTopTab = 2),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Center(
                        child: Transform.rotate(
                          angle: _manualDeskewAngle * pi / 180,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: activePreset.matrix != null
                                ? ColorFiltered(
                                    colorFilter: ColorFilter.matrix(activePreset.matrix!),
                                    child: Image.file(curImageFile, fit: BoxFit.contain),
                                  )
                                : Image.file(curImageFile, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_currentWorkingPaths.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_currentWorkingPaths.length, (idx) {
                          return GestureDetector(
                            onTap: () => setState(() => _curPageIndex = idx),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _curPageIndex == idx ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _curPageIndex == idx ? const Color(0xFF8AB4F8) : Colors.grey.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  if (_activeTopTab == 2) ...[
                    Container(
                      color: const Color(0xFF181A1F),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.straighten, color: Colors.white70, size: 18),
                              const SizedBox(width: 8),
                              Text('Tilt / Deskew: ${_manualDeskewAngle.toStringAsFixed(1)}°', style: const TextStyle(color: Colors.white, fontSize: 12)),
                              const Spacer(),
                              TextButton(
                                onPressed: () => setState(() => _manualDeskewAngle = 0.0),
                                child: const Text('Reset', style: TextStyle(color: Color(0xFF8AB4F8), fontSize: 12)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
                                tooltip: 'Rotate 90°',
                                onPressed: _rotateCurrentPage90,
                              ),
                            ],
                          ),
                          Slider(
                            value: _manualDeskewAngle,
                            min: -30.0,
                            max: 30.0,
                            activeColor: const Color(0xFF8AB4F8),
                            inactiveColor: Colors.grey.shade800,
                            onChanged: (val) => setState(() => _manualDeskewAngle = val),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.only(top: 10, bottom: 6),
                      color: const Color(0xFF181A1F),
                      child: SizedBox(
                        height: 105,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: kDocFilters.length,
                          itemBuilder: (ctx, i) {
                            final filter = kDocFilters[i];
                            final isSel = (_pageFilterSelections[_curPageIndex] ?? 'auto') == filter.id;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _pageFilterSelections[_curPageIndex] = filter.id;
                                });
                              },
                              child: Container(
                                width: 82,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: isSel ? const Color(0xFF2A3E5F) : const Color(0xFF23252B),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: isSel ? const Color(0xFF8AB4F8) : Colors.transparent,
                                          width: 2.2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          filter.icon,
                                          color: isSel ? const Color(0xFF8AB4F8) : Colors.white70,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      filter.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                        color: isSel ? const Color(0xFF8AB4F8) : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  Container(
                    color: const Color(0xFF181A1F),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB0CCF9),
                            foregroundColor: const Color(0xFF003062),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 14),
                            elevation: 0,
                          ),
                          onPressed: _applyAndFinish,
                          child: const Text('Apply', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTopPill({required String title, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB0CCF9) : const Color(0xFF26282E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? const Color(0xFF003062) : Colors.white),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF003062) : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. DOCUMENT DETAIL SCREEN
// ============================================================================
class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDelete;
  final Function(Map<String, dynamic>) onDocUpdated;
  final Function(String) onExtractText;
  final Function(List, String) onSharePdf;
  final Function(List, String) onShareImages;
  final Function(List, String) onCompress;
  final Function(List, String) onSaveToPhone;
  final Function(List, String) onSaveJpgToPhone;

  const DocumentDetailScreen({
    super.key,
    required this.doc,
    required this.onDelete,
    required this.onDocUpdated,
    required this.onExtractText,
    required this.onSharePdf,
    required this.onShareImages,
    required this.onCompress,
    required this.onSaveToPhone,
    required this.onSaveJpgToPhone,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late List<String> _images;
  late List<String> _originalImages;
  late String _title;

  bool _isPageSelectionMode = false;
  final List<int> _selectedPageIndicesOrder = [];

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.doc['images'] ?? []);
    _originalImages = List<String>.from(widget.doc['originalImages'] ?? widget.doc['images'] ?? []);
    _title = widget.doc['title'] ?? 'Document';
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
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
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

  Future<void> _addMoreDocuments({bool gallery = false}) async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: gallery, pageLimit: 20),
    );
    try {
      final res = await scanner.scanDocument();
      if (res?.images != null && res!.images.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final scansDir = Directory('${appDir.path}/scans');

        for (int i = 0; i < res.images.length; i++) {
          final tempF = File(res.images[i]);
          if (await tempF.exists()) {
            final targetPath = '${scansDir.path}/doc_${DateTime.now().millisecondsSinceEpoch}_add$i.jpg';
            await tempF.copy(targetPath);
            _images.add(targetPath);
            _originalImages.add(targetPath);
          }
        }

        setState(() {
          widget.doc['images'] = _images;
          widget.doc['originalImages'] = _originalImages;
          widget.doc['pages'] = _images.length;
        });
        widget.onDocUpdated(widget.doc);
      }
    } catch (e) {
      debugPrint("Add page err: $e");
    }
  }

  void _deleteSelectedPages() {
    if (_selectedPageIndicesOrder.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Pages?'),
        content: Text('Are you sure you want to delete ${_selectedPageIndicesOrder.length} page(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final sortedIndices = List<int>.from(_selectedPageIndicesOrder)..sort((a, b) => b.compareTo(a));
              for (int idx in sortedIndices) {
                if (idx < _images.length) {
                  final removedPath = _images.removeAt(idx);
                  if (idx < _originalImages.length) _originalImages.removeAt(idx);
                  final f = File(removedPath);
                  if (await f.exists()) await f.delete();
                }
              }

              if (_images.isEmpty) {
                widget.onDelete();
                Navigator.pop(context);
              } else {
                setState(() {
                  widget.doc['images'] = _images;
                  widget.doc['originalImages'] = _originalImages;
                  widget.doc['pages'] = _images.length;
                  _isPageSelectionMode = false;
                  _selectedPageIndicesOrder.clear();
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

  void _openFullPhotoViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenPhotoViewer(
          images: _images,
          originalImages: _originalImages,
          initialIndex: initialIndex,
          title: _title,
          onDocUpdated: () {
            setState(() {
              _images = List<String>.from(widget.doc['images']);
            });
            widget.onDocUpdated(widget.doc);
          },
          onExtractText: widget.onExtractText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _renameDoc,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(_title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              const Icon(Icons.edit, size: 14),
            ],
          ),
        ),
        actions: [
          if (_isPageSelectionMode) ...[
            IconButton(
              tooltip: 'Delete Selected',
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              onPressed: _deleteSelectedPages,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _isPageSelectionMode = false;
                _selectedPageIndicesOrder.clear();
              }),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Select Pages Order',
              icon: const Icon(Icons.checklist_rounded),
              onPressed: () => setState(() => _isPageSelectionMode = true),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: 'Delete Document',
              onPressed: () {
                widget.onDelete();
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_images.length} Pages • Folder: ${widget.doc['category'] ?? 'General'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appPrimaryColor.value,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                  label: Text(AppLang.tr('add_more')),
                  onPressed: () => _addMoreDocuments(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _images.isEmpty
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
                      final rankIndex = _selectedPageIndicesOrder.indexOf(idx);
                      final isChosen = rankIndex != -1;
                      final file = File(_images[idx]);

                      return InkWell(
                        onTap: () {
                          if (_isPageSelectionMode) {
                            setState(() {
                              if (isChosen) {
                                _selectedPageIndicesOrder.remove(idx);
                              } else {
                                _selectedPageIndicesOrder.add(idx);
                              }
                            });
                          } else {
                            _openFullPhotoViewer(idx);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isChosen ? appPrimaryColor.value : Colors.grey.withOpacity(0.3),
                              width: isChosen ? 3 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: file.existsSync()
                                      ? Image.file(file, fit: BoxFit.cover)
                                      : Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image)),
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
                              if (_isPageSelectionMode)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isChosen ? appPrimaryColor.value : Colors.black45,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    child: Center(
                                      child: isChosen
                                          ? Text('${rankIndex + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
                                          : null,
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
      bottomNavigationBar: Container(
        color: Theme.of(context).cardColor,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionBtn(Icons.download_rounded, 'Save PDF', () => widget.onSaveToPhone(_images, _title)),
              _buildActionBtn(Icons.save_alt_rounded, 'Save JPG', () => widget.onSaveJpgToPhone(_images, _title)),
              _buildActionBtn(Icons.picture_as_pdf_rounded, 'Share PDF', () => widget.onSharePdf(_images, _title)),
              _buildActionBtn(Icons.image_rounded, 'Share JPG', () => widget.onShareImages(_images, _title)),
              _buildActionBtn(Icons.tune_rounded, 'Compress', () => widget.onCompress(_images, _title)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: appPrimaryColor.value, size: 20),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 5. FULL SCREEN PHOTO VIEWER
// ============================================================================
class FullScreenPhotoViewer extends StatefulWidget {
  final List<String> images;
  final List<String> originalImages;
  final int initialIndex;
  final String title;
  final VoidCallback onDocUpdated;
  final Function(String) onExtractText;

  const FullScreenPhotoViewer({
    super.key,
    required this.images,
    required this.originalImages,
    required this.initialIndex,
    required this.title,
    required this.onDocUpdated,
    required this.onExtractText,
  });

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late PageController _pageCtrl;
  late int _curPage;

  @override
  void initState() {
    super.initState();
    _curPage = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  void _resetImage() {
    if (_curPage < widget.originalImages.length) {
      setState(() {
        widget.images[_curPage] = widget.originalImages[_curPage];
      });
      widget.onDocUpdated();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Restored Original Camera Photo.')));
    }
  }

  Future<void> _rotatePage() async {
    final curPath = widget.images[_curPage];
    final bytes = await File(curPath).readAsBytes();
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

      setState(() {
        widget.images[_curPage] = f.path;
      });
      widget.onDocUpdated();
    }
  }

  Future<void> _applyAdvancedAIFilter(int filterType) async {
    if (widget.images.isEmpty) return;

    ColorFilter? filter;
    switch (filterType) {
      case 1:
        filter = const ColorFilter.matrix([
          1.65, 0.05, 0.05, 0, -36,
          0.05, 1.65, 0.05, 0, -36,
          0.05, 0.05, 1.65, 0, -36,
          0,    0,    0,    1, 0,
        ]);
        break;
      case 2:
        filter = const ColorFilter.matrix([
          2.2, 2.2, 2.2, 0, -300,
          2.2, 2.2, 2.2, 0, -300,
          2.2, 2.2, 2.2, 0, -300,
          0,   0,   0,   1, 0,
        ]);
        break;
      case 3:
        filter = const ColorFilter.matrix([
          1.4, 0,   0,   0, -5,
          0,   1.4, 0,   0, -5,
          0,   0,   1.4, 0, -5,
          0,   0,   0,   1, 0,
        ]);
        break;
      case 4:
        filter = const ColorFilter.matrix([
          1.3, 0,   0,   0, 35,
          0,   1.3, 0,   0, 35,
          0,   0,   1.3, 0, 35,
          0,   0,   0,   1, 0,
        ]);
        break;
      case 5:
        filter = const ColorFilter.matrix([
          0.30, 0.59, 0.11, 0, 0,
          0.30, 0.59, 0.11, 0, 0,
          0.30, 0.59, 0.11, 0, 0,
          0,    0,    0,    1, 0,
        ]);
        break;
    }

    if (filter == null) return;

    final sourcePath = (_curPage < widget.originalImages.length) ? widget.originalImages[_curPage] : widget.images[_curPage];
    final currFile = File(sourcePath);
    final bytes = await currFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()));
    final paint = Paint()..colorFilter = filter;
    canvas.drawImage(img, Offset.zero, paint);

    final picture = recorder.endRecording();
    final outputImg = await picture.toImage(img.width, img.height);
    final byteData = await outputImg.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final newFile = File('${appDir.path}/scans/ai_clean_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await newFile.writeAsBytes(byteData.buffer.asUint8List());

      setState(() {
        widget.images[_curPage] = newFile.path;
      });
      widget.onDocUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ AI Filter applied. Tap Reset anytime.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.title} (${_curPage + 1}/${widget.images.length})', style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(icon: const Icon(Icons.rotate_right_rounded), tooltip: 'Rotate 90°', onPressed: _rotatePage),
          IconButton(icon: const Icon(Icons.restore_rounded, color: Colors.orangeAccent), tooltip: 'Reset to Original', onPressed: _resetImage),
          PopupMenuButton<int>(
            tooltip: 'AI Clarity Filters',
            icon: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF80CBC4)),
            onSelected: _applyAdvancedAIFilter,
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 1, child: Text('✨ AI Ultra Paper Whitener')),
              PopupMenuItem(value: 2, child: Text('📄 Super Deep Black Text')),
              PopupMenuItem(value: 3, child: Text('🎨 AI Vibrant HD Color')),
              PopupMenuItem(value: 4, child: Text('☀️ AI Shadow & Noise Remover')),
              PopupMenuItem(value: 5, child: Text('🩶 Studio Grayscale Pro')),
            ],
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _curPage = i),
        itemBuilder: (ctx, i) {
          final file = File(widget.images[i]);
          return InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 5.0,
            child: Center(
              child: file.existsSync()
                  ? Image.file(file, fit: BoxFit.contain)
                  : const Text('Image file not found', style: TextStyle(color: Colors.white)),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('AI OCR Text'),
                onPressed: () {
                  if (widget.images.isNotEmpty) widget.onExtractText(widget.images[_curPage]);
                },
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share JPG'),
                onPressed: () {
                  if (widget.images.isNotEmpty) Share.shareXFiles([XFile(widget.images[_curPage])]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 6. PDF STUDIO (Merge PDFs)
// ============================================================================
class PdfStudioScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedDocs;
  final Function(List, String) onExportPdf;

  const PdfStudioScreen({super.key, required this.savedDocs, required this.onExportPdf});

  @override
  State<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends State<PdfStudioScreen> {
  final Set<String> _selectedMergeDocIds = {};

  void _executeMerge() {
    if (_selectedMergeDocIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least 2 documents to merge.')));
      return;
    }
    List<String> combined = [];
    for (String id in _selectedMergeDocIds) {
      final doc = widget.savedDocs.firstWhere((d) => d['id'] == id, orElse: () => {});
      if (doc.isNotEmpty && doc['images'] != null) {
        combined.addAll(List<String>.from(doc['images']));
      }
    }
    if (combined.isNotEmpty) {
      widget.onExportPdf(combined, "Merged_Doc_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge Documents into PDF')),
      body: widget.savedDocs.isEmpty
          ? const Center(child: Text('No documents scanned yet.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.savedDocs.length,
                    itemBuilder: (ctx, i) {
                      final doc = widget.savedDocs[i];
                      final isSel = _selectedMergeDocIds.contains(doc['id']);
                      return CheckboxListTile(
                        activeColor: appPrimaryColor.value,
                        title: Text(doc['title'] ?? 'Untitled'),
                        subtitle: Text('${doc['pages']} pages'),
                        value: isSel,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedMergeDocIds.add(doc['id']);
                            } else {
                              _selectedMergeDocIds.remove(doc['id']);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text('Merge Selected (${_selectedMergeDocIds.length})'),
                      onPressed: _executeMerge,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ============================================================================
// 7. DIGITAL SIGNATURE SCREEN
// ============================================================================
class StrokeLine {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  StrokeLine({required this.points, required this.color, required this.strokeWidth});
}

class DigitalSignatureScreen extends StatefulWidget {
  const DigitalSignatureScreen({super.key});
  @override
  State<DigitalSignatureScreen> createState() => _DigitalSignatureScreenState();
}

class _DigitalSignatureScreenState extends State<DigitalSignatureScreen> {
  final List<StrokeLine> _lines = [];
  Color _penColor = Colors.black;
  double _penSize = 3.5;

  final List<Color> _penColors = [
    Colors.black,
    const Color(0xFF1565C0),
    const Color(0xFFD32F2F),
    const Color(0xFF2E7D32),
    const Color(0xFF6A1B9A),
  ];

  void _undo() {
    if (_lines.isNotEmpty) {
      setState(() => _lines.removeLast());
    }
  }

  Future<void> _saveAndShareSignature({bool saveToStorage = false}) async {
    if (_lines.isEmpty) return;

    double minX = 10000, maxX = 0, minY = 10000, maxY = 0;
    for (var line in _lines) {
      for (var p in line.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    const padding = 20.0;
    minX = (minX - padding).clamp(0, 5000);
    minY = (minY - padding).clamp(0, 5000);
    final width = (maxX - minX + (padding * 2)).clamp(60.0, 5000.0);
    final height = (maxY - minY + (padding * 2)).clamp(60.0, 5000.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.translate(-minX, -minY);

    for (var line in _lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = line.strokeWidth;

      for (int i = 0; i < line.points.length - 1; i++) {
        canvas.drawLine(line.points[i], line.points[i + 1], paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final dir = saveToStorage ? await getApplicationDocumentsDirectory() : await getTemporaryDirectory();
      final file = File("${dir.path}/Sign_${DateTime.now().millisecondsSinceEpoch}.png");
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (saveToStorage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Signature saved: ${file.path}')));
      } else {
        await Share.shareXFiles([XFile(file.path)], text: 'My Signature - Bharat Document Scanner PDF AI');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Signature Pro'),
        actions: [
          IconButton(icon: const Icon(Icons.undo_rounded), tooltip: 'Undo', onPressed: _undo),
          IconButton(icon: const Icon(Icons.clear_rounded), tooltip: 'Clear All', onPressed: () => setState(() => _lines.clear())),
          IconButton(icon: const Icon(Icons.save_alt_rounded), tooltip: 'Save to Phone', onPressed: () => _saveAndShareSignature(saveToStorage: true)),
          IconButton(icon: const Icon(Icons.share_rounded), tooltip: 'Share Sign PNG', onPressed: () => _saveAndShareSignature(saveToStorage: false)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Text('Color: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ..._penColors.map((c) => InkWell(
                      onTap: () => setState(() => _penColor = c),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: _penColor == c ? Colors.black : Colors.transparent, width: 2),
                        ),
                      ),
                    )),
                const Spacer(),
                const Text('Size: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Slider(
                  value: _penSize,
                  min: 1.5,
                  max: 8.0,
                  activeColor: _penColor,
                  onChanged: (v) => setState(() => _penSize = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: GestureDetector(
                onPanStart: (d) {
                  setState(() {
                    _lines.add(StrokeLine(points: [d.localPosition], color: _penColor, strokeWidth: _penSize));
                  });
                },
                onPanUpdate: (d) {
                  setState(() {
                    if (_lines.isNotEmpty) {
                      _lines.last.points.add(d.localPosition);
                    }
                  });
                },
                child: CustomPaint(painter: _MultiColorSigPainter(_lines), size: Size.infinite),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiColorSigPainter extends CustomPainter {
  final List<StrokeLine> lines;
  _MultiColorSigPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    for (var line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = line.strokeWidth;

      for (int i = 0; i < line.points.length - 1; i++) {
        canvas.drawLine(line.points[i], line.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================================
// 8. PASSPORT PHOTO STUDIO
// ============================================================================
class PassportPhotoStudioScreen extends StatefulWidget {
  const PassportPhotoStudioScreen({super.key});
  @override
  State<PassportPhotoStudioScreen> createState() => _PassportPhotoStudioScreenState();
}

class _PassportPhotoStudioScreenState extends State<PassportPhotoStudioScreen> {
  String? _selectedImagePath;
  int _photoCount = 8;
  bool _addWhiteBorder = true;

  Future<void> _pickPhoto() async {
    final scanner = DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 1));
    final res = await scanner.scanDocument();
    if (res?.images != null && res!.images.isNotEmpty) {
      setState(() => _selectedImagePath = res.images.first);
    }
  }

  Future<void> _generateSheet({bool isJpg = false, bool saveStorage = false}) async {
    if (_selectedImagePath == null) return;

    final imgBytes = await File(_selectedImagePath!).readAsBytes();

    if (isJpg) {
      const a4Width = 1240.0;
      const a4Height = 1754.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, a4Width, a4Height));
      canvas.drawRect(const Rect.fromLTWH(0, 0, a4Width, a4Height), Paint()..color = Colors.white);

      final codec = await ui.instantiateImageCodec(imgBytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;

      double w = _photoCount <= 8 ? 260.0 : 180.0;
      double h = _photoCount <= 8 ? 340.0 : 240.0;
      int cols = _photoCount <= 8 ? 4 : 5;

      double startX = 60;
      double startY = 80;
      double gapX = 25;
      double gapY = 30;

      for (int i = 0; i < _photoCount; i++) {
        int r = i ~/ cols;
        int c = i % cols;
        double x = startX + c * (w + gapX);
        double y = startY + r * (h + gapY);

        final targetRect = Rect.fromLTWH(x, y, w, h);
        canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), targetRect, Paint());
        if (_addWhiteBorder) {
          canvas.drawRect(targetRect, Paint()..color = Colors.grey.shade400..style = PaintingStyle.stroke..strokeWidth = 2);
        }
      }

      final pic = recorder.endRecording();
      final finalImg = await pic.toImage(a4Width.toInt(), a4Height.toInt());
      final byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final dir = saveStorage ? await getApplicationDocumentsDirectory() : await getTemporaryDirectory();
        final file = File("${dir.path}/Passport_Sheet_${DateTime.now().millisecondsSinceEpoch}.jpg");
        await file.writeAsBytes(byteData.buffer.asUint8List());

        if (saveStorage) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ JPG Sheet saved: ${file.path}')));
        } else {
          await Share.shareXFiles([XFile(file.path)], text: 'Passport Photos Print Sheet');
        }
      }
    } else {
      final pdf = pw.Document();
      final passImage = pw.MemoryImage(imgBytes);
      final double width = _photoCount <= 8 ? 110 : 80;
      final double height = _photoCount <= 8 ? 145 : 105;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Wrap(
              spacing: 12,
              runSpacing: 16,
              children: List.generate(_photoCount, (i) => pw.Container(
                    width: width,
                    height: height,
                    decoration: _addWhiteBorder ? pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 1)) : null,
                    child: pw.Image(passImage, fit: pw.BoxFit.cover),
                  )),
            );
          },
        ),
      );
      final dir = saveStorage ? await getApplicationDocumentsDirectory() : await getTemporaryDirectory();
      final file = File("${dir.path}/Passport_Sheet_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());

      if (saveStorage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ PDF Sheet saved: ${file.path}')));
      } else {
        await Share.shareXFiles([XFile(file.path)], text: 'Passport Photos Print Sheet');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passport Photo Studio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_selectedImagePath != null)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_selectedImagePath!), height: 180, fit: BoxFit.contain),
                ),
              )
            else
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.portrait, size: 60, color: Colors.grey),
                    SizedBox(height: 6),
                    Text('Select a clear portrait photo'),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('Choose Photo (Camera/Gallery)'),
              onPressed: _pickPhoto,
            ),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Select Photo Count:', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 4, label: Text('4')),
                ButtonSegment(value: 8, label: Text('8')),
                ButtonSegment(value: 16, label: Text('16')),
                ButtonSegment(value: 32, label: Text('32')),
              ],
              selected: {_photoCount},
              onSelectionChanged: (set) => setState(() => _photoCount = set.first),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add Cut-Guide Border'),
              value: _addWhiteBorder,
              onChanged: (v) => setState(() => _addWhiteBorder = v),
            ),
            const Divider(),
            if (_selectedImagePath != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Share PDF'),
                      onPressed: () => _generateSheet(isJpg: false, saveStorage: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
                      icon: const Icon(Icons.image),
                      label: const Text('Share JPG'),
                      onPressed: () => _generateSheet(isJpg: true, saveStorage: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('Save Sheet to Storage (JPG)'),
                  onPressed: () => _generateSheet(isJpg: true, saveStorage: true),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 9. POWERPOINT STUDIO
// ============================================================================
class PowerPointStudioScreen extends StatefulWidget {
  const PowerPointStudioScreen({super.key});
  @override
  State<PowerPointStudioScreen> createState() => _PowerPointStudioScreenState();
}

class _PowerPointStudioScreenState extends State<PowerPointStudioScreen> {
  final List<Map<String, String>> _slides = [
    {'title': 'Project Intro', 'content': '• Objectives\n• Key Deliverables'},
  ];

  Future<void> _export() async {
    final pdf = pw.Document();
    for (var s in _slides) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (ctx) => pw.Container(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(s['title'] ?? '', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 16),
                pw.Text(s['content'] ?? '', style: const pw.TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ),
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Presentation.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'PowerPoint Slides');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Slides Maker'), actions: [IconButton(icon: const Icon(Icons.share), onPressed: _export)]),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _slides.length,
        itemBuilder: (ctx, i) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextFormField(initialValue: _slides[i]['title'], decoration: const InputDecoration(labelText: 'Title'), onChanged: (v) => _slides[i]['title'] = v),
                TextFormField(initialValue: _slides[i]['content'], maxLines: 3, decoration: const InputDecoration(labelText: 'Bullets'), onChanged: (v) => _slides[i]['content'] = v),
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
// 10. TXT & NOTES MAKER
// ============================================================================
class TxtEditorNotesScreen extends StatefulWidget {
  final bool isNotes;
  const TxtEditorNotesScreen({super.key, required this.isNotes});
  @override
  State<TxtEditorNotesScreen> createState() => _TxtEditorNotesScreenState();
}

class _TxtEditorNotesScreenState extends State<TxtEditorNotesScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isNotes) {
      SharedPreferences.getInstance().then((p) {
        setState(() {
          _title.text = p.getString('saved_note_title') ?? '';
          _body.text = p.getString('saved_note_body') ?? '';
        });
      });
    }
  }

  Future<void> _export() async {
    final prefs = await SharedPreferences.getInstance();
    if (widget.isNotes) {
      await prefs.setString('saved_note_title', _title.text.trim());
      await prefs.setString('saved_note_body', _body.text.trim());
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/${_title.text.isEmpty ? 'Note' : _title.text}.txt");
    await file.writeAsString(_body.text);
    await Share.shareXFiles([XFile(file.path)], text: 'Exported Note');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isNotes ? 'Quick Notes' : 'TXT Editor'), actions: [IconButton(icon: const Icon(Icons.save), onPressed: _export)]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _title, decoration: const InputDecoration(hintText: 'Title...', border: InputBorder.none)),
            const Divider(),
            Expanded(child: TextField(controller: _body, maxLines: null, expands: true, decoration: const InputDecoration(hintText: 'Start typing...', border: InputBorder.none))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 11. RESUME BUILDER
// ============================================================================
class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});
  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final _name = TextEditingController(text: 'Rahul Kumar');
  final _phone = TextEditingController(text: '+91 98765 43210');
  final _email = TextEditingController(text: 'rahul.kumar@email.com');
  final _summary = TextEditingController(text: 'Dedicated professional seeking growth opportunities.');
  final _experience = TextEditingController(text: '• 2+ Years experience in Operations & IT.');
  final _education = TextEditingController(text: '• Bachelor of Technology / Graduate');
  final _skills = TextEditingController(text: 'Teamwork, Problem Solving, Communication');

  Future<void> _export() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_name.text, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
              pw.Text('${_phone.text} | ${_email.text}'),
              pw.Divider(thickness: 1.5, color: PdfColors.pink),
              pw.SizedBox(height: 8),
              pw.Text('Profile Summary:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_summary.text),
              pw.SizedBox(height: 8),
              pw.Text('Work Experience:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_experience.text),
              pw.SizedBox(height: 8),
              pw.Text('Education:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_education.text),
              pw.SizedBox(height: 8),
              pw.Text('Skills:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_skills.text),
            ],
          ),
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Resume.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Professional Resume');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resume Maker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _summary, maxLines: 2, decoration: const InputDecoration(labelText: 'Summary', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _experience, maxLines: 2, decoration: const InputDecoration(labelText: 'Experience', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _education, maxLines: 2, decoration: const InputDecoration(labelText: 'Education', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _skills, decoration: const InputDecoration(labelText: 'Skills', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: appPrimaryColor.value,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _export,
              child: const Text('Generate Resume PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 12. INVOICE MAKER (GST Tax Calculation)
// ============================================================================
class InvoiceMakerProScreen extends StatefulWidget {
  const InvoiceMakerProScreen({super.key});
  @override
  State<InvoiceMakerProScreen> createState() => _InvoiceMakerProScreenState();
}

class _InvoiceMakerProScreenState extends State<InvoiceMakerProScreen> {
  final _client = TextEditingController(text: 'Client Name');
  final _invoiceNum = TextEditingController(text: 'INV-2026-001');
  final _itemName = TextEditingController();
  final _itemPrice = TextEditingController();
  List<Map<String, dynamic>> items = [
    {'name': 'Document Services', 'price': 1200.0},
    {'name': 'Processing Fee', 'price': 300.0},
  ];

  Future<void> _export() async {
    final pdf = pw.Document();
    double sub = items.fold(0.0, (s, i) => s + (i['price'] as double));
    double cgst = sub * 0.09;
    double sgst = sub * 0.09;
    double grandTotal = sub + cgst + sgst;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
              pw.Text('Invoice No: ${_invoiceNum.text} | Client: ${_client.text}'),
              pw.Divider(thickness: 1.5, color: PdfColors.pink),
              pw.TableHelper.fromTextArray(
                headers: ['Item / Service Description', 'Amount (INR)'],
                data: items.map((e) => [e['name'], 'INR ${e['price']}']).toList(),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.pink),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 14),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: INR ${sub.toStringAsFixed(2)}'),
                    pw.Text('CGST (9%): INR ${cgst.toStringAsFixed(2)}'),
                    pw.Text('SGST (9%): INR ${sgst.toStringAsFixed(2)}'),
                    pw.Divider(),
                    pw.Text('Grand Total: INR ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.pink)),
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
    await Share.shareXFiles([XFile(file.path)], text: 'Tax Invoice');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice & GST Maker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _client, decoration: const InputDecoration(labelText: 'Client Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _invoiceNum, decoration: const InputDecoration(labelText: 'Invoice Number', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _itemName, decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _itemPrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()))),
                IconButton(
                  icon: Icon(Icons.add_circle, color: appPrimaryColor.value, size: 32),
                  onPressed: () {
                    if (_itemName.text.isNotEmpty && _itemPrice.text.isNotEmpty) {
                      setState(() {
                        items.add({'name': _itemName.text.trim(), 'price': double.tryParse(_itemPrice.text.trim()) ?? 0.0});
                        _itemName.clear();
                        _itemPrice.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map((i) => ListTile(
                  title: Text(i['name']),
                  trailing: Text('INR ${i['price']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: appPrimaryColor.value,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: items.isEmpty ? null : _export,
              child: const Text('Export Invoice PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 13. LETTER TEMPLATES
// ============================================================================
class LetterTemplatesScreen extends StatefulWidget {
  const LetterTemplatesScreen({super.key});
  @override
  State<LetterTemplatesScreen> createState() => _LetterTemplatesScreenState();
}

class _LetterTemplatesScreenState extends State<LetterTemplatesScreen> {
  final _ctrl = TextEditingController(
    text: "To,\nThe HR Manager,\nSubject: Leave Application\n\nRespected Sir/Madam,\nPlease grant me 2 days of leave for urgent work.\n\nThank you.\nSincerely,\n[Your Name]",
  );

  Future<void> _export() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (ctx) => pw.Padding(padding: const pw.EdgeInsets.all(32), child: pw.Text(_ctrl.text, style: const pw.TextStyle(fontSize: 14)))));
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Letter.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Formal Letter');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Letter Maker'), actions: [IconButton(icon: const Icon(Icons.share), onPressed: _export)]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Leave Letter'),
                  onPressed: () => setState(() => _ctrl.text = "To,\nThe Manager,\nSubject: Leave Request\n\nRespected Sir,\nI request leave for 2 days due to personal reasons.\n\nRegards,\n[Your Name]"),
                ),
                ActionChip(
                  label: const Text('Resignation Letter'),
                  onPressed: () => setState(() => _ctrl.text = "To,\nThe Management,\nSubject: Resignation Letter\n\nPlease accept this letter as formal notification of my resignation.\n\nRegards,\n[Your Name]"),
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
// 14. UNIVERSAL IMAGE ROTATE (Physical 90°)
// ============================================================================
class UniversalImageToolScreen extends StatefulWidget {
  const UniversalImageToolScreen({super.key});
  @override
  State<UniversalImageToolScreen> createState() => _UniversalImageToolScreenState();
}

class _UniversalImageToolScreenState extends State<UniversalImageToolScreen> {
  String? _imagePath;

  Future<void> _select() async {
    final scanner = DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 1));
    final res = await scanner.scanDocument();
    if (res?.images != null && res!.images.isNotEmpty) setState(() => _imagePath = res.images.first);
  }

  Future<void> _rotate() async {
    if (_imagePath == null) return;
    final bytes = await File(_imagePath!).readAsBytes();
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
      final f = File('${appDir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(data.buffer.asUint8List());
      setState(() => _imagePath = f.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Rotate Studio'),
        actions: [
          if (_imagePath != null) IconButton(icon: const Icon(Icons.rotate_right), onPressed: _rotate),
          if (_imagePath != null) IconButton(icon: const Icon(Icons.share), onPressed: () => Share.shareXFiles([XFile(_imagePath!)])),
        ],
      ),
      body: Center(
        child: _imagePath == null ? ElevatedButton(onPressed: _select, child: const Text('Select Image')) : Image.file(File(_imagePath!)),
      ),
    );
  }
}
