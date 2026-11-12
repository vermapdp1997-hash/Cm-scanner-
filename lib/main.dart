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
final ValueNotifier<Color> appPrimaryColor = ValueNotifier(const Color(0xFF0288D1));
final ValueNotifier<bool> isHindiLanguage = ValueNotifier(false);

class AppLang {
  static String tr(String key) {
    final bool hi = isHindiLanguage.value;
    final Map<String, List<String>> dict = {
      'docs': ['Documents', 'दस्तावेज़'],
      'tools': ['PDF Tools', 'स्टूडियो टूल्स'],
      'search': ['Search documents...', 'दस्तावेज़ खोजें...'],
      'total_files': ['Total Files', 'कुल फाइलें'],
      'scanned_pages': ['Pages Scanned', 'स्कैन पेज'],
      'all': ['All docs', 'सभी'],
      'recent': ['Recent', 'हाल के'],
      'starred': ['Favourite', 'पसंदीदा'],
      'business_card': ['Business Card', 'बिजनेस कार्ड'],
      'new_folder': ['+ New Folder', '+ नया फ़ोल्डर'],
      'create_folder': ['Create New Folder', 'नया फ़ोल्डर बनाएं'],
      'folder_name': ['Folder Name', 'फ़ोल्डर का नाम'],
      'cancel': ['Cancel', 'रद्द करें'],
      'create': ['Create', 'बनाएं'],
      'save': ['Save to Docs', 'सेव करें'],
      'save_pdf': ['Save PDF', 'PDF सेव करें'],
      'save_jpg': ['Save to Phone', 'फोन में सेव करें'],
      'share_pdf': ['Share PDF', 'PDF शेयर करें'],
      'share_jpg': ['Share JPG', 'JPG शेयर करें'],
      'delete': ['Delete', 'हटाएं'],
      'no_docs': ['No documents found', 'कोई दस्तावेज़ नहीं मिला'],
      'select_all': ['Select All', 'सभी चुनें'],
      'add_more': ['+ Add Pages', '+ और पेज जोड़ें'],
      'add_new_doc': ['Add New Document', 'नया दस्तावेज़ जोड़ें'],
      'choose_options': ['Choose from below options', 'नीचे दिए गए विकल्प चुनें'],
      'from_gallery': ['Import from Gallery', 'गैलरी से चुनें'],
      'from_camera': ['Scan from Camera', 'कैमरे से स्कैन करें'],
      'import_pdf_img': ['Import PDF as Image (Old Version)', 'PDF को फोटो की तरह जोड़ें'],
      'import_docs': ['Import Documents (PDF, Word & More)', 'डॉक्यूमेंट्स फाइलें जोड़ें'],
      'edit_doc': ['Edit / Retouch', 'एडिट करें'],
    };
    if (dict.containsKey(key)) {
      return hi ? dict[key]![1] : dict[key]![0];
    }
    return key;
  }
}

// ============================================================================
// ULTRA-CLARITY COLOR FILTERS WITH REAL-TIME DYNAMIC INTENSITY
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
    final factor = 0.5 + (intensity * 1.5);

    switch (id) {
      case 'magic_book':
        final contrast = 1.75 * factor;
        final offset = -48.0 * factor + (intensity * 55.0);
        return [
          contrast, 0.0, 0.0, 0.0, offset,
          0.0, contrast, 0.0, 0.0, offset,
          0.0, 0.0, contrast, 0.0, offset,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];

      case 'bw_sharp':
        final c = 2.9 * factor;
        final off = -370.0 * factor;
        return [
          c, c, c, 0.0, off,
          c, c, c, 0.0, off,
          c, c, c, 0.0, off,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];

      case 'deshadow':
        final b = 50.0 * factor;
        return [
          1.25, 0.0, 0.0, 0.0, b,
          0.0, 1.25, 0.0, 0.0, b,
          0.0, 0.0, 1.25, 0.0, b,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];

      case 'vibrant_color':
        final s = 1.45 * factor;
        return [
          s, -0.12, -0.12, 0.0, -12,
          -0.12, s, -0.12, 0.0, -12,
          -0.12, -0.12, s, 0.0, -12,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];

      case 'greyscale':
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
// PHONE GALLERY / PUBLIC STORAGE EXPORTER
// ============================================================================
class PhoneStorageManager {
  static Future<int> saveImagesToPublicGallery(List<String> imagePaths, String docTitle) async {
    int savedCount = 0;
    try {
      Directory targetDir;
      final picturesDir = Directory('/storage/emulated/0/Pictures/BharatScanner');
      final dcimDir = Directory('/storage/emulated/0/DCIM/BharatScanner');

      if (await picturesDir.exists() || await picturesDir.create(recursive: true).then((_) => true).catchError((_) => false)) {
        targetDir = picturesDir;
      } else if (await dcimDir.exists() || await dcimDir.create(recursive: true).then((_) => true).catchError((_) => false)) {
        targetDir = dcimDir;
      } else {
        final ext = await getExternalStorageDirectory();
        targetDir = Directory('${ext?.path ?? (await getApplicationDocumentsDirectory()).path}/BharatScanner');
        if (!await targetDir.exists()) await targetDir.create(recursive: true);
      }

      final safeName = docTitle.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      for (int i = 0; i < imagePaths.length; i++) {
        final f = File(imagePaths[i]);
        if (await f.exists()) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final dest = File('${targetDir.path}/${safeName}_p${i + 1}_$timestamp.jpg');
          await f.copy(dest.path);
          savedCount++;
        }
      }
    } catch (e) {
      debugPrint("Gallery export error: $e");
    }
    return savedCount;
  }
}

// ============================================================================
// MAIN FUNCTION & RUN APP
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
            return ValueListenableBuilder<bool>(
              valueListenable: isHindiLanguage,
              builder: (_, __, ____) {
                return MaterialApp(
                  title: 'Doc Scanner',
                  debugShowCheckedModeBanner: false,
                  themeMode: mode,
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.light,
                    scaffoldBackgroundColor: const Color(0xFFF6F8FA),
                    colorSchemeSeed: color,
                    appBarTheme: const AppBarTheme(
                      elevation: 0,
                      backgroundColor: Color(0xFF0F2B3B),
                      foregroundColor: Colors.white,
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
      },
    );
  }
}

// ============================================================================
// 1. ANIMATED SPLASH SCREEN
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
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _animController.forward();

    _timer = Timer(const Duration(milliseconds: 1800), () {
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
      backgroundColor: const Color(0xFF0F2438),
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 2),
                ),
                child: const Icon(Icons.document_scanner_rounded, size: 70, color: Colors.cyanAccent),
              ),
              const SizedBox(height: 20),
              const Text('DOC SCANNER', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
              const SizedBox(height: 4),
              const Text('Ultra Clarity Document & Studio AI', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. MAIN DASHBOARD SCREEN (SCREENSHOT UI RESTORED)
// ============================================================================
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});
  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _navTabController;
  int _currentTopNavIndex = 0; // 0 = Home, 1 = PDF Tools, 2 = Import ID Photo

  List<Map<String, dynamic>> _savedDocs = [];
  List<Map<String, dynamic>> _filteredDocs = [];
  List<String> _userFolders = ['ID Cards', 'Bills', 'New Folder'];
  String _selectedCategory = 'All docs';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _navTabController = TabController(length: 3, vsync: this);
    _navTabController.addListener(() {
      if (_navTabController.indexIsChanging) {
        setState(() => _currentTopNavIndex = _navTabController.index);
      }
    });

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
    final List<String>? customFolders = prefs.getStringList('custom_user_folders_v4');
    if (customFolders != null && customFolders.isNotEmpty) {
      setState(() => _userFolders = customFolders);
    }
  }

  Future<void> _commitUserFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_user_folders_v4', _userFolders);
  }

  Future<void> _loadSavedDocs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString('saved_documents_v7');
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
    await prefs.setString('saved_documents_v7', jsonEncode(_savedDocs));
  }

  void _filterDocs() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredDocs = _savedDocs.where((doc) {
        final title = (doc['title'] ?? '').toString().toLowerCase();
        final matchesSearch = title.contains(q);
        bool matchesCat = true;

        if (_selectedCategory == 'All docs') {
          matchesCat = true;
        } else if (_selectedCategory == 'Favourite') {
          matchesCat = (doc['isFavorite'] == true);
        } else if (_selectedCategory == 'Recent') {
          matchesCat = true;
        } else if (_selectedCategory == 'Business Card') {
          matchesCat = ((doc['category'] ?? '') == 'Business Card');
        } else {
          matchesCat = ((doc['category'] ?? '') == _selectedCategory);
        }

        return matchesSearch && matchesCat;
      }).toList();
    });
  }

  // Scanning flow
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
              if (category == 'ID Cards' && filteredImages.length >= 2) {
                _processIdCardCollage(filteredImages.sublist(0, 2), persistentRawPaths);
              } else {
                _promptSaveDoc(filteredImages, persistentRawPaths, prefix, category);
              }
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint("Scan Err: $e");
    }
  }

  // ID Card A4 Collage
  Future<void> _processIdCardCollage(List<String> frontAndBack, List<String> rawImages) async {
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
      final borderPaint = Paint()..color = const Color(0xFFCFD8DC)..style = PaintingStyle.stroke..strokeWidth = 2.0;

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

        final newDoc = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': 'ID_Card_${DateFormat('ddMMM_HHmm').format(DateTime.now())}',
          'category': 'ID Cards',
          'isFavorite': false,
          'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
          'images': [collageFile.path],
          'originalImages': frontAndBack,
          'pages': 1,
        };

        setState(() {
          _savedDocs.insert(0, newDoc);
          _filterDocs();
        });
        await _commitDocsToPrefs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Front & Back ID Card stitched onto A4 Sheet!')));
        }
      }
    } catch (e) {
      _promptSaveDoc(frontAndBack, rawImages, 'ID_Card', 'ID Cards');
    }
  }

  void _promptSaveDoc(List<String> enhancedImages, List<String> rawImages, String prefix, String defaultCat) {
    final nameCtrl = TextEditingController(text: "${prefix}_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    String chosenFolder = _userFolders.contains(defaultCat) ? defaultCat : (_userFolders.isNotEmpty ? _userFolders.first : 'General');

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
              items: _userFolders.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (val) {
                if (val != null) chosenFolder = val;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
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
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Document Saved!')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _createNewFolderDialog() {
    final folderCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create New Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: folderCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
            onPressed: () async {
              final name = folderCtrl.text.trim();
              if (name.isNotEmpty && !_userFolders.contains(name)) {
                setState(() {
                  _userFolders.add(name);
                  _selectedCategory = name;
                });
                await _commitUserFolders();
                _filterDocs();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // SCREENSHOT 1: ADD NEW DOCUMENT BOTTOM SHEET
  void _openAddNewDocBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Add New Document / Choose from below options)
                Row(
                  children: [
                    Stack(
                      children: [
                        const Icon(Icons.description_rounded, size: 40, color: Color(0xFF00B4D8)),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.add, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Add New Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          SizedBox(height: 2),
                          Text('Choose from below options', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Colors.black54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Option 1: Import from Gallery
                _buildBottomSheetOption(
                  icon: Icons.photo_library_rounded,
                  iconColor: const Color(0xFF00B4D8),
                  title: 'Import from Gallery',
                  onTap: () {
                    Navigator.pop(ctx);
                    _startDocScan(galleryOnly: true);
                  },
                ),

                // Option 2: Scan from Camera
                _buildBottomSheetOption(
                  icon: Icons.camera_alt_rounded,
                  iconColor: const Color(0xFF4A6572),
                  title: 'Scan from Camera',
                  onTap: () {
                    Navigator.pop(ctx);
                    _startDocScan();
                  },
                ),

                // Option 3: Import PDF as Image(Old Version)
                _buildBottomSheetOption(
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: const Color(0xFFEF5350),
                  title: 'Import PDF as Image(Old Version)',
                  onTap: () {
                    Navigator.pop(ctx);
                    _startDocScan(galleryOnly: true, prefix: 'PDF_Import');
                  },
                ),

                // Option 4: Import Documents (PDF, Word & More)
                _buildBottomSheetOption(
                  icon: Icons.insert_drive_file_rounded,
                  iconColor: const Color(0xFFE53935),
                  title: 'Import Documents (PDF, Word & More)',
                  onTap: () {
                    Navigator.pop(ctx);
                    _startDocScan(galleryOnly: true, prefix: 'File_Import');
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  // SCREENSHOT 2: BOTTOM RIGHT DUAL PILL [📷 | ➕]
  Widget _buildDualFabPill() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0288D1),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Camera Direct Button
          InkWell(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(26)),
            onTap: () => _startDocScan(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
            ),
          ),
          // Divider
          Container(width: 1.2, height: 26, color: Colors.white38),
          // Plus Button (Opens Bottom Sheet)
          InkWell(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(26)),
            onTap: _openAddNewDocBottomSheet,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildAppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2B3B),
        foregroundColor: Colors.white,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search documents...',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
              )
            : const Text('Doc Scanner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
            tooltip: 'VIP',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⭐ Doc Scanner Pro Active!')));
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchController.clear();
            }),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'new_folder') _createNewFolderDialog();
              if (val == 'refresh') setState(() => _loadSavedDocs());
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'new_folder', child: Text('New Folder')),
              const PopupMenuItem(value: 'refresh', child: Text('Refresh Documents')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _navTabController,
              labelColor: const Color(0xFF0288D1),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF0288D1),
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.home_rounded, size: 20), text: 'Home'),
                Tab(icon: Icon(Icons.business_center_rounded, size: 20), text: 'PDF Tools'),
                Tab(icon: Icon(Icons.badge_rounded, size: 20), text: 'Import ID Photo'),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _navTabController,
            children: [
              _buildHomeTab(),
              _buildToolsTab(),
              _buildIdCardFastTab(),
            ],
          ),
          // Screen 2 Bottom Right Dual Pill
          Positioned(
            right: 18,
            bottom: 24,
            child: _buildDualFabPill(),
          ),
        ],
      ),
      // Central Floating Camera Button & Bottom Navigation
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isBannerLoaded && _bannerAd != null)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          else
            Container(
              height: 24,
              color: Colors.white,
              alignment: Alignment.center,
              child: const Text('Ad Space', style: TextStyle(color: Colors.black26, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 1: HOME (SCREENSHOT 1 & 2 FOLDERS + CHIPS + FAST DOC LIST)
  // ==========================================================================
  Widget _buildHomeTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Sub Filter Chips (All docs, Recent, Favourite, Business Card)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTopCategoryChip('All docs', Icons.touch_app_rounded),
              _buildTopCategoryChip('Recent', Icons.history_rounded),
              _buildTopCategoryChip('Favourite', Icons.star_rounded),
              _buildTopCategoryChip('Business Card', Icons.credit_card_rounded),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Folders Section Header (Folders (3) [📁+])
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Folders (${_userFolders.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            IconButton(
              icon: const Icon(Icons.create_new_folder_rounded, color: Color(0xFF0F2B3B), size: 24),
              tooltip: 'New Folder',
              onPressed: _createNewFolderDialog,
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Folder Cards (ID Cards, New Folder, Bills, etc.)
        ..._userFolders.map((folderName) => _buildFolderCard(folderName)),

        const SizedBox(height: 16),
        // Saved Documents Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('All Documents (${_filteredDocs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            Text('Filtered: $_selectedCategory', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),

        if (_filteredDocs.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Column(
              children: const [
                Icon(Icons.folder_open_rounded, size: 48, color: Colors.black26),
                SizedBox(height: 8),
                Text('No documents here yet', style: TextStyle(color: Colors.black45)),
              ],
            ),
          )
        else
          ..._filteredDocs.map((doc) => _buildFastDocTile(doc)),

        const SizedBox(height: 90), // Spacing for floating buttons
      ],
    );
  }

  Widget _buildTopCategoryChip(String title, IconData icon) {
    final isSel = _selectedCategory == title;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSel,
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF0288D1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSel ? const Color(0xFF0288D1) : Colors.grey.shade300),
        ),
        avatar: Icon(icon, size: 16, color: isSel ? Colors.white : Colors.black87),
        label: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSel ? Colors.white : Colors.black87)),
        onSelected: (val) {
          setState(() {
            _selectedCategory = title;
            _filterDocs();
          });
        },
      ),
    );
  }

  Widget _buildFolderCard(String folderName) {
    final int count = _savedDocs.where((d) => (d['category'] ?? '') == folderName).length;
    final isSel = _selectedCategory == folderName;

    return Card(
      elevation: 0.5,
      color: isSel ? const Color(0xFFE1F5FE) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSel ? const Color(0xFF0288D1) : Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          setState(() {
            _selectedCategory = isSel ? 'All docs' : folderName;
            _filterDocs();
          });
        },
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: const Color(0xFF0F2B3B), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.folder_rounded, color: Colors.white, size: 26),
        ),
        title: Text(folderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Row(
          children: [
            const Text('Folder • ', style: TextStyle(fontSize: 11, color: Colors.grey)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
              child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
          onSelected: (action) {
            if (action == 'rename') _renameFolderDialog(folderName);
            if (action == 'delete') _deleteFolder(folderName);
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'rename', child: Text('Rename Folder')),
            PopupMenuItem(value: 'delete', child: Text('Delete Folder')),
          ],
        ),
      ),
    );
  }

  void _renameFolderDialog(String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  final idx = _userFolders.indexOf(oldName);
                  if (idx != -1) _userFolders[idx] = newName;
                  for (var d in _savedDocs) {
                    if (d['category'] == oldName) d['category'] = newName;
                  }
                });
                await _commitUserFolders();
                await _commitDocsToPrefs();
                _filterDocs();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteFolder(String folderName) async {
    setState(() {
      _userFolders.remove(folderName);
      if (_selectedCategory == folderName) _selectedCategory = 'All docs';
    });
    await _commitUserFolders();
    _filterDocs();
  }

  Widget _buildFastDocTile(Map<String, dynamic> doc) {
    final List imgs = doc['images'] ?? [];
    final bool hasImg = imgs.isNotEmpty && File(imgs.first).existsSync();

    return Card(
      elevation: 0.5,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        onTap: () => _openDocDetail(doc),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: hasImg
              ? Image.file(File(imgs.first), width: 48, height: 60, fit: BoxFit.cover, cacheWidth: 150)
              : Container(width: 48, height: 60, color: Colors.grey.shade200, child: const Icon(Icons.description, color: Colors.grey)),
        ),
        title: Text(doc['title'] ?? 'Document', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('${doc['pages']} p • ${doc['category']} • ${doc['date']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      ),
    );
  }

  void _openDocDetail(Map<String, dynamic> doc) {
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
  }

  // ==========================================================================
  // TAB 2: PDF TOOLS / STUDIO
  // ==========================================================================
  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Fast AI Scanning'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard('ID Card', 'Front & Back', Icons.badge_outlined, Colors.blue, () => _startDocScan(limit: 2, category: 'ID Cards', prefix: 'ID_Card')),
            _buildToolCard('Book Scan', 'Ultra Clarity', Icons.menu_book_rounded, Colors.green, () => _startDocScan(prefix: 'Book_Page')),
            _buildToolCard('Import Photo', 'From Gallery', Icons.photo_library_outlined, Colors.pink, () => _startDocScan(galleryOnly: true)),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Office & Productivity Suite'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard('Resume Maker', 'Pro CV Maker', Icons.assignment_ind_rounded, const Color(0xFF0277BD), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeBuilderScreen()))),
            _buildToolCard('GST Invoice', 'Tax Slips', Icons.receipt_long_rounded, const Color(0xFF2E7D32), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceMakerProScreen()))),
            _buildToolCard('Slides Maker', 'PPT Slides', Icons.slideshow_rounded, const Color(0xFFD84315), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PowerPointStudioScreen()))),
            _buildToolCard('Letters', 'Formal Letters', Icons.mail_outline_rounded, const Color(0xFF6A1B9A), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LetterTemplatesScreen()))),
            _buildToolCard('Notes & TXT', 'Text Editor', Icons.edit_note_rounded, const Color(0xFF00796B), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen()))),
            _buildToolCard('Passport Photo', '4/8/16 Prints', Icons.portrait_rounded, Colors.deepPurple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportPhotoStudioScreen()))),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Image & PDF Studio'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard('Digital Sign', 'Transparent PNG', Icons.draw_rounded, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalSignatureScreen()))),
            _buildToolCard('PDF Merge', 'Combine Files', Icons.picture_as_pdf_rounded, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfStudioScreen(savedDocs: _savedDocs)))),
            _buildToolCard('Watermark', 'Stamp Text', Icons.branding_watermark_outlined, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => WatermarkToolScreen(savedDocs: _savedDocs)))),
            _buildToolCard('Photo Rotate', '90° Angle', Icons.crop_rotate_rounded, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalImageToolScreen()))),
          ],
        ),
        const SizedBox(height: 90),
      ],
    );
  }

  // TAB 3: IMPORT ID PHOTO DIRECT
  Widget _buildIdCardFastTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.badge_rounded, size: 70, color: Color(0xFF0288D1)),
            const SizedBox(height: 16),
            const Text('Import ID Photo / Card Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Scan Front & Back sides of your ID Card, Voter ID, Aadhaar or License to automatically stitch onto a single A4 Sheet!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0288D1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan ID Card Now (2 Pages)'),
              onPressed: () => _startDocScan(limit: 2, category: 'ID Cards', prefix: 'ID_Card'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: const Color(0xFF0288D1)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildToolCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            Text(subtitle, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(color: Colors.grey, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0F2B3B)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.document_scanner_rounded, size: 36, color: Colors.cyanAccent),
                SizedBox(height: 8),
                Text('Doc Scanner Pro', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Fast, Smooth & Ultra Clarity', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('Language / भाषा'),
            trailing: Switch(
              value: isHindiLanguage.value,
              onChanged: (val) async {
                isHindiLanguage.value = val;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('app_language_hindi', val);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder_shared_rounded),
            title: const Text('Gallery Storage Path'),
            subtitle: const Text('Pictures/BharatScanner'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. SCAN FILTER & RETOUCH SCREEN (CAN BE RE-OPENED ANYTIME TO RE-EDIT)
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
  double _manualDeskewAngle = 0.0;
  int _activeTopTab = 1; // 0 = Straighten AI, 1 = Filters, 2 = Tilt & Rotate

  late List<String> _workingPaths;
  late Map<int, String> _pageFilterSelections;
  late Map<int, double> _pageFilterIntensities;

  @override
  void initState() {
    super.initState();
    _workingPaths = List<String>.from(widget.rawImagePaths);
    _pageFilterSelections = {for (var i = 0; i < widget.rawImagePaths.length; i++) i: 'magic_book'};
    _pageFilterIntensities = {for (var i = 0; i < widget.rawImagePaths.length; i++) i: 0.6};
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Applied this filter & contrast to ALL pages!')));
  }

  Future<void> _runAutoStraightenAI() async {
    setState(() => _isProcessing = true);
    final curImg = _workingPaths[_curPageIndex];
    final detectedAngle = await AIDeskewEngine.detectSkewAngle(curImg);

    if (detectedAngle.abs() > 0.4) {
      final straightened = await AIDeskewEngine.rotateAndDeskewImage(curImg, -detectedAngle);
      setState(() {
        _workingPaths[_curPageIndex] = straightened;
        _manualDeskewAngle = 0.0;
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✨ AI Straightened by ${detectedAngle.toStringAsFixed(1)}°')));
    } else {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Page is already straight!')));
    }
  }

  Future<void> _rotateCurrentPage90() async {
    setState(() => _isProcessing = true);
    final curPath = _workingPaths[_curPageIndex];
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
        _workingPaths[_curPageIndex] = rotatedFile.path;
        _isProcessing = false;
      });
    } else {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _finishAndExport() async {
    setState(() => _isProcessing = true);
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!await scansDir.exists()) await scansDir.create(recursive: true);

    List<String> enhancedPaths = [];
    for (int i = 0; i < _workingPaths.length; i++) {
      String sourceImg = _workingPaths[i];

      if (i == _curPageIndex && _manualDeskewAngle.abs() > 0.5) {
        sourceImg = await AIDeskewEngine.rotateAndDeskewImage(sourceImg, _manualDeskewAngle);
      }

      final filterId = _pageFilterSelections[i] ?? 'magic_book';
      final intensity = _pageFilterIntensities[i] ?? 0.6;
      final preset = kDocFilters.firstWhere((f) => f.id == filterId, orElse: () => kDocFilters[1]);

      final matrix = preset.getMatrix(intensity);
      if (matrix == null) {
        enhancedPaths.add(sourceImg);
      } else {
        final bytes = await File(sourceImg).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final img = frame.image;

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
          enhancedPaths.add(sourceImg);
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
        title: Text('Edit Page ${_curPageIndex + 1} of ${_workingPaths.length}', style: const TextStyle(fontSize: 15)),
        actions: [
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTopPill('Straighten AI', Icons.auto_awesome, _activeTopTab == 0, () {
                        setState(() => _activeTopTab = 0);
                        _runAutoStraightenAI();
                      }),
                      const SizedBox(width: 8),
                      _buildTopPill('Filters', Icons.auto_fix_high_rounded, _activeTopTab == 1, () => setState(() => _activeTopTab = 1)),
                      const SizedBox(width: 8),
                      _buildTopPill('Tilt & Rotate', Icons.crop_rotate_rounded, _activeTopTab == 2, () => setState(() => _activeTopTab = 2)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: Transform.rotate(
                        angle: _manualDeskewAngle * pi / 180,
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
                ),
                if (_activeTopTab == 2) ...[
                  Container(
                    color: const Color(0xFF21242B),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.straighten, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Text('Tilt Angle: ${_manualDeskewAngle.toStringAsFixed(1)}°', style: const TextStyle(color: Colors.white, fontSize: 12)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    color: const Color(0xFF21242B),
                    child: Row(
                      children: [
                        const Text('Contrast:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
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
                ],
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
                                  child: Image.file(pageImg, fit: BoxFit.cover, cacheWidth: 150),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                left: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 1),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(4)),
                                  child: Text('P${idx + 1}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
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

  Widget _buildTopPill(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB0CCF9) : const Color(0xFF26282E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF003062) : Colors.white),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF003062) : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. DOCUMENT DETAIL SCREEN (SELECT SPECIFIC PAGES TO SHARE/DOWNLOAD + RE-EDIT)
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
  late List<String> _originalImages;
  late String _title;

  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.doc['images'] ?? []);
    _originalImages = List<String>.from(widget.doc['originalImages'] ?? widget.doc['images'] ?? []);
    _title = widget.doc['title'] ?? 'Document';
  }

  // Returns ONLY the pages user selected (or all if none selected)
  List<String> get _targetedImages {
    if (_isSelectionMode && _selectedIndices.isNotEmpty) {
      final sorted = _selectedIndices.toList()..sort();
      return sorted.map((i) => _images[i]).toList();
    }
    return _images;
  }

  void _reEditDocument() {
    final pathsToEdit = _targetedImages;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanFilterReviewScreen(
          rawImagePaths: pathsToEdit,
          onApplyAndProceed: (retouchedPaths) {
            setState(() {
              if (_isSelectionMode && _selectedIndices.isNotEmpty) {
                final sorted = _selectedIndices.toList()..sort();
                for (int i = 0; i < sorted.length; i++) {
                  _images[sorted[i]] = retouchedPaths[i];
                }
              } else {
                _images = List<String>.from(retouchedPaths);
              }
              widget.doc['images'] = _images;
            });
            widget.onDocUpdated(widget.doc);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Retouched Document Saved!')));
          },
        ),
      ),
    );
  }

  Future<void> _shareSelectedPdf() async {
    final imgs = _targetedImages;
    if (imgs.isEmpty) return;

    final pdf = pw.Document();
    for (var path in imgs) {
      final f = File(path);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) => pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain)),
          ),
        );
      }
    }

    final tempDir = await getTemporaryDirectory();
    final file = File("${tempDir.path}/${_title}_${imgs.length}p.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: '$_title (${imgs.length} Pages PDF)');
  }

  Future<void> _shareSelectedJpg() async {
    final imgs = _targetedImages;
    if (imgs.isEmpty) return;
    List<XFile> xFiles = imgs.map((p) => XFile(p)).toList();
    await Share.shareXFiles(xFiles, text: '$_title (${imgs.length} Pages JPG)');
  }

  Future<void> _saveSelectedToGallery() async {
    final imgs = _targetedImages;
    if (imgs.isEmpty) return;

    final int count = await PhoneStorageManager.saveImagesToPublicGallery(imgs, _title);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $count photo(s) saved directly to Phone Gallery (Pictures/BharatScanner)!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  Future<void> _addMorePages() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 20),
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
              icon: const Icon(Icons.select_all_rounded),
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
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedIndices.clear();
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.auto_fix_high_rounded),
              tooltip: 'Edit / Retouch',
              onPressed: _reEditDocument,
            ),
            TextButton.icon(
              icon: const Icon(Icons.checklist_rounded, color: Colors.white, size: 18),
              label: const Text('Select', style: TextStyle(color: Colors.white)),
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_images.length} Pages • Folder: ${widget.doc['category'] ?? 'General'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0288D1),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                  label: const Text('+ Add Pages'),
                  onPressed: _addMorePages,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _images.isEmpty
                ? const Center(child: Text('No pages found.'))
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
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenPhotoViewer(
                                  images: _images,
                                  initialIndex: idx,
                                  title: _title,
                                  onReEdit: _reEditDocument,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0288D1) : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: file.existsSync()
                                      ? Image.file(file, fit: BoxFit.cover, cacheWidth: 300)
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
                                    isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                    color: isSelected ? const Color(0xFF0288D1) : Colors.white,
                                    size: 24,
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
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomAction(Icons.picture_as_pdf_rounded, 'Share PDF', _shareSelectedPdf),
              _buildBottomAction(Icons.image_rounded, 'Share JPG', _shareSelectedJpg),
              _buildBottomAction(Icons.download_rounded, 'Save to Phone', _saveSelectedToGallery),
              _buildBottomAction(Icons.auto_fix_high_rounded, 'Re-Edit', _reEditDocument),
              if (_isSelectionMode)
                _buildBottomAction(Icons.delete_rounded, 'Delete', _deleteSelectedPages, isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    final col = isDestructive ? Colors.redAccent : const Color(0xFF0288D1);
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
// 5. FULL SCREEN PHOTO VIEWER
// ============================================================================
class FullScreenPhotoViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String title;
  final VoidCallback onReEdit;

  const FullScreenPhotoViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.title,
    required this.onReEdit,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.title} (${_curPage + 1}/${widget.images.length})', style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high_rounded, color: Colors.cyanAccent),
            tooltip: 'Edit / Retouch',
            onPressed: () {
              Navigator.pop(context);
              widget.onReEdit();
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              if (widget.images.isNotEmpty) {
                Share.shareXFiles([XFile(widget.images[_curPage])]);
              }
            },
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
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: file.existsSync()
                  ? Image.file(file, fit: BoxFit.contain)
                  : const Text('Image file not found', style: TextStyle(color: Colors.white)),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 6. PASSPORT PHOTO STUDIO
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
                width: 110,
                height: 145,
                padding: const pw.EdgeInsets.all(2),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 1)),
                child: pw.Image(passImg, fit: pw.BoxFit.cover),
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
            const SizedBox(height: 12),
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
                DropdownMenuItem(value: 'US Visa (2x2 inch)', child: Text('US Visa (2x2 inch)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _presetSize = v);
              },
            ),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Number of Prints on A4:', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 4, label: Text('4')),
                ButtonSegment(value: 8, label: Text('8')),
                ButtonSegment(value: 16, label: Text('16')),
              ],
              selected: {_copies},
              onSelectionChanged: (s) => setState(() => _copies = s.first),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
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
// 7. DIGITAL SIGNATURE
// ============================================================================
class DigitalSignatureScreen extends StatefulWidget {
  const DigitalSignatureScreen({super.key});
  @override
  State<DigitalSignatureScreen> createState() => _DigitalSignatureScreenState();
}

class _DigitalSignatureScreenState extends State<DigitalSignatureScreen> {
  final List<List<Offset>> _strokes = [];
  Color _inkColor = Colors.black;

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
      ..strokeWidth = 3.5
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
            onPressed: () {
              if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => setState(() => _strokes.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Text('Ink Color: ', style: TextStyle(fontWeight: FontWeight.bold)),
                ...[Colors.black, const Color(0xFF0D47A1), const Color(0xFFB71C1C)].map((c) => GestureDetector(
                  onTap: () => setState(() => _inkColor = c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _inkColor == c ? Colors.amber : Colors.transparent, width: 2)),
                  ),
                )),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
              onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
              child: CustomPaint(
                painter: _SignPainter(_strokes, _inkColor),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
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
  _SignPainter(this.strokes, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
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
// 8. GST TAX INVOICE MAKER
// ============================================================================
class InvoiceMakerProScreen extends StatefulWidget {
  const InvoiceMakerProScreen({super.key});
  @override
  State<InvoiceMakerProScreen> createState() => _InvoiceMakerProScreenState();
}

class _InvoiceMakerProScreenState extends State<InvoiceMakerProScreen> {
  final _sellerCtrl = TextEditingController(text: 'My Business / Shop Name');
  final _clientCtrl = TextEditingController(text: 'Customer Name');
  final _itemCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');

  final List<Map<String, dynamic>> _items = [
    {'name': 'Professional Consulting', 'price': 1500.0, 'qty': 1},
  ];

  Future<void> _exportInvoicePdf() async {
    final pdf = pw.Document();
    double subtotal = _items.fold(0.0, (s, i) => s + ((i['price'] as double) * (i['qty'] as int)));
    double gst = subtotal * 0.18;
    double total = subtotal + gst;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.SizedBox(height: 6),
              pw.Text('Seller: ${_sellerCtrl.text}'),
              pw.Text('Billed To: ${_clientCtrl.text}'),
              pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
              pw.Divider(),
              pw.TableHelper.fromTextArray(
                headers: ['Item / Service', 'Qty', 'Rate', 'Total'],
                data: _items.map((it) => [it['name'], '${it['qty']}', '${it['price']}', '${it['qty'] * it['price']}']).toList(),
              ),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: INR ${subtotal.toStringAsFixed(2)}'),
                    pw.Text('GST (18%): INR ${gst.toStringAsFixed(2)}'),
                    pw.Text('Grand Total: INR ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
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
            const Divider(),
            ..._items.map((it) => ListTile(
              title: Text(it['name']),
              subtitle: Text('Qty: ${it['qty']} × INR ${it['price']}'),
              trailing: Text('INR ${(it['qty'] * it['price']).toStringAsFixed(2)}'),
            )),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
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
// 9. RESUME / CV BUILDER
// ============================================================================
class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});
  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final _name = TextEditingController(text: 'Rahul Sharma');
  final _contact = TextEditingController(text: '+91 98765 43210 | rahul.sharma@email.com');
  final _summary = TextEditingController(text: 'Motivated professional with expertise in operations and documentation.');
  final _experience = TextEditingController(text: '• 3+ Years experience in Team Coordination & IT Documentation.');
  final _education = TextEditingController(text: '• Graduate / Bachelor Degree (2021)');
  final _skills = TextEditingController(text: 'Documentation, MS Office, Problem Solving');

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
              pw.Text(_name.text, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.Text(_contact.text, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(_summary.text, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Text('EXPERIENCE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
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
    final file = File("${dir.path}/Resume.pdf");
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
            TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact Info', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _summary, maxLines: 2, decoration: const InputDecoration(labelText: 'Summary', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _experience, maxLines: 3, decoration: const InputDecoration(labelText: 'Experience', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _education, maxLines: 2, decoration: const InputDecoration(labelText: 'Education', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _skills, decoration: const InputDecoration(labelText: 'Skills', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
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
// 10. POWERPOINT / SLIDES MAKER
// ============================================================================
class PowerPointStudioScreen extends StatefulWidget {
  const PowerPointStudioScreen({super.key});
  @override
  State<PowerPointStudioScreen> createState() => _PowerPointStudioScreenState();
}

class _PowerPointStudioScreenState extends State<PowerPointStudioScreen> {
  final List<Map<String, String>> _slides = [
    {'title': 'Project Overview', 'content': '• Milestone 1\n• Milestone 2\n• Next Steps'},
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
                pw.Text(s['title'] ?? '', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Divider(),
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
        backgroundColor: const Color(0xFF0288D1),
        foregroundColor: Colors.white,
        onPressed: () => setState(() => _slides.add({'title': 'New Slide', 'content': '• Point 1\n• Point 2'})),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================================
// 11. FORMAL LETTER TEMPLATES
// ============================================================================
class LetterTemplatesScreen extends StatefulWidget {
  const LetterTemplatesScreen({super.key});
  @override
  State<LetterTemplatesScreen> createState() => _LetterTemplatesScreenState();
}

class _LetterTemplatesScreenState extends State<LetterTemplatesScreen> {
  final _ctrl = TextEditingController(
    text: "To,\nThe Branch Manager,\nSubject: Application for New Cheque Book\n\nRespected Sir/Madam,\nI hold a savings account in your branch (Account No: XXXXXXXX). I kindly request you to issue a new cheque book.\n\nThanking You,\nYours Sincerely,\n[Your Name]",
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
                  onPressed: () => setState(() => _ctrl.text = "To,\nThe HR Manager,\nSubject: Leave Application\n\nRespected Sir/Madam,\nI request 3 days leave from [Date] due to urgent personal reasons.\n\nThank you,\n[Your Name]"),
                ),
                ActionChip(
                  label: const Text('Resignation'),
                  onPressed: () => setState(() => _ctrl.text = "To,\nThe Management,\nSubject: Notice of Resignation\n\nPlease accept this letter as formal notification of my resignation.\n\nRegards,\n[Your Name]"),
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
// 12. TXT & NOTES STUDIO
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
// 13. PDF MERGE STUDIO
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
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.picture_as_pdf),
          label: Text('Merge Selected (${_selectedIds.length}) into One PDF'),
          onPressed: _mergeDocs,
        ),
      ),
    );
  }
}

// ============================================================================
// 14. WATERMARK STUDIO
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
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
// 15. UNIVERSAL PHOTO ROTATE
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
