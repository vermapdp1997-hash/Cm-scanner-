// ==================== PART 1 START ====================
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
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// GLOBAL CONTROLLERS & LOCALIZATION
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);
final ValueNotifier<Color> appPrimaryColor = ValueNotifier(const Color(0xFF2E7D32));
final ValueNotifier<bool> isHindiLanguage = ValueNotifier(false);

class AppLang {
  static String tr(String key) {
    final bool hi = isHindiLanguage.value;
    const Map<String, List<String>> dict = {
      'app_title': ['Bharat Document Scanner AI', 'भारत डॉक्यूमेंट स्कैनर AI'],
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
      'save': ['Save', 'सेव करें'],
      'save_pdf': ['Save PDF', 'PDF सेव करें'],
      'save_jpg': ['Save JPG', 'JPG सेव करें'],
      'share_pdf': ['Share PDF', 'PDF शेयर करें'],
      'share_jpg': ['Share JPG', 'JPG शेयर करें'],
      'delete': ['Delete', 'हटाएं'],
      'no_docs': ['No documents saved yet. Tap Camera to Scan!', 'अभी तक कोई दस्तावेज़ नहीं है। स्कैन करने के लिए कैमरा दबाएं!'],
      'scan': ['Scan', 'स्कैन'],
      'camera': ['Camera', 'कैमरा'],
      'add_gal': ['Add / Gal', 'जोड़ें / गैलरी'],
      'select_all': ['Select All', 'सभी चुनें'],
      'add_more': ['+ Add Pages', '+ और पेज जोड़ें'],
      'add_new_doc': ['Add New Document', 'नया दस्तावेज़ जोड़ें'],
      'choose_options': ['Choose from below options', 'नीचे दिए गए विकल्प चुनें'],
      'from_gallery': ['Import from Gallery (Phone Photos)', 'गैलरी से फोटो चुनें'],
      'from_camera': ['Scan from Camera', 'कैमरे से स्कैन करें'],
      'compress': ['Compress', 'कंप्रेस'],
      'edit_doc': ['Edit Page', 'एडिट करें'],
      'move_folder': ['Move Folder', 'फ़ोल्डर बदलें'],
      'move_copy': ['Move/Copy', 'ट्रांसफर'],
      'combine_doc': ['Combine Doc', 'एक में जोड़ें'],
      'light_mode': ['Light Mode', 'लाइट मोड'],
      'dark_mode': ['Dark Mode', 'डार्क मोड'],
      'change_theme': ['Change Theme Color', 'थीम का रंग बदलें'],
      'language': ['Language / भाषा (हिंदी)', 'भाषा / Language (हिंदी)'],
    };
    return dict[key] != null ? (hi ? dict[key]![1] : dict[key]![0]) : key;
  }
}

class LabeledIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const LabeledIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.iconSize = 21,
    this.fontSize = 9.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onPressed == null ? Colors.grey : (color ?? IconTheme.of(context).color ?? Colors.black87);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: effectiveColor),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: effectiveColor, height: 1.05)),
          ],
        ),
      ),
    );
  }
}

class DocFilterPreset {
  final String id;
  final String title;
  final IconData icon;
  final Color badgeColor;
  const DocFilterPreset({required this.id, required this.title, required this.icon, required this.badgeColor});
}

// PRO DOC SCANNER PRESET FILTERS
final List<DocFilterPreset> kDocFilters = [
  const DocFilterPreset(id: 'original', title: 'Original', icon: Icons.image_outlined, badgeColor: Colors.blueGrey),
  const DocFilterPreset(id: 'magic_pro', title: 'Magic Color', icon: Icons.auto_awesome_rounded, badgeColor: Color(0xFF00B4D8)),
  const DocFilterPreset(id: 'auto_pro', title: 'Auto AI', icon: Icons.auto_fix_high_rounded, badgeColor: Color(0xFF2E7D32)),
  const DocFilterPreset(id: 'lighten_pro', title: 'Lighten Pro', icon: Icons.wb_sunny_outlined, badgeColor: Colors.orange),
  const DocFilterPreset(id: 'super_bw', title: 'B&W Pro', icon: Icons.contrast_rounded, badgeColor: Colors.black87),
  const DocFilterPreset(id: 'dark_ink', title: 'Dark Ink', icon: Icons.draw_rounded, badgeColor: Color(0xFF4CAF50)),
  const DocFilterPreset(id: 'ocv_crisp', title: 'Grayscale Pro', icon: Icons.filter_b_and_w_rounded, badgeColor: Colors.grey),
  const DocFilterPreset(id: 'vivid_color', title: 'Vivid Color', icon: Icons.color_lens_outlined, badgeColor: Colors.pink),
];

// ============================================================================
// ULTRA-CLARITY PRO IMAGE PROCESSOR (WHITE BALANCE + DENOISE + SAUVOLA + LUT)
// ============================================================================
class ProDocImageProcessor {
  static List<int>? _readDimensionsFast(Uint8List rawBytes) {
    try {
      final decoder = img.findDecoderForData(rawBytes);
      final info = decoder?.startDecode(rawBytes);
      if (info != null && info.width > 0 && info.height > 0) return [info.width, info.height];
    } catch (_) {}
    return null;
  }

  static Future<Uint8List?> decodeImageToRgba(String path, {int? maxDimension, required List<int> outWidthHeight}) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final rawBytes = await file.readAsBytes();
    ui.Codec? codec;
    ui.Image? targetImg;
    try {
      int? targetWidth;
      int? targetHeight;
      if (maxDimension != null) {
        final dims = _readDimensionsFast(rawBytes);
        if (dims != null) {
          if (dims[0] > maxDimension || dims[1] > maxDimension) {
            if (dims[0] >= dims[1]) {
              targetWidth = maxDimension;
            } else {
              targetHeight = maxDimension;
            }
          }
        } else {
          targetWidth = maxDimension;
        }
      }
      codec = await ui.instantiateImageCodec(rawBytes, targetWidth: targetWidth, targetHeight: targetHeight);
      final frame = await codec.getNextFrame();
      targetImg = frame.image;
      outWidthHeight[0] = targetImg.width;
      outWidthHeight[1] = targetImg.height;
      final byteData = await targetImg.toByteData(format: ui.ImageByteFormat.rawRgba);
      return byteData?.buffer.asUint8List();
    } finally {
      targetImg?.dispose();
      codec?.dispose();
    }
  }

  static Future<Uint8List> applyProFilterToRgba({
    required Uint8List rgba,
    required int width,
    required int height,
    required String filterId,
    required double intensity,
    double brightness = 0.0,
    double contrast = 1.0,
    double sharpness = 0.5,
    List<Map<String, dynamic>>? eraserStrokes,
  }) async {
    final bool hasAdjustments = brightness.abs() > 0.01 || (contrast - 1.0).abs() > 0.01 || (eraserStrokes != null && eraserStrokes.isNotEmpty);
    if (filterId == 'original' && !hasAdjustments) return rgba;
    return compute(_processRgbaIsolate, {
      'rgba': rgba,
      'w': width,
      'h': height,
      'filter': filterId,
      'intensity': intensity,
      'brightness': brightness,
      'contrast': contrast,
      'sharpness': sharpness,
      'eraserStrokes': eraserStrokes ?? const <Map<String, dynamic>>[],
    });
  }

  static Future<ui.Image?> rgbaToUiImage(Uint8List rgba, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  static Future<String> processAndSaveHighRes({
    required String sourcePath,
    required String filterId,
    required double intensity,
    required String outputPath,
    double brightness = 0.0,
    double contrast = 1.0,
    double sharpness = 0.5,
    List<Map<String, dynamic>>? eraserStrokes,
  }) async {
    final bool hasAdjustments = brightness.abs() > 0.01 || (contrast - 1.0).abs() > 0.01 || (eraserStrokes != null && eraserStrokes.isNotEmpty);
    if (filterId == 'original' && !hasAdjustments) {
      await File(sourcePath).copy(outputPath);
      return outputPath;
    }
    final wh = [0, 0];
    final rgba = await decodeImageToRgba(sourcePath, maxDimension: 2400, outWidthHeight: wh);
    if (rgba == null) return sourcePath;
    final enhanced = await applyProFilterToRgba(
      rgba: rgba,
      width: wh[0],
      height: wh[1],
      filterId: filterId,
      intensity: intensity,
      brightness: brightness,
      contrast: contrast,
      sharpness: sharpness,
      eraserStrokes: eraserStrokes,
    );
    final jpgBytes = await compute(_encodeRgbaToJpgIsolate, {'rgba': enhanced, 'w': wh[0], 'h': wh[1], 'quality': 93});
    await File(outputPath).writeAsBytes(jpgBytes);
    return outputPath;
  }

  static Future<String> rotateImage90Fast(String sourcePath, String outputPath) async {
    try {
      final rawBytes = await File(sourcePath).readAsBytes();
      final rotatedJpg = await compute(_rotate90Isolate, rawBytes);
      if (rotatedJpg != null) {
        await File(outputPath).writeAsBytes(rotatedJpg);
        return outputPath;
      }
    } catch (e) {
      debugPrint("Fast rotate err: $e");
    }
    return sourcePath;
  }
}

Uint8List? _rotate90Isolate(Uint8List rawBytes) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final rotated = img.copyRotate(oriented, angle: 90);
  return Uint8List.fromList(img.encodeJpg(rotated, quality: 93));
}

Uint8List _encodeRgbaToJpgIsolate(Map<String, dynamic> params) {
  final Uint8List rgba = params['rgba'];
  final im = img.Image.fromBytes(width: params['w'], height: params['h'], bytes: Uint8List.fromList(rgba).buffer, numChannels: 4, order: img.ChannelOrder.rgba);
  return Uint8List.fromList(img.encodeJpg(im, quality: params['quality']));
}

Uint8List _processRgbaIsolate(Map<String, dynamic> params) {
  final Uint8List rawSrc = params['rgba'];
  final int w = params['w'];
  final int h = params['h'];
  final String filter = params['filter'];
  final double intensity = (params['intensity'] as double).clamp(0.0, 1.0);
  final double brightness = (params['brightness'] as double).clamp(-0.5, 0.5);
  final double contrast = (params['contrast'] as double).clamp(0.5, 2.0);
  final double userSharpness = (params['sharpness'] as double).clamp(0.0, 1.5);
  final List eraserStrokes = params['eraserStrokes'] as List? ?? const [];

  final int total = w * h;
  final Uint8List out = Uint8List.fromList(rawSrc);
  if (total == 0) return out;

  // STEP 1: Fast Edge-Preserving Noise Removal
  Uint8List src = rawSrc;
  if (filter != 'original' && filter != 'vivid_color' && w > 4 && h > 4) {
    final Uint8List denoised = Uint8List.fromList(rawSrc);
    final int noiseThresh = (filter == 'super_bw' || filter == 'dark_ink') ? 22 : 16;
    for (int y = 1; y < h - 1; y++) {
      final int rb = y * w;
      for (int x = 1; x < w - 1; x++) {
        final int p = (rb + x) * 4;
        final int cR = rawSrc[p], cG = rawSrc[p + 1], cB = rawSrc[p + 2];
        final int cL = (77 * cR + 150 * cG + 29 * cB) >> 8;

        int sumR = cR, sumG = cG, sumB = cB, cnt = 1;
        final int n1 = (rb + x - 1) * 4;
        if ((((77 * rawSrc[n1] + 150 * rawSrc[n1 + 1] + 29 * rawSrc[n1 + 2]) >> 8) - cL).abs() <= noiseThresh) {
          sumR += rawSrc[n1];
          sumG += rawSrc[n1 + 1];
          sumB += rawSrc[n1 + 2];
          cnt++;
        }
        final int n2 = (rb + x + 1) * 4;
        if ((((77 * rawSrc[n2] + 150 * rawSrc[n2 + 1] + 29 * rawSrc[n2 + 2]) >> 8) - cL).abs() <= noiseThresh) {
          sumR += rawSrc[n2];
          sumG += rawSrc[n2 + 1];
          sumB += rawSrc[n2 + 2];
          cnt++;
        }
        final int n3 = ((y - 1) * w + x) * 4;
        if ((((77 * rawSrc[n3] + 150 * rawSrc[n3 + 1] + 29 * rawSrc[n3 + 2]) >> 8) - cL).abs() <= noiseThresh) {
          sumR += rawSrc[n3];
          sumG += rawSrc[n3 + 1];
          sumB += rawSrc[n3 + 2];
          cnt++;
        }
        final int n4 = ((y + 1) * w + x) * 4;
        if ((((77 * rawSrc[n4] + 150 * rawSrc[n4 + 1] + 29 * rawSrc[n4 + 2]) >> 8) - cL).abs() <= noiseThresh) {
          sumR += rawSrc[n4];
          sumG += rawSrc[n4 + 1];
          sumB += rawSrc[n4 + 2];
          cnt++;
        }
        if (cnt > 1) {
          denoised[p] = sumR ~/ cnt;
          denoised[p + 1] = sumG ~/ cnt;
          denoised[p + 2] = sumB ~/ cnt;
        }
      }
    }
    src = denoised;
  }

  // STEP 2: 3-Channel (R, G, B) Illumination & White-Balance Grid Estimation
  const int gridCols = 24;
  const int gridRows = 24;
  const int gridCount = gridCols * gridRows;
  final Float32List bgRGrid = Float32List(gridCount);
  final Float32List bgGGrid = Float32List(gridCount);
  final Float32List bgBGrid = Float32List(gridCount);

  if (filter != 'original' && filter != 'vivid_color') {
    final Int32List gHistR = Int32List(256), gHistG = Int32List(256), gHistB = Int32List(256);
    int gSamples = 0;
    final int gStep = max(1, total ~/ 25000);
    for (int i = 0; i < total; i += gStep) {
      final int p = i * 4;
      gHistR[src[p]]++;
      gHistG[src[p + 1]]++;
      gHistB[src[p + 2]]++;
      gSamples++;
    }
    double percentile85(Int32List hist) {
      int acc = 0;
      final int target = max(1, (gSamples * 0.15).round());
      for (int b = 255; b >= 0; b--) {
        acc += hist[b];
        if (acc >= target) return b.toDouble();
      }
      return 210.0;
    }

    final double minFloorR = max(75.0, percentile85(gHistR) * 0.55);
    final double minFloorG = max(75.0, percentile85(gHistG) * 0.55);
    final double minFloorB = max(75.0, percentile85(gHistB) * 0.55);

    final Int32List blkHist = Int32List(256);
    final Int32List blkSumR = Int32List(256), blkSumG = Int32List(256), blkSumB = Int32List(256);
    final int step = (w > 1000 || h > 1000) ? 2 : 1;

    for (int gy = 0; gy < gridRows; gy++) {
      final int y0 = (gy * h) ~/ gridRows, y1 = ((gy + 1) * h) ~/ gridRows;
      for (int gx = 0; gx < gridCols; gx++) {
        final int x0 = (gx * w) ~/ gridCols, x1 = ((gx + 1) * w) ~/ gridCols;
        blkHist.fillRange(0, 256, 0);
        blkSumR.fillRange(0, 256, 0);
        blkSumG.fillRange(0, 256, 0);
        blkSumB.fillRange(0, 256, 0);
        int samples = 0;
        for (int y = y0; y < y1; y += step) {
          final int rb = y * w;
          for (int x = x0; x < x1; x += step) {
            final int p = (rb + x) * 4;
            final int r = src[p], g = src[p + 1], b = src[p + 2];
            final int l = ((77 * r + 150 * g + 29 * b) >> 8).clamp(0, 255);
            blkHist[l]++;
            blkSumR[l] += r;
            blkSumG[l] += g;
            blkSumB[l] += b;
            samples++;
          }
        }
        final int gIdx = gy * gridCols + gx;
        if (samples == 0) {
          bgRGrid[gIdx] = 255.0;
          bgGGrid[gIdx] = 255.0;
          bgBGrid[gIdx] = 255.0;
          continue;
        }
        final int target = max(1, (samples * 0.12).round());
        int acc = 0, sR = 0, sG = 0, sB = 0;
        for (int bin = 255; bin >= 0; bin--) {
          final int c = blkHist[bin];
          if (c > 0) {
            acc += c;
            sR += blkSumR[bin];
            sG += blkSumG[bin];
            sB += blkSumB[bin];
            if (acc >= target) break;
          }
        }
        bgRGrid[gIdx] = max(sR / acc, minFloorR).clamp(48.0, 255.0);
        bgGGrid[gIdx] = max(sG / acc, minFloorG).clamp(48.0, 255.0);
        bgBGrid[gIdx] = max(sB / acc, minFloorB).clamp(48.0, 255.0);
      }
    }

    final Float32List tmpR = Float32List(gridCount), tmpG = Float32List(gridCount), tmpB = Float32List(gridCount);
    for (int gy = 0; gy < gridRows; gy++) {
      for (int gx = 0; gx < gridCols; gx++) {
        final int idx = gy * gridCols + gx;
        double mR = bgRGrid[idx], mG = bgGGrid[idx], mB = bgBGrid[idx];
        for (int dy = -1; dy <= 1; dy++) {
          final int ny = (gy + dy).clamp(0, gridRows - 1);
          for (int dx = -1; dx <= 1; dx++) {
            final int nx = (gx + dx).clamp(0, gridCols - 1);
            final int nIdx = ny * gridCols + nx;
            if (bgRGrid[nIdx] > mR) mR = bgRGrid[nIdx];
            if (bgGGrid[nIdx] > mG) mG = bgGGrid[nIdx];
            if (bgBGrid[nIdx] > mB) mB = bgBGrid[nIdx];
          }
        }
        tmpR[idx] = bgRGrid[idx] * 0.55 + mR * 0.45;
        tmpG[idx] = bgGGrid[idx] * 0.55 + mG * 0.45;
        tmpB[idx] = bgBGrid[idx] * 0.55 + mB * 0.45;
      }
    }
    bgRGrid.setAll(0, tmpR);
    bgGGrid.setAll(0, tmpG);
    bgBGrid.setAll(0, tmpB);

    for (int pass = 0; pass < 2; pass++) {
      for (int gy = 0; gy < gridRows; gy++) {
        for (int gx = 0; gx < gridCols; gx++) {
          double sR = 0, sG = 0, sB = 0;
          int cnt = 0;
          for (int dy = -1; dy <= 1; dy++) {
            final int ny = (gy + dy).clamp(0, gridRows - 1);
            for (int dx = -1; dx <= 1; dx++) {
              final int nx = (gx + dx).clamp(0, gridCols - 1);
              final int nIdx = ny * gridCols + nx;
              sR += bgRGrid[nIdx];
              sG += bgGGrid[nIdx];
              sB += bgBGrid[nIdx];
              cnt++;
            }
          }
          final int idx = gy * gridCols + gx;
          tmpR[idx] = sR / cnt;
          tmpG[idx] = sG / cnt;
          tmpB[idx] = sB / cnt;
        }
      }
      bgRGrid.setAll(0, tmpR);
      bgGGrid.setAll(0, tmpG);
      bgBGrid.setAll(0, tmpB);
    }
  }

  double sampleGrid(Float32List grid, double gx, double gy) {
    final int x0 = gx.floor().clamp(0, gridCols - 1);
    final int y0 = gy.floor().clamp(0, gridRows - 1);
    final int x1 = (x0 + 1).clamp(0, gridCols - 1);
    final int y1 = (y0 + 1).clamp(0, gridRows - 1);
    final double fx = gx - x0, fy = gy - y0;
    final double top = grid[y0 * gridCols + x0] + (grid[y0 * gridCols + x1] - grid[y0 * gridCols + x0]) * fx;
    final double bot = grid[y1 * gridCols + x0] + (grid[y1 * gridCols + x1] - grid[y1 * gridCols + x0]) * fx;
    return top + (bot - top) * fy;
  }

  final double cellW = w / gridCols, cellH = h / gridRows;
  final bool hasManualTone = brightness.abs() > 0.005 || (contrast - 1.0).abs() > 0.005;

  // STEP 3A: TRUE SAUVOLA ADAPTIVE THRESHOLDING (B&W Pro)
  if (filter == 'super_bw') {
    final Uint8List normLum = Uint8List(total);
    final int iw = w + 1;
    final Int64List intSum = Int64List(iw * (h + 1));
    final Int64List intSq = Int64List(iw * (h + 1));

    for (int y = 0; y < h; y++) {
      final double gy = ((y + 0.5) / cellH - 0.5).clamp(0.0, gridRows - 1.0001);
      int rowSum = 0, rowSq = 0;
      final int rb = y * w, irb = (y + 1) * iw, iprb = y * iw;
      for (int x = 0; x < w; x++) {
        final double gx = ((x + 0.5) / cellW - 0.5).clamp(0.0, gridCols - 1.0001);
        final int p = (rb + x) * 4;
        final double gR = min(252.0 / max(sampleGrid(bgRGrid, gx, gy), 45.0), 2.8);
        final double gG = min(252.0 / max(sampleGrid(bgGGrid, gx, gy), 45.0), 2.8);
        final double gB = min(252.0 / max(sampleGrid(bgBGrid, gx, gy), 45.0), 2.8);
        final int nL = (0.299 * src[p] * gR + 0.587 * src[p + 1] * gG + 0.114 * src[p + 2] * gB).round().clamp(0, 255);
        normLum[rb + x] = nL;
        rowSum += nL;
        rowSq += nL * nL;
        intSum[irb + x + 1] = intSum[iprb + x + 1] + rowSum;
        intSq[irb + x + 1] = intSq[iprb + x + 1] + rowSq;
      }
    }

    final int rad = max(14, min(w, h) ~/ 28);
    final double kSauvola = 0.14 + 0.24 * (1.0 - intensity);
    const double band = 14.0;

    for (int y = 0; y < h; y++) {
      final int y1 = max(0, y - rad), y2 = min(h - 1, y + rad), rowOff = y * w;
      for (int x = 0; x < w; x++) {
        final int x1 = max(0, x - rad), x2 = min(w - 1, x + rad);
        final int count = (x2 - x1 + 1) * (y2 - y1 + 1);
        final int sum = intSum[(y2 + 1) * iw + (x2 + 1)] - intSum[y1 * iw + (x2 + 1)] - intSum[(y2 + 1) * iw + x1] + intSum[y1 * iw + x1];
        final int sqSum = intSq[(y2 + 1) * iw + (x2 + 1)] - intSq[y1 * iw + (x2 + 1)] - intSq[(y2 + 1) * iw + x1] + intSq[y1 * iw + x1];

        final double mean = sum / count;
        final double variance = max(0.0, (sqSum / count) - mean * mean);
        final double stdDev = sqrt(variance);
        final int cur = normLum[rowOff + x];

        int bw;
        if (cur > 230 && stdDev < 18.0) {
          bw = 255;
        } else if (mean < 28.0 && stdDev < 12.0) {
          bw = 10;
        } else {
          final double thresh = mean * (1.0 + kSauvola * (stdDev / 128.0 - 1.0));
          final double t = ((cur - (thresh - band)) / (2.0 * band)).clamp(0.0, 1.0);
          bw = (8 + (t * t * (3.0 - 2.0 * t)) * 247).round().clamp(0, 255);
        }
        if (hasManualTone) {
          bw = ((bw - 128.0) * contrast + 128.0 + brightness * 255.0).round().clamp(0, 255);
        }
        final int p = (rowOff + x) * 4;
        out[p] = bw;
        out[p + 1] = bw;
        out[p + 2] = bw;
        out[p + 3] = 255;
      }
    }
    _paintEraserStrokes(out, w, h, eraserStrokes);
    return out;
  }

  // STEP 3B: PRO TONE CURVE LUT
  final Float32List toneLut = Float32List(256);
  if (filter == 'magic_pro' || filter == 'auto_pro' || filter == 'dark_ink' || filter == 'ocv_crisp') {
    final double paperSnap = filter == 'dark_ink'
        ? (202.0 - 30.0 * intensity)
        : filter == 'magic_pro'
            ? (208.0 - 30.0 * intensity)
            : filter == 'ocv_crisp'
                ? (205.0 - 28.0 * intensity)
                : (220.0 - 22.0 * intensity);
    final double inkGamma = filter == 'dark_ink'
        ? (1.42 + 0.52 * intensity)
        : filter == 'magic_pro'
            ? (1.22 + 0.36 * intensity)
            : filter == 'ocv_crisp'
                ? (1.28 + 0.35 * intensity)
                : (1.12 + 0.22 * intensity);
    final double blackFloor = (filter == 'dark_ink') ? 22.0 : 12.0;

    for (int v = 0; v < 256; v++) {
      final double dv = v.toDouble();
      if (dv <= blackFloor) {
        toneLut[v] = dv * 0.55;
      } else {
        final double normalized = ((dv - blackFloor) / max(1.0, paperSnap - blackFloor)).clamp(0.0, 1.0);
        final double inkVal = pow(normalized, inkGamma) * paperSnap;
        final double kneeStart = paperSnap - 34.0;
        final double kneeEnd = min(253.0, paperSnap + 16.0);
        final double t = ((dv - kneeStart) / max(1.0, kneeEnd - kneeStart)).clamp(0.0, 1.0);
        final double smoothWhite = t * t * (3.0 - 2.0 * t);
        toneLut[v] = (inkVal + (255.0 - inkVal) * smoothWhite).clamp(0.0, 255.0);
      }
    }
  } else if (filter == 'lighten_pro') {
    final double liftGamma = 0.86 - 0.20 * intensity;
    for (int v = 0; v < 256; v++) {
      toneLut[v] = (pow(v / 255.0, liftGamma) * 255.0).clamp(0.0, 255.0);
    }
  } else {
    for (int v = 0; v < 256; v++) {
      toneLut[v] = v.toDouble();
    }
  }

  int lowClip = 6, highClip = 249;
  if (filter == 'vivid_color') {
    final Int32List lumHist = Int32List(256);
    int sampleCount = 0;
    for (int i = 0; i < total; i += 4) {
      final int p = i * 4;
      lumHist[((77 * src[p] + 150 * src[p + 1] + 29 * src[p + 2]) >> 8).clamp(0, 255)]++;
      sampleCount++;
    }
    int acc = 0;
    for (int b = 0; b < 256; b++) {
      acc += lumHist[b];
      if (acc >= sampleCount * 0.015) {
        lowClip = b;
        break;
      }
    }
    acc = 0;
    for (int b = 255; b >= 0; b--) {
      acc += lumHist[b];
      if (acc >= sampleCount * 0.015) {
        highClip = b;
        break;
      }
    }
    if (highClip - lowClip < 40) {
      lowClip = 5;
      highClip = 250;
    }
  }

  // STEP 4: WHITE BALANCE + TONE MAPPING + BRIGHTNESS/CONTRAST
  final Uint8List lumCache = Uint8List(total);
  final double maxGain = (filter == 'dark_ink' || filter == 'magic_pro') ? 2.80 : 2.45;
  final double satBoost = filter == 'magic_pro'
      ? (1.22 + 0.22 * intensity)
      : filter == 'auto_pro'
          ? (1.12 + 0.12 * intensity)
          : filter == 'vivid_color'
              ? (1.28 + 0.35 * intensity)
              : 1.06;

  for (int y = 0; y < h; y++) {
    final double gy = ((y + 0.5) / cellH - 0.5).clamp(0.0, gridRows - 1.0001);
    final int rowOff = y * w;
    for (int x = 0; x < w; x++) {
      final double gx = ((x + 0.5) / cellW - 0.5).clamp(0.0, gridCols - 1.0001);
      final int p = (rowOff + x) * 4;
      double nr = src[p].toDouble(), ng = src[p + 1].toDouble(), nb = src[p + 2].toDouble();

      if (filter == 'vivid_color') {
        final double scale = 255.0 / (highClip - lowClip);
        nr = ((nr - lowClip) * scale).clamp(0.0, 255.0);
        ng = ((ng - lowClip) * scale).clamp(0.0, 255.0);
        nb = ((nb - lowClip) * scale).clamp(0.0, 255.0);
        final double lum = 0.299 * nr + 0.587 * ng + 0.114 * nb;
        nr = (lum + (nr - lum) * satBoost).clamp(0.0, 255.0);
        ng = (lum + (ng - lum) * satBoost).clamp(0.0, 255.0);
        nb = (lum + (nb - lum) * satBoost).clamp(0.0, 255.0);
      } else if (filter != 'original') {
        final double gR = min(253.0 / max(sampleGrid(bgRGrid, gx, gy), 45.0), maxGain);
        final double gG = min(253.0 / max(sampleGrid(bgGGrid, gx, gy), 45.0), maxGain);
        final double gB = min(253.0 / max(sampleGrid(bgBGrid, gx, gy), 45.0), maxGain);

        final double wbR = (nr * gR).clamp(0.0, 255.0);
        final double wbG = (ng * gG).clamp(0.0, 255.0);
        final double wbB = (nb * gB).clamp(0.0, 255.0);
        final double wbLum = (0.299 * wbR + 0.587 * wbG + 0.114 * wbB).clamp(0.0, 255.0);

        if (filter == 'ocv_crisp') {
          final double targetL = toneLut[wbLum.round().clamp(0, 255)];
          nr = targetL;
          ng = targetL;
          nb = targetL;
        } else if (filter == 'lighten_pro') {
          final double blend = 0.60 + 0.35 * intensity;
          final double lR = nr + (wbR - nr) * blend;
          final double lG = ng + (wbG - ng) * blend;
          final double lB = nb + (wbB - nb) * blend;
          nr = toneLut[lR.round().clamp(0, 255)];
          ng = toneLut[lG.round().clamp(0, 255)];
          nb = toneLut[lB.round().clamp(0, 255)];
        } else {
          final double targetL = toneLut[wbLum.round().clamp(0, 255)];
          final double ratio = wbLum > 1.5 ? (targetL / wbLum) : 1.0;
          final double sr = (wbR * ratio).clamp(0.0, 255.0);
          final double sg = (wbG * ratio).clamp(0.0, 255.0);
          final double sb = (wbB * ratio).clamp(0.0, 255.0);
          final double paperFade = ((255.0 - targetL) / 56.0).clamp(0.0, 1.0);
          final double effSat = 1.0 + (satBoost - 1.0) * paperFade;
          final double satFactor = paperFade < 0.25 ? paperFade * 4.0 : effSat;
          nr = (targetL + (sr - targetL) * satFactor).clamp(0.0, 255.0);
          ng = (targetL + (sg - targetL) * satFactor).clamp(0.0, 255.0);
          nb = (targetL + (sb - targetL) * satFactor).clamp(0.0, 255.0);
        }
      }

      if (hasManualTone) {
        nr = ((nr - 128.0) * contrast + 128.0 + brightness * 255.0).clamp(0.0, 255.0);
        ng = ((ng - 128.0) * contrast + 128.0 + brightness * 255.0).clamp(0.0, 255.0);
        nb = ((nb - 128.0) * contrast + 128.0 + brightness * 255.0).clamp(0.0, 255.0);
      }

      final int ri = nr.round().clamp(0, 255), gi = ng.round().clamp(0, 255), bi = nb.round().clamp(0, 255);
      out[p] = ri;
      out[p + 1] = gi;
      out[p + 2] = bi;
      out[p + 3] = 255;
      lumCache[rowOff + x] = ((77 * ri + 150 * gi + 29 * bi) >> 8).clamp(0, 255);
    }
  }

  // STEP 5: HALO-FREE GAUSSIAN CORING UNSHARP MASK
  final double baseSharp = filter == 'dark_ink'
      ? (0.48 + 0.40 * intensity)
      : (filter == 'magic_pro' || filter == 'auto_pro' || filter == 'ocv_crisp')
          ? (0.35 + 0.35 * intensity)
          : (filter == 'original' ? 0.0 : 0.24);
  final double sharpAmt = (baseSharp * (0.4 + userSharpness * 1.2)).clamp(0.0, 1.35);

  if (sharpAmt > 0.05 && w > 3 && h > 3) {
    for (int y = 1; y < h - 1; y++) {
      final int r0 = (y - 1) * w, r1 = y * w, r2 = (y + 1) * w;
      for (int x = 1; x < w - 1; x++) {
        final int center = lumCache[r1 + x];
        if (center >= 250) continue;
        final int blur = (lumCache[r0 + x - 1] +
                2 * lumCache[r0 + x] +
                lumCache[r0 + x + 1] +
                2 * lumCache[r1 + x - 1] +
                4 * center +
                2 * lumCache[r1 + x + 1] +
                lumCache[r2 + x - 1] +
                2 * lumCache[r2 + x] +
                lumCache[r2 + x + 1]) >>
            4;
        final int diff = center - blur;
        if (diff.abs() > 5) {
          final int delta = (diff * sharpAmt).round().clamp(-45, 45);
          final int p = (r1 + x) * 4;
          out[p] = (out[p] + delta).clamp(0, 255);
          out[p + 1] = (out[p + 1] + delta).clamp(0, 255);
          out[p + 2] = (out[p + 2] + delta).clamp(0, 255);
        }
      }
    }
  }

  _paintEraserStrokes(out, w, h, eraserStrokes);
  return out;
}

void _paintEraserStrokes(Uint8List out, int w, int h, List eraserStrokes) {
  if (eraserStrokes.isEmpty) return;
  final int minDim = min(w, h);
  for (final stroke in eraserStrokes) {
    final List pts = stroke['points'] as List? ?? const [];
    final double rNorm = (stroke['radius'] as num?)?.toDouble() ?? 0.035;
    final int radPx = max(2, (rNorm * minDim).round());
    final int radSq = radPx * radPx;

    for (int k = 0; k < pts.length; k++) {
      final List p1 = pts[k] as List;
      final double x1 = (p1[0] as num).toDouble() * w;
      final double y1 = (p1[1] as num).toDouble() * h;

      double x2 = x1, y2 = y1;
      if (k + 1 < pts.length) {
        final List p2 = pts[k + 1] as List;
        x2 = (p2[0] as num).toDouble() * w;
        y2 = (p2[1] as num).toDouble() * h;
      }

      final double dist = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
      final int steps = max(1, (dist / max(1.0, radPx * 0.4)).ceil());
      for (int s = 0; s <= steps; s++) {
        final double t = s / steps;
        final int cx = (x1 + (x2 - x1) * t).round();
        final int cy = (y1 + (y2 - y1) * t).round();
        final int minY = max(0, cy - radPx), maxY = min(h - 1, cy + radPx);
        final int minX = max(0, cx - radPx), maxX = min(w - 1, cx + radPx);
        for (int py = minY; py <= maxY; py++) {
          final int dy = py - cy;
          final int rb = py * w;
          for (int px = minX; px <= maxX; px++) {
            final int dx = px - cx;
            if (dx * dx + dy * dy <= radSq) {
              final int idx = (rb + px) * 4;
              out[idx] = 255;
              out[idx + 1] = 255;
              out[idx + 2] = 255;
              out[idx + 3] = 255;
            }
          }
        }
      }
    }
  }
}

// AI DESKEW ENGINE
class AIDeskewEngine {
  static Future<double> detectSkewAngle(String imagePath) async {
    final textRecognizer = TextRecognizer();
    try {
      final recognizedText = await textRecognizer.processImage(InputImage.fromFilePath(imagePath));
      final List<double> angles = [];
      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          if (line.cornerPoints.length >= 2) {
            final p1 = line.cornerPoints[0], p2 = line.cornerPoints[1];
            double angleDeg = atan2((p2.y - p1.y).toDouble(), (p2.x - p1.x).toDouble()) * 180 / pi;
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
    } finally {
      await textRecognizer.close();
    }
    return 0.0;
  }

  static Future<String> rotateAndDeskewImage(String sourcePath, double angleDegrees) async {
    try {
      final rawBytes = await File(sourcePath).readAsBytes();
      final outBytes = await compute(_rotateArbitraryIsolate, {'bytes': rawBytes, 'angle': angleDegrees});
      if (outBytes != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final scansDir = Directory('${appDir.path}/scans');
        if (!await scansDir.exists()) await scansDir.create(recursive: true);
        final outF = File('${scansDir.path}/deskew_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await outF.writeAsBytes(outBytes);
        return outF.path;
      }
    } catch (e) {
      debugPrint("Rotate Deskew err: $e");
    }
    return sourcePath;
  }
}

Uint8List? _rotateArbitraryIsolate(Map<String, dynamic> params) {
  final decoded = img.decodeImage(params['bytes']);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final rotated = img.copyRotate(oriented, angle: params['angle']);
  return Uint8List.fromList(img.encodeJpg(rotated, quality: 93));
}
// ==================== PART 1 END ====================
// ==================== PART 2 START ====================
// PHONE STORAGE MANAGER
class StorageSaveResult {
  final int count;
  final String? savedPath;
  final String folderLabel;
  const StorageSaveResult({required this.count, this.savedPath, required this.folderLabel});
}

class PhoneStorageManager {
  static Future<Map<String, dynamic>> _resolvePublicDir(String primaryPath, String secondaryPath, String publicLabel) async {
    for (final path in [primaryPath, secondaryPath]) {
      try {
        final dir = Directory(path);
        if (!await dir.exists()) await dir.create(recursive: true);
        final testFile = File('${dir.path}/.bharat_test_${DateTime.now().millisecondsSinceEpoch}');
        await testFile.writeAsString('ok');
        await testFile.delete();
        return {'dir': dir, 'label': publicLabel};
      } catch (_) {}
    }
    final ext = await getExternalStorageDirectory();
    final fallback = Directory('${ext?.path ?? (await getApplicationDocumentsDirectory()).path}/BharatScanner');
    if (!await fallback.exists()) await fallback.create(recursive: true);
    return {'dir': fallback, 'label': 'Android/data/BharatScanner'};
  }

  static Future<StorageSaveResult> saveImagesToPublicGallery(List<String> imagePaths, String docTitle) async {
    int savedCount = 0;
    String folderLabel = 'Pictures/BharatScanner';
    String? lastPath;
    try {
      final resolved = await _resolvePublicDir('/storage/emulated/0/Pictures/BharatScanner', '/storage/emulated/0/DCIM/BharatScanner', 'Pictures/BharatScanner');
      final Directory targetDir = resolved['dir'];
      folderLabel = resolved['label'];
      final safeName = docTitle.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      for (int i = 0; i < imagePaths.length; i++) {
        final f = File(imagePaths[i]);
        if (await f.exists()) {
          final dest = File('${targetDir.path}/${safeName}_p${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await f.copy(dest.path);
          lastPath = dest.path;
          savedCount++;
        }
      }
    } catch (e) {
      debugPrint("Gallery export error: $e");
    }
    return StorageSaveResult(count: savedCount, savedPath: lastPath, folderLabel: folderLabel);
  }

  static Future<StorageSaveResult> savePdfBytesToPublicDownloads(Uint8List pdfBytes, String docTitle) async {
    try {
      final resolved = await _resolvePublicDir('/storage/emulated/0/Download/BharatScanner', '/storage/emulated/0/Documents/BharatScanner', 'Download/BharatScanner');
      final Directory targetDir = resolved['dir'];
      final safeName = docTitle.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      final dest = File('${targetDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await dest.writeAsBytes(pdfBytes);
      return StorageSaveResult(count: 1, savedPath: dest.path, folderLabel: resolved['label']);
    } catch (e) {
      debugPrint("PDF save error: $e");
      return const StorageSaveResult(count: 0, folderLabel: 'Error');
    }
  }
}

// PRO TARGET COMPRESSION ENGINE (10KB - 5MB)
class CompressedBundleResult {
  final File pdfFile;
  final List<File> jpgFiles;
  final double pdfSizeKb;
  final double jpgTotalSizeKb;
  CompressedBundleResult({required this.pdfFile, required this.jpgFiles, required this.pdfSizeKb, required this.jpgTotalSizeKb});
}

Uint8List _compressSingleImageIsolate(Map<String, dynamic> params) {
  final Uint8List rawBytes = params['bytes'];
  final int targetBytes = params['targetBytes'];
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) return rawBytes;
  final oriented = img.bakeOrientation(decoded);

  int maxDim = 1650;
  if (targetBytes < 30 * 1024) {
    maxDim = 600;
  } else if (targetBytes < 80 * 1024) {
    maxDim = 960;
  } else if (targetBytes < 220 * 1024) {
    maxDim = 1320;
  }

  img.Image working = oriented;
  if (oriented.width > maxDim || oriented.height > maxDim) {
    working = oriented.width >= oriented.height ? img.copyResize(oriented, width: maxDim) : img.copyResize(oriented, height: maxDim);
  }

  int lo = 12, hi = 92;
  Uint8List best = Uint8List.fromList(img.encodeJpg(working, quality: 50));
  for (int iter = 0; iter < 5; iter++) {
    final int mid = (lo + hi) ~/ 2;
    final candidate = Uint8List.fromList(img.encodeJpg(working, quality: mid));
    best = candidate;
    if (candidate.length > targetBytes) {
      hi = mid - 1;
    } else {
      lo = mid + 1;
    }
  }
  if (best.length > targetBytes && working.width > 320) {
    final scaled = img.copyResize(working, width: (working.width * 0.65).round());
    best = Uint8List.fromList(img.encodeJpg(scaled, quality: 28));
  }
  return best;
}

class ProCompressionEngine {
  static Future<CompressedBundleResult?> compressOrderedPages({required List<String> orderedImagePaths, required int targetKb, required String docTitle}) async {
    if (orderedImagePaths.isEmpty) return null;
    final safeName = docTitle.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    final tempDir = await getTemporaryDirectory();
    final int totalTargetBytes = max(10 * 1024, targetKb * 1024);
    final int perPageTargetBytes = max(8 * 1024, (totalTargetBytes * 0.90) ~/ orderedImagePaths.length);

    final pdf = pw.Document();
    final List<File> jpgFiles = [];
    int totalJpgBytes = 0;

    for (int i = 0; i < orderedImagePaths.length; i++) {
      final srcFile = File(orderedImagePaths[i]);
      if (!await srcFile.exists()) continue;
      final rawBytes = await srcFile.readAsBytes();
      final compressedJpg = await compute(_compressSingleImageIsolate, {'bytes': rawBytes, 'targetBytes': perPageTargetBytes});
      final jpgOut = File('${tempDir.path}/${safeName}_comp_p${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await jpgOut.writeAsBytes(compressedJpg);
      jpgFiles.add(jpgOut);
      totalJpgBytes += compressedJpg.length;
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(8), build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(compressedJpg), fit: pw.BoxFit.contain))));
    }
    final pdfBytes = await pdf.save();
    final pdfOut = File('${tempDir.path}/${safeName}_compressed_${targetKb}KB.pdf');
    await pdfOut.writeAsBytes(pdfBytes);
    return CompressedBundleResult(pdfFile: pdfOut, jpgFiles: jpgFiles, pdfSizeKb: pdfBytes.length / 1024.0, jpgTotalSizeKb: totalJpgBytes / 1024.0);
  }

  static void showCompressorDialog({required BuildContext context, required List<String> orderedPaths, required String title}) {
    double targetKb = 150;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Compress (${orderedPaths.length} Page${orderedPaths.length > 1 ? 's' : ''})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Target Size:'),
                  Text(targetKb >= 1000 ? '${(targetKb / 1000).toStringAsFixed(1)} MB' : '${targetKb.toInt()} KB', style: TextStyle(fontWeight: FontWeight.bold, color: appPrimaryColor.value, fontSize: 15)),
                ],
              ),
              Slider(value: targetKb, min: 10, max: 5000, divisions: 100, activeColor: appPrimaryColor.value, onChanged: (v) => setDialogState(() => targetKb = v)),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [20, 50, 100, 200, 500, 1000, 2000].map((preset) => ActionChip(label: Text(preset >= 1000 ? '${preset ~/ 1000} MB' : '$preset KB', style: const TextStyle(fontSize: 10)), onPressed: () => setDialogState(() => targetKb = preset.toDouble()))).toList(),
              ),
            ],
          ),
          actions: [
            TextButton.icon(icon: const Icon(Icons.close, size: 16), label: Text(AppLang.tr('cancel')), onPressed: () => Navigator.pop(ctx)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
              icon: const Icon(Icons.compress_rounded, size: 18),
              label: const Text('Compress Now'),
              onPressed: () {
                Navigator.pop(ctx);
                _runCompressionWithResultSheet(context: context, orderedPaths: orderedPaths, targetKb: targetKb.toInt(), title: title);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _runCompressionWithResultSheet({required BuildContext context, required List<String> orderedPaths, required int targetKb, required String title}) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Expanded(child: Text('Compressing PDF & JPG...'))])));
    final bundle = await compressOrderedPages(orderedImagePaths: orderedPaths, targetKb: targetKb, docTitle: title);
    if (context.mounted) Navigator.pop(context);
    if (bundle == null || !context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 42),
              const SizedBox(height: 6),
              const Text('Compression Complete!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('PDF Size: ${bundle.pdfSizeKb.toStringAsFixed(1)} KB  •  JPG Total: ${bundle.jpgTotalSizeKb.toStringAsFixed(1)} KB (${bundle.jpgFiles.length} Pages)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  LabeledIconButton(
                    icon: Icons.download_for_offline_rounded,
                    label: AppLang.tr('save_pdf'),
                    color: Colors.redAccent,
                    iconSize: 28,
                    fontSize: 11,
                    onPressed: () async {
                      final pdfBytes = await bundle.pdfFile.readAsBytes();
                      final res = await PhoneStorageManager.savePdfBytesToPublicDownloads(pdfBytes, '${title}_compressed');
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.savedPath != null ? '✅ Compressed PDF saved to ${res.folderLabel}!' : '❌ Failed to save PDF'), backgroundColor: Colors.green.shade700));
                      }
                    },
                  ),
                  LabeledIconButton(
                    icon: Icons.save_alt_rounded,
                    label: AppLang.tr('save_jpg'),
                    color: Colors.teal,
                    iconSize: 28,
                    fontSize: 11,
                    onPressed: () async {
                      final res = await PhoneStorageManager.saveImagesToPublicGallery(bundle.jpgFiles.map((f) => f.path).toList(), '${title}_compressed');
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${res.count} Compressed JPG(s) saved to ${res.folderLabel}!'), backgroundColor: Colors.green.shade700));
                      }
                    },
                  ),
                  LabeledIconButton(icon: Icons.picture_as_pdf_rounded, label: AppLang.tr('share_pdf'), color: appPrimaryColor.value, iconSize: 28, fontSize: 11, onPressed: () => Share.shareXFiles([XFile(bundle.pdfFile.path)], text: '$title (Compressed PDF)')),
                  LabeledIconButton(icon: Icons.image_rounded, label: AppLang.tr('share_jpg'), color: Colors.indigo, iconSize: 28, fontSize: 11, onPressed: () => Share.shareXFiles(bundle.jpgFiles.map((f) => XFile(f.path)).toList(), text: '$title (Compressed JPG)')),
                ],
              ),
              const SizedBox(height: 10),
              TextButton.icon(icon: const Icon(Icons.close, size: 18), label: const Text('Close'), onPressed: () => Navigator.pop(sheetCtx)),
            ],
          ),
        ),
      ),
    );
  }
}

// MAIN & APP ROOT
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("AdMob Init: $e");
  }
  final prefs = await SharedPreferences.getInstance();
  appThemeMode.value = (prefs.getBool('is_dark_mode') ?? false) ? ThemeMode.dark : ThemeMode.light;
  final colorVal = prefs.getInt('primary_color_val_v2');
  if (colorVal != null) appPrimaryColor.value = Color(colorVal);
  isHindiLanguage.value = prefs.getBool('app_language_hindi') ?? false;
  runApp(const BharatDocScannerApp());
}

class BharatDocScannerApp extends StatelessWidget {
  const BharatDocScannerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appPrimaryColor,
      builder: (_, color, __) => ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeMode,
        builder: (_, mode, ___) => ValueListenableBuilder<bool>(
          valueListenable: isHindiLanguage,
          builder: (_, __, ____) => MaterialApp(
            title: 'Bharat Document Scanner PDF AI',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: ThemeData(useMaterial3: true, brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF8F9FA), colorSchemeSeed: color, appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black87)),
            darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF121212), colorSchemeSeed: color, appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Color(0xFF1E1E1E), foregroundColor: Colors.white)),
            home: const SplashScreen(),
          ),
        ),
      ),
    );
  }
}

// 1. SPLASH SCREEN (WITH "Created by Yogesh Verma" AT BOTTOM)
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
    _timer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(PageRouteBuilder(pageBuilder: (_, __, ___) => const MainDashboardScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c)));
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
      backgroundColor: const Color(0xFF0C2318),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 270,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF173D2B), Color(0xFF0E271C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFF3A8D63), width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 15))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('BHARAT', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 3.0, color: Color(0xFFF1C40F))),
                      const SizedBox(height: 4),
                      const Text('DOCUMENT SCANNER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2.0, color: Colors.white)),
                      const SizedBox(height: 8),
                      const Text('PDF', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFF4CAF50))),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('A', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFFFFA000))),
                          Icon(Icons.star, color: Color(0xFFFFA000), size: 20),
                          Text('i', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFFFFA000))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text('AI DESKEW & PRO CLARITY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 22,
              child: Text('Created by Yogesh Verma', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.1)),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. MAIN DASHBOARD SCREEN
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
  final TextEditingController _searchController = TextEditingController();
  bool _isDocSelectionMode = false;
  final List<String> _selectedDocIdsOrder = [];
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

  @override
  void dispose() {
    _searchController.removeListener(_filterDocs);
    _searchController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: kDebugMode ? 'ca-app-pub-3940256099942544/6300978111' : 'ca-app-pub-7940311763952252/4182204348',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(onAdLoaded: (_) { if (mounted) setState(() => _isBannerLoaded = true); }, onAdFailedToLoad: (ad, err) => ad.dispose()),
    )..load();
  }

  Future<void> _loadUserFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? customFolders = prefs.getStringList('custom_user_folders_v3');
    if (customFolders != null && customFolders.isNotEmpty && mounted) {
      setState(() => _userFolders = ['All', ...customFolders, 'Starred']);
    }
  }

  Future<String?> _addNewFolder(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty || _userFolders.contains(name)) return null;
    final prefs = await SharedPreferences.getInstance();
    final currentCustom = _userFolders.where((f) => f != 'All' && f != 'Starred').toList()..add(name);
    await prefs.setStringList('custom_user_folders_v3', currentCustom);
    if (mounted) setState(() => _userFolders = ['All', ...currentCustom, 'Starred']);
    return name;
  }

  Future<void> _loadSavedDocs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString('saved_documents_v6');
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
    await prefs.setString('saved_documents_v6', jsonEncode(_savedDocs));
  }

  void _filterDocs() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredDocs = _savedDocs.where((doc) {
        final matchesSearch = (doc['title'] ?? '').toString().toLowerCase().contains(q);
        final matchesCat = _selectedCategory == 'All' || (_selectedCategory == 'Starred' ? (doc['isFavorite'] == true) : (doc['category'] ?? 'General') == _selectedCategory);
        return matchesSearch && matchesCat;
      }).toList();
    });
  }

  List<String> get _actualFolders => _userFolders.where((f) => f != 'All' && f != 'Starred').toList();

  void _moveDocumentsToFolderDialog(List<String> docIds) {
    if (docIds.isEmpty) return;
    final folders = _actualFolders;
    String selectedTarget = folders.isNotEmpty ? folders.first : 'General';
    final newFolderCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Move ${docIds.length} Document(s) to Folder', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedTarget,
                decoration: const InputDecoration(labelText: 'Target Folder', border: OutlineInputBorder()),
                items: folders.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) { if (v != null) setDState(() => selectedTarget = v); },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: newFolderCtrl, decoration: const InputDecoration(labelText: 'Or Create New Folder', border: OutlineInputBorder(), isDense: true))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                    onPressed: () async {
                      final created = await _addNewFolder(newFolderCtrl.text);
                      if (created != null) {
                        setDState(() {
                          selectedTarget = created;
                          newFolderCtrl.clear();
                        });
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton.icon(icon: const Icon(Icons.close, size: 16), label: Text(AppLang.tr('cancel')), onPressed: () => Navigator.pop(ctx)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
              icon: const Icon(Icons.drive_file_move_rounded, size: 18),
              label: const Text('Move Now'),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  for (final doc in _savedDocs) {
                    if (docIds.contains(doc['id'].toString())) doc['category'] = selectedTarget;
                  }
                  _isDocSelectionMode = false;
                  _selectedDocIdsOrder.clear();
                  _filterDocs();
                });
                _commitDocsToPrefs();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Moved to "$selectedTarget" folder!')));
              },
            ),
          ],
        ),
      ),
    ).whenComplete(() => newFolderCtrl.dispose());
  }

  Future<void> _transferPagesBetweenDocs({
    required String sourceDocId,
    required List<String> pagePaths,
    required List<String> origPaths,
    required List<int> sourceIndicesToRemove,
    required String actionType,
    String? targetDocId,
    String? targetFolder,
    String? newDocTitle,
  }) async {
    if (pagePaths.isEmpty) return;
    setState(() {
      if (actionType == 'copy_doc' || actionType == 'move_doc') {
        final targetIdx = _savedDocs.indexWhere((d) => d['id'].toString() == targetDocId);
        if (targetIdx != -1) {
          final tImgs = List<String>.from(_savedDocs[targetIdx]['images'] ?? [])..addAll(pagePaths);
          final tOrigs = List<String>.from(_savedDocs[targetIdx]['originalImages'] ?? tImgs)..addAll(origPaths);
          _savedDocs[targetIdx]['images'] = tImgs;
          _savedDocs[targetIdx]['originalImages'] = tOrigs;
          _savedDocs[targetIdx]['pages'] = tImgs.length;
        }
      } else if (actionType == 'new_doc_folder') {
        _savedDocs.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': (newDocTitle == null || newDocTitle.trim().isEmpty) ? 'Moved_Doc_${DateFormat('ddMMM_HHmm').format(DateTime.now())}' : newDocTitle.trim(),
          'category': targetFolder ?? 'General',
          'isFavorite': false,
          'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
          'images': List<String>.from(pagePaths),
          'originalImages': List<String>.from(origPaths),
          'pages': pagePaths.length,
        });
      }
      if (actionType == 'move_doc' || (actionType == 'new_doc_folder' && sourceIndicesToRemove.isNotEmpty)) {
        final srcIdx = _savedDocs.indexWhere((d) => d['id'].toString() == sourceDocId);
        if (srcIdx != -1) {
          final sImgs = List<String>.from(_savedDocs[srcIdx]['images'] ?? []);
          final sOrigs = List<String>.from(_savedDocs[srcIdx]['originalImages'] ?? sImgs);
          final sortedDesc = sourceIndicesToRemove.toList()..sort((a, b) => b.compareTo(a));
          for (final rmIdx in sortedDesc) {
            if (rmIdx >= 0 && rmIdx < sImgs.length) sImgs.removeAt(rmIdx);
            if (rmIdx >= 0 && rmIdx < sOrigs.length) sOrigs.removeAt(rmIdx);
          }
          if (sImgs.isEmpty) {
            _savedDocs.removeAt(srcIdx);
          } else {
            _savedDocs[srcIdx]['images'] = sImgs;
            _savedDocs[srcIdx]['originalImages'] = sOrigs;
            _savedDocs[srcIdx]['pages'] = sImgs.length;
          }
        }
      }
      _filterDocs();
    });
    await _commitDocsToPrefs();
  }

  void _combineSelectedDocsIntoOne() {
    if (_selectedDocIdsOrder.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least 2 documents to combine!')));
      return;
    }
    final nameCtrl = TextEditingController(text: 'Combined_${DateFormat('ddMMM_HHmm').format(DateTime.now())}');
    String chosenFolder = _actualFolders.isNotEmpty ? _actualFolders.first : 'General';
    bool deleteSourceDocs = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Combine ${_selectedDocIdsOrder.length} Docs into 1', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'New Document Name', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(value: chosenFolder, decoration: const InputDecoration(labelText: 'Target Folder', border: OutlineInputBorder()), items: _actualFolders.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: (v) { if (v != null) chosenFolder = v; }),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Remove original docs after combining', style: TextStyle(fontSize: 12)), value: deleteSourceDocs, onChanged: (v) => setDState(() => deleteSourceDocs = v ?? false)),
            ],
          ),
          actions: [
            TextButton.icon(icon: const Icon(Icons.close, size: 16), label: Text(AppLang.tr('cancel')), onPressed: () => Navigator.pop(ctx)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
              icon: const Icon(Icons.merge_type_rounded, size: 18),
              label: const Text('Combine'),
              onPressed: () {
                Navigator.pop(ctx);
                final List<String> allImgs = [], allOrigs = [];
                for (final id in _selectedDocIdsOrder) {
                  final d = _savedDocs.firstWhere((e) => e['id'].toString() == id, orElse: () => {});
                  if (d.isNotEmpty) {
                    final imgs = List<String>.from(d['images'] ?? []);
                    final origs = List<String>.from(d['originalImages'] ?? imgs);
                    allImgs.addAll(imgs);
                    allOrigs.addAll(origs);
                  }
                }
                if (allImgs.isEmpty) return;
                setState(() {
                  if (deleteSourceDocs) _savedDocs.removeWhere((d) => _selectedDocIdsOrder.contains(d['id'].toString()));
                  _savedDocs.insert(0, {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'title': nameCtrl.text.trim().isEmpty ? 'Combined_Doc' : nameCtrl.text.trim(), 'category': chosenFolder, 'isFavorite': false, 'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()), 'images': allImgs, 'originalImages': allOrigs, 'pages': allImgs.length});
                  _isDocSelectionMode = false;
                  _selectedDocIdsOrder.clear();
                  _filterDocs();
                });
                _commitDocsToPrefs();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Combined ${allImgs.length} pages into "$chosenFolder"!')));
              },
            ),
          ],
        ),
      ),
    ).whenComplete(() => nameCtrl.dispose());
  }

  Future<void> _importFromGalleryDirectly({String category = 'General', String prefix = 'Gallery'}) async {
    try {
      final List<XFile> picked = await ImagePicker().pickMultiImage();
      if (!mounted || picked.isEmpty) return;
      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory('${appDir.path}/scans');
      if (!await scansDir.exists()) await scansDir.create(recursive: true);

      List<String> persistentRawPaths = [];
      for (int i = 0; i < picked.length; i++) {
        final f = File(picked[i].path);
        if (await f.exists()) {
          final target = await f.copy('${scansDir.path}/gal_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
          persistentRawPaths.add(target.path);
        }
      }
      if (!mounted || persistentRawPaths.isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanFilterReviewScreen(
            rawImagePaths: persistentRawPaths,
            initialFilterId: 'magic_pro',
            onApplyAndProceed: (filteredImages) {
              if (category == 'Personal' && prefix.contains('ID_Card') && filteredImages.length >= 2) {
                _processIdCardCollage(filteredImages.sublist(0, 2), persistentRawPaths);
              } else {
                _promptSaveDoc(filteredImages, persistentRawPaths, prefix, category);
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gallery Error: $e')));
    }
  }

  Future<void> _startDocScan({int limit = 50, String category = 'General', String prefix = 'Doc', String defaultFilter = 'magic_pro'}) async {
    final scanner = DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.base, isGalleryImport: true, pageLimit: limit));
    try {
      final result = await scanner.scanDocument();
      if (!mounted || result.images.isEmpty) return;
      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory('${appDir.path}/scans');
      if (!await scansDir.exists()) await scansDir.create(recursive: true);

      List<String> persistentRawPaths = [];
      for (int i = 0; i < result.images.length; i++) {
        final f = File(result.images[i]);
        if (await f.exists()) {
          final target = await f.copy('${scansDir.path}/raw_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
          persistentRawPaths.add(target.path);
        }
      }
      if (!mounted || persistentRawPaths.isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanFilterReviewScreen(
            rawImagePaths: persistentRawPaths,
            initialFilterId: defaultFilter,
            onApplyAndProceed: (filteredImages) {
              if (category == 'Personal' && prefix.contains('ID_Card') && filteredImages.length >= 2) {
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

  Future<void> _processIdCardCollage(List<String> frontAndBack, List<String> rawImages) async {
    ui.Codec? frontCodec, backCodec;
    ui.Image? frontImg, backImg, a4CollageImg;
    ui.Picture? picture;
    try {
      frontCodec = await ui.instantiateImageCodec(await File(frontAndBack[0]).readAsBytes());
      frontImg = (await frontCodec.getNextFrame()).image;
      backCodec = await ui.instantiateImageCodec(await File(frontAndBack[1]).readAsBytes());
      backImg = (await backCodec.getNextFrame()).image;

      const a4Width = 1240.0, a4Height = 1754.0, cardW = 760.0, cardH = 480.0, left = (a4Width - cardW) / 2;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, a4Width, a4Height));
      canvas.drawRect(const Rect.fromLTWH(0, 0, a4Width, a4Height), Paint()..color = Colors.white);
      final borderPaint = Paint()..color = const Color(0xFFCFD8DC)..style = PaintingStyle.stroke..strokeWidth = 2.0;

      const rect1 = Rect.fromLTWH(left, 200.0, cardW, cardH);
      canvas.drawImageRect(frontImg, Rect.fromLTWH(0, 0, frontImg.width.toDouble(), frontImg.height.toDouble()), rect1, Paint());
      canvas.drawRect(rect1, borderPaint);

      const rect2 = Rect.fromLTWH(left, 820.0, cardW, cardH);
      canvas.drawImageRect(backImg, Rect.fromLTWH(0, 0, backImg.width.toDouble(), backImg.height.toDouble()), rect2, Paint());
      canvas.drawRect(rect2, borderPaint);

      picture = recorder.endRecording();
      a4CollageImg = await picture.toImage(a4Width.toInt(), a4Height.toInt());
      final byteData = await a4CollageImg.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final collageFile = File('${appDir.path}/id_a4_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await collageFile.writeAsBytes(byteData.buffer.asUint8List());
        if (mounted) {
          setState(() {
            _savedDocs.insert(0, {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'title': 'ID_Card_${DateFormat('ddMMM_HHmm').format(DateTime.now())}', 'category': 'Personal', 'isFavorite': false, 'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()), 'images': [collageFile.path], 'originalImages': frontAndBack, 'pages': 1});
            _filterDocs();
          });
        }
        await _commitDocsToPrefs();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Front & Back ID Card stitched onto A4 Sheet!')));
      }
    } catch (e) {
      _promptSaveDoc(frontAndBack, rawImages, 'ID_Card', 'Personal');
    } finally {
      a4CollageImg?.dispose();
      picture?.dispose();
      frontImg?.dispose();
      backImg?.dispose();
      frontCodec?.dispose();
      backCodec?.dispose();
    }
  }

  void _promptSaveDoc(List<String> enhancedImages, List<String> rawImages, String prefix, String defaultCat) {
    final nameCtrl = TextEditingController(text: "${prefix}_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    String chosenFolder = (defaultCat == 'All' || defaultCat == 'Starred') ? 'General' : defaultCat;
    if (!_actualFolders.contains(chosenFolder)) chosenFolder = 'General';

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
            DropdownButtonFormField<String>(value: chosenFolder, decoration: const InputDecoration(labelText: 'Folder', border: OutlineInputBorder()), items: _actualFolders.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: (val) { if (val != null) chosenFolder = val; }),
          ],
        ),
        actions: [
          TextButton.icon(icon: const Icon(Icons.close, size: 16), label: Text(AppLang.tr('cancel')), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(AppLang.tr('save')),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _savedDocs.insert(0, {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'title': nameCtrl.text.trim().isEmpty ? 'Doc_${DateTime.now().millisecondsSinceEpoch}' : nameCtrl.text.trim(), 'category': chosenFolder, 'isFavorite': false, 'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()), 'images': List<String>.from(enhancedImages), 'originalImages': List<String>.from(rawImages), 'pages': enhancedImages.length});
                _filterDocs();
              });
              await _commitDocsToPrefs();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Document Saved with Pro Clarity!')));
            },
          ),
        ],
      ),
    ).whenComplete(() => nameCtrl.dispose());
  }

  void _createNewFolderDialog() {
    final folderCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLang.tr('create_folder'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(controller: folderCtrl, decoration: InputDecoration(labelText: AppLang.tr('folder_name'), border: const OutlineInputBorder())),
        actions: [
          TextButton.icon(icon: const Icon(Icons.close, size: 16), label: Text(AppLang.tr('cancel')), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
            icon: const Icon(Icons.create_new_folder_rounded, size: 16),
            label: Text(AppLang.tr('create')),
            onPressed: () async {
              final created = await _addNewFolder(folderCtrl.text);
              if (created != null) {
                setState(() => _selectedCategory = created);
                _filterDocs();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    ).whenComplete(() => folderCtrl.dispose());
  }

  List<String> _getOrderedImagesFromSelectedDocs() {
    final List<String> orderedPaths = [];
    for (final docId in _selectedDocIdsOrder) {
      final doc = _savedDocs.firstWhere((d) => d['id'] == docId, orElse: () => {});
      if (doc.isNotEmpty && doc['images'] != null) orderedPaths.addAll(List<String>.from(doc['images']));
    }
    return orderedPaths;
  }

  Future<Uint8List> _buildOrderedPdfBytes(List<String> orderedImagePaths) async {
    final pdf = pw.Document();
    for (final path in orderedImagePaths) {
      final f = File(path);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(8), build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain))));
      }
    }
    return pdf.save();
  }

  Future<void> _exportSelectedDocsPdf({required bool saveToPhone}) async {
    final paths = _getOrderedImagesFromSelectedDocs();
    if (paths.isEmpty) return;
    final pdfBytes = await _buildOrderedPdfBytes(paths);
    final name = 'Ordered_Docs_${_selectedDocIdsOrder.length}';
    if (saveToPhone) {
      final res = await PhoneStorageManager.savePdfBytesToPublicDownloads(pdfBytes, name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.savedPath != null ? '✅ Ordered PDF saved to ${res.folderLabel}!' : '❌ Failed to save PDF'), backgroundColor: Colors.green.shade700));
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$name.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Ordered PDF (${_selectedDocIdsOrder.length} Documents)');
    }
  }

  Future<void> _exportSelectedDocsJpg({required bool saveToPhone}) async {
    final paths = _getOrderedImagesFromSelectedDocs();
    if (paths.isEmpty) return;
    if (saveToPhone) {
      final res = await PhoneStorageManager.saveImagesToPublicGallery(paths, 'Selected_Docs');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${res.count} Photo(s) saved to ${res.folderLabel}!'), backgroundColor: Colors.green.shade700));
    } else {
      await Share.shareXFiles(paths.map((p) => XFile(p)).toList(), text: 'Selected Document Pages');
    }
  }

  void _deleteSelectedDocs() {
    if (_selectedDocIdsOrder.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Documents?'),
        content: Text('Delete ${_selectedDocIdsOrder.length} selected document(s)?'),
        actions: [
          TextButton.icon(icon: const Icon(Icons.close, size: 16), label: Text(AppLang.tr('cancel')), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: Text(AppLang.tr('delete')),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _savedDocs.removeWhere((d) => _selectedDocIdsOrder.contains(d['id']));
                _selectedDocIdsOrder.clear();
                _isDocSelectionMode = false;
                _filterDocs();
              });
              _commitDocsToPrefs();
            },
          ),
        ],
      ),
    );
  }

  void _openAddNewDocBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Stack(children: [Icon(Icons.description_rounded, size: 40, color: appPrimaryColor.value), Positioned(right: 0, bottom: 0, child: Container(decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle), padding: const EdgeInsets.all(2), child: const Icon(Icons.add, size: 14, color: Colors.white)))]),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppLang.tr('add_new_doc'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(AppLang.tr('choose_options'), style: const TextStyle(fontSize: 12, color: Colors.grey))])),
                  LabeledIconButton(icon: Icons.keyboard_arrow_down_rounded, label: 'Close', iconSize: 24, onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 4),
              _buildSheetTile(Icons.photo_library_rounded, const Color(0xFF00B4D8), AppLang.tr('from_gallery'), () { Navigator.pop(ctx); _importFromGalleryDirectly(prefix: 'Gallery'); }),
              _buildSheetTile(Icons.camera_alt_rounded, const Color(0xFF4A6572), AppLang.tr('from_camera'), () { Navigator.pop(ctx); _startDocScan(); }),
              _buildSheetTile(Icons.folder_open_rounded, const Color(0xFFEF5350), 'Import Images from Phone Storage', () { Navigator.pop(ctx); _importFromGalleryDirectly(prefix: 'Storage_Img'); }),
              _buildSheetTile(Icons.menu_book_rounded, const Color(0xFF2E7D32), 'Book Page Scan (Dark Ink AI)', () { Navigator.pop(ctx); _startDocScan(prefix: 'Book_Page', defaultFilter: 'dark_ink'); }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetTile(IconData icon, Color color, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 26)),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey), Text('Open', style: TextStyle(fontSize: 8, color: Colors.grey))]),
      onTap: onTap,
    );
  }

  Widget _buildDualFabPill() {
    return ValueListenableBuilder<Color>(
      valueListenable: appPrimaryColor,
      builder: (_, color, __) => Container(
        height: 52,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)), onTap: () => _startDocScan(), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 21), Text(AppLang.tr('camera'), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))]))),
            Container(width: 1.2, height: 28, color: Colors.white38),
            InkWell(borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)), onTap: _openAddNewDocBottomSheet, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.add_rounded, color: Colors.white, size: 22), Text(AppLang.tr('add_gal'), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))]))),
          ],
        ),
      ),
    );
  }

  Future<void> _extractTextOCR(String imagePath) async {
    final textRecognizer = TextRecognizer();
    try {
      final recognizedText = await textRecognizer.processImage(InputImage.fromFilePath(imagePath));
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
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Extracted OCR Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), LabeledIconButton(icon: Icons.copy, label: 'Copy', onPressed: () { Clipboard.setData(ClipboardData(text: textCtrl.text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!'))); })]),
              const Divider(),
              TextField(controller: textCtrl, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder())),
              const SizedBox(height: 12),
              ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(44)), icon: const Icon(Icons.share), label: const Text('Share Extracted Text'), onPressed: () => Share.share(textCtrl.text)),
            ],
          ),
        ),
      ).whenComplete(() => textCtrl.dispose());
    } catch (e) {
      debugPrint("OCR Err: $e");
    } finally {
      await textRecognizer.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: _buildAppDrawer(isDark),
      appBar: AppBar(
        title: _isDocSelectionMode
            ? Text('${_selectedDocIdsOrder.length} Selected (In Order)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
            : (_isSearching ? TextField(controller: _searchController, autofocus: true, decoration: InputDecoration(hintText: AppLang.tr('search'), border: InputBorder.none)) : Text(AppLang.tr('app_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
        actions: _isDocSelectionMode
            ? [
                LabeledIconButton(
                  icon: Icons.select_all_rounded,
                  label: AppLang.tr('all'),
                  onPressed: () => setState(() {
                    if (_selectedDocIdsOrder.length == _filteredDocs.length) {
                      _selectedDocIdsOrder.clear();
                    } else {
                      for (final doc in _filteredDocs) {
                        if (!_selectedDocIdsOrder.contains(doc['id'])) _selectedDocIdsOrder.add(doc['id']);
                      }
                    }
                  }),
                ),
                LabeledIconButton(icon: Icons.close_rounded, label: AppLang.tr('cancel'), onPressed: () => setState(() { _isDocSelectionMode = false; _selectedDocIdsOrder.clear(); })),
              ]
            : [
                LabeledIconButton(icon: _isSearching ? Icons.close : Icons.search_rounded, label: _isSearching ? 'Close' : 'Search', onPressed: () => setState(() { _isSearching = !_isSearching; if (!_isSearching) _searchController.clear(); })),
              ],
      ),
      body: Stack(
        children: [
          _currentTabIndex == 0 ? _buildDocsTab() : _buildToolsTab(),
          if (!_isDocSelectionMode) Positioned(right: 16, bottom: 20, child: _buildDualFabPill()),
        ],
      ),
      floatingActionButtonLocation: _isDocSelectionMode ? null : FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _isDocSelectionMode
          ? null
          : FloatingActionButton(
              elevation: 4,
              shape: const CircleBorder(),
              backgroundColor: appPrimaryColor.value,
              foregroundColor: Colors.white,
              onPressed: () => _startDocScan(),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt_rounded, size: 22), Text(AppLang.tr('scan'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))]),
            ),
      bottomNavigationBar: _isDocSelectionMode
          ? Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: SafeArea(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      LabeledIconButton(icon: Icons.drive_file_move_rounded, label: AppLang.tr('move_folder'), color: Colors.green.shade700, onPressed: () => _moveDocumentsToFolderDialog(List<String>.from(_selectedDocIdsOrder))),
                      LabeledIconButton(icon: Icons.merge_type_rounded, label: AppLang.tr('combine_doc'), color: Colors.deepPurple, onPressed: _combineSelectedDocsIntoOne),
                      LabeledIconButton(icon: Icons.picture_as_pdf_rounded, label: AppLang.tr('share_pdf'), color: appPrimaryColor.value, onPressed: () => _exportSelectedDocsPdf(saveToPhone: false)),
                      LabeledIconButton(icon: Icons.download_for_offline_rounded, label: AppLang.tr('save_pdf'), color: Colors.redAccent, onPressed: () => _exportSelectedDocsPdf(saveToPhone: true)),
                      LabeledIconButton(icon: Icons.image_rounded, label: AppLang.tr('share_jpg'), color: Colors.indigo, onPressed: () => _exportSelectedDocsJpg(saveToPhone: false)),
                      LabeledIconButton(icon: Icons.save_alt_rounded, label: AppLang.tr('save_jpg'), color: Colors.teal, onPressed: () => _exportSelectedDocsJpg(saveToPhone: true)),
                      LabeledIconButton(icon: Icons.compress_rounded, label: AppLang.tr('compress'), color: Colors.orange.shade800, onPressed: () { final paths = _getOrderedImagesFromSelectedDocs(); if (paths.isNotEmpty) ProCompressionEngine.showCompressorDialog(context: context, orderedPaths: paths, title: 'Selected_Docs_${_selectedDocIdsOrder.length}'); }),
                      LabeledIconButton(icon: Icons.delete_rounded, label: AppLang.tr('delete'), color: Colors.red, onPressed: _deleteSelectedDocs),
                    ],
                  ),
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BottomAppBar(
                  shape: const CircularNotchedRectangle(),
                  notchMargin: 8,
                  elevation: 10,
                  color: Theme.of(context).cardColor,
                  child: SizedBox(
                    height: 58,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        InkWell(onTap: () => setState(() => _currentTabIndex = 0), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.folder_special_rounded, color: _currentTabIndex == 0 ? appPrimaryColor.value : Colors.grey, size: 24), Text(AppLang.tr('docs'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _currentTabIndex == 0 ? appPrimaryColor.value : Colors.grey))]))),
                        const SizedBox(width: 48),
                        InkWell(onTap: () => setState(() => _currentTabIndex = 1), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.auto_awesome_mosaic_rounded, color: _currentTabIndex == 1 ? appPrimaryColor.value : Colors.grey, size: 24), Text(AppLang.tr('tools'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _currentTabIndex == 1 ? appPrimaryColor.value : Colors.grey))]))),
                      ],
                    ),
                  ),
                ),
                if (_isBannerLoaded && _bannerAd != null) SizedBox(width: _bannerAd!.size.width.toDouble(), height: _bannerAd!.size.height.toDouble(), child: AdWidget(ad: _bannerAd!)),
              ],
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
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.document_scanner_rounded, size: 36, color: Colors.white), SizedBox(height: 8), Text('BHARAT SCANNER PDF AI', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), Text('Ultra Clarity Book & Studio Edition', style: TextStyle(color: Colors.white70, fontSize: 11))]),
          ),
          ListTile(leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode), title: Text(isDark ? AppLang.tr('light_mode') : AppLang.tr('dark_mode')), onTap: () async { appThemeMode.value = isDark ? ThemeMode.light : ThemeMode.dark; await (await SharedPreferences.getInstance()).setBool('is_dark_mode', !isDark); }),
          ListTile(leading: const Icon(Icons.palette_rounded), title: Text(AppLang.tr('change_theme')), onTap: () { Navigator.pop(context); _openThemeColorPicker(); }),
          ListTile(leading: const Icon(Icons.language_rounded), title: Text(AppLang.tr('language')), trailing: Switch(value: isHindiLanguage.value, activeColor: appPrimaryColor.value, onChanged: (val) async { isHindiLanguage.value = val; await (await SharedPreferences.getInstance()).setBool('app_language_hindi', val); })),
        ],
      ),
    );
  }

  void _openThemeColorPicker() {
    final colors = [const Color(0xFF2E7D32), Colors.pink, Colors.teal, Colors.blue, Colors.deepOrange, Colors.purple, Colors.indigo, Colors.blueGrey];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLang.tr('change_theme')),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((col) => InkWell(
            onTap: () async {
              appPrimaryColor.value = col;
              await (await SharedPreferences.getInstance()).setInt('primary_color_val_v2', col.value);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: CircleAvatar(backgroundColor: col, radius: 20, child: appPrimaryColor.value.value == col.value ? const Icon(Icons.check, color: Colors.white, size: 18) : null),
          )).toList(),
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Theme.of(context).cardColor, border: Border.all(color: Colors.grey.withOpacity(0.2))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildStat(AppLang.tr('total_files'), '${_savedDocs.length}', Icons.insert_drive_file_rounded), Container(width: 1, height: 24, color: Colors.grey.shade300), _buildStat(AppLang.tr('scanned_pages'), '$totalPages', Icons.pages_rounded)]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._userFolders.map((cat) {
                final isSel = _selectedCategory == cat;
                final label = cat == 'All' ? AppLang.tr('all') : (cat == 'Starred' ? AppLang.tr('starred') : cat);
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(label: Text(label), selected: isSel, selectedColor: appPrimaryColor.value, labelStyle: TextStyle(color: isSel ? Colors.white : null, fontSize: 11), onSelected: (_) => setState(() { _selectedCategory = cat; _filterDocs(); })),
                );
              }),
              ActionChip(label: Text(AppLang.tr('new_folder'), style: const TextStyle(fontSize: 11)), onPressed: _createNewFolderDialog),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${AppLang.tr('docs')} (${_filteredDocs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), const Text('Long press to select in order or move folder', style: TextStyle(fontSize: 10, color: Colors.grey))])),
            LabeledIconButton(icon: _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, label: _isGridView ? 'List View' : 'Grid View', iconSize: 20, onPressed: () => setState(() => _isGridView = !_isGridView)),
          ],
        ),
        const SizedBox(height: 4),
        if (_filteredDocs.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 80), child: Center(child: Text(AppLang.tr('no_docs'), textAlign: TextAlign.center)))
        else if (_isGridView)
          GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _filteredDocs.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72), itemBuilder: (ctx, i) => _buildDocGridCard(_filteredDocs[i]))
        else
          ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _filteredDocs.length, itemBuilder: (ctx, i) => _buildDocListTile(_filteredDocs[i])),
        const SizedBox(height: 95),
      ],
    );
  }

  Widget _buildStat(String label, String count, IconData icon) => Row(children: [Icon(icon, size: 18, color: appPrimaryColor.value), const SizedBox(width: 6), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))])]);

  void _toggleDocSelection(String docId) {
    setState(() {
      if (_selectedDocIdsOrder.contains(docId)) {
        _selectedDocIdsOrder.remove(docId);
        if (_selectedDocIdsOrder.isEmpty) _isDocSelectionMode = false;
      } else {
        _isDocSelectionMode = true;
        _selectedDocIdsOrder.add(docId);
      }
    });
  }

  void _copyWholeDocToAnotherDoc(Map<String, dynamic> srcDoc) {
    final others = _savedDocs.where((d) => d['id'] != srcDoc['id']).toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create another document first to add into it!')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add "${srcDoc['title']}" Pages Into:', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 260,
          child: ListView.builder(
            itemCount: others.length,
            itemBuilder: (_, i) {
              final target = others[i];
              return ListTile(
                leading: Icon(Icons.description_rounded, color: appPrimaryColor.value),
                title: Text(target['title'] ?? 'Doc', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${target['pages']} pages • ${target['category']}'),
                onTap: () {
                  Navigator.pop(ctx);
                  final sImgs = List<String>.from(srcDoc['images'] ?? []);
                  final sOrigs = List<String>.from(srcDoc['originalImages'] ?? sImgs);
                  _transferPagesBetweenDocs(sourceDocId: srcDoc['id'].toString(), pagePaths: sImgs, origPaths: sOrigs, sourceIndicesToRemove: const [], actionType: 'copy_doc', targetDocId: target['id'].toString());
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Added ${sImgs.length} page(s) into "${target['title']}"!')));
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr('cancel')))],
      ),
    );
  }

  Widget _buildDocPopupMenu(Map<String, dynamic> doc) {
    final bool isFav = doc['isFavorite'] == true;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
      onSelected: (val) {
        if (val == 'move_folder') {
          _moveDocumentsToFolderDialog([doc['id'].toString()]);
        } else if (val == 'add_to_doc') {
          _copyWholeDocToAnotherDoc(doc);
        } else if (val == 'fav') {
          setState(() { doc['isFavorite'] = !isFav; _filterDocs(); });
          _commitDocsToPrefs();
        } else if (val == 'delete') {
          setState(() { _savedDocs.removeWhere((d) => d['id'] == doc['id']); _filterDocs(); });
          _commitDocsToPrefs();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'move_folder', child: ListTile(leading: Icon(Icons.drive_file_move_rounded), title: Text('Move to Folder'), dense: true)),
        const PopupMenuItem(value: 'add_to_doc', child: ListTile(leading: Icon(Icons.post_add_rounded), title: Text('Copy into Another Doc'), dense: true)),
        PopupMenuItem(value: 'fav', child: ListTile(leading: Icon(isFav ? Icons.star : Icons.star_border, color: Colors.amber), title: Text(isFav ? 'Remove Star' : 'Add to Starred'), dense: true)),
        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_rounded, color: Colors.red), title: Text('Delete'), dense: true)),
      ],
    );
  }

  Widget _buildDocListTile(Map<String, dynamic> doc) {
    final List imgs = doc['images'] ?? [];
    final bool hasImage = imgs.isNotEmpty && File(imgs.first).existsSync();
    final String docId = doc['id'].toString();
    final int orderIdx = _selectedDocIdsOrder.indexOf(docId);
    final bool isSelected = orderIdx != -1;

    return Card(
      elevation: isSelected ? 2 : 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? appPrimaryColor.value : Colors.transparent, width: isSelected ? 2 : 0)),
      child: ListTile(
        leading: Stack(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(6), child: hasImage ? Image.file(File(imgs.first), width: 50, height: 60, fit: BoxFit.cover, cacheWidth: 160) : Container(width: 50, height: 60, color: Colors.grey.shade200)),
            if (isSelected) Positioned(top: 2, left: 2, child: CircleAvatar(radius: 10, backgroundColor: appPrimaryColor.value, child: Text('${orderIdx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
          ],
        ),
        title: Row(children: [Expanded(child: Text(doc['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)), if (doc['isFavorite'] == true) const Icon(Icons.star, size: 14, color: Colors.amber)]),
        subtitle: Text('${doc['pages']} pages • ${doc['category'] ?? 'General'} • ${doc['date']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        trailing: _isDocSelectionMode ? Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? appPrimaryColor.value : Colors.grey) : _buildDocPopupMenu(doc),
        onLongPress: () => _toggleDocSelection(docId),
        onTap: () => _isDocSelectionMode ? _toggleDocSelection(docId) : _openDocDetail(doc),
      ),
    );
  }

  Widget _buildDocGridCard(Map<String, dynamic> doc) {
    final List imgs = doc['images'] ?? [];
    final bool hasImg = imgs.isNotEmpty && File(imgs.first).existsSync();
    final String docId = doc['id'].toString();
    final int orderIdx = _selectedDocIdsOrder.indexOf(docId);
    final bool isSelected = orderIdx != -1;

    return InkWell(
      onLongPress: () => _toggleDocSelection(docId),
      onTap: () => _isDocSelectionMode ? _toggleDocSelection(docId) : _openDocDetail(doc),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? appPrimaryColor.value : Colors.grey.withOpacity(0.25), width: isSelected ? 2.5 : 1)),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(11)), child: hasImg ? Image.file(File(imgs.first), fit: BoxFit.cover, width: double.infinity, cacheWidth: 260) : Container(color: Colors.grey.shade200))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 2, 6),
                  child: Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(doc['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('${doc['pages']} p • ${doc['category'] ?? 'General'}', style: const TextStyle(color: Colors.grey, fontSize: 9))])),
                      if (!_isDocSelectionMode) _buildDocPopupMenu(doc),
                    ],
                  ),
                ),
              ],
            ),
            if (_isDocSelectionMode)
              Positioned(top: 6, right: 6, child: isSelected ? CircleAvatar(radius: 13, backgroundColor: appPrimaryColor.value, child: Text('#${orderIdx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))) : const Icon(Icons.circle_outlined, color: Colors.white, size: 26)),
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
          allDocs: _savedDocs,
          userFolders: _actualFolders,
          onCreateFolder: _addNewFolder,
          onDocUpdated: (updated) {
            setState(() {
              final idx = _savedDocs.indexWhere((d) => d['id'] == updated['id']);
              if (idx != -1) _savedDocs[idx] = updated;
              _filterDocs();
            });
            _commitDocsToPrefs();
          },
          onTransferPages: _transferPagesBetweenDocs,
          onDelete: () {
            setState(() { _savedDocs.removeWhere((d) => d['id'] == doc['id']); _filterDocs(); });
            _commitDocsToPrefs();
          },
          onExtractText: _extractTextOCR,
        ),
      ),
    );
  }

  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Smart AI Scan Modes'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard('ID Card Mode', 'Front & Back', Icons.badge_outlined, Colors.blue, () => _startDocScan(limit: 2, category: 'Personal', prefix: 'ID_Card')),
            _buildToolCard('Book Scan', 'Dark Ink AI', Icons.menu_book_rounded, Colors.green, () => _startDocScan(prefix: 'Book_Page', defaultFilter: 'dark_ink')),
            _buildToolCard('AI OCR Text', 'Extract Text', Icons.auto_awesome, Colors.purple, () {
              if (_savedDocs.isNotEmpty && (_savedDocs.first['images'] as List).isNotEmpty) {
                _extractTextOCR(_savedDocs.first['images'][0]);
              } else {
                _startDocScan();
              }
            }),
            _buildToolCard('From Gallery', 'Phone Photos', Icons.photo_library_outlined, const Color(0xFFD81B60), () => _importFromGalleryDirectly(prefix: 'Gallery')),
            _buildToolCard('Target Compress', '10KB - 5MB', Icons.compress_rounded, Colors.teal, () {
              if (_savedDocs.isNotEmpty) {
                _openDocDetail(_savedDocs.first);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please scan or create a document first!')));
              }
            }),
            _buildToolCard('QR & Barcode', 'Generate Code', Icons.qr_code_2_rounded, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrBarcodeStudioScreen()))),
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
            _buildToolCard('GST Invoice', 'With Tax Slips', Icons.receipt_long_rounded, const Color(0xFF2E7D32), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceMakerProScreen()))),
            _buildToolCard('Slides Maker', 'PPT Slides', Icons.slideshow_rounded, const Color(0xFFD84315), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PowerPointStudioScreen()))),
            _buildToolCard('Letters', 'Formal Letters', Icons.mail_outline_rounded, const Color(0xFF6A1B9A), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LetterTemplatesScreen()))),
            _buildToolCard('Notes & TXT', 'Text Editor', Icons.edit_note_rounded, const Color(0xFF00796B), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen()))),
            _buildToolCard('Passport Photo', '4/8/16 Prints', Icons.portrait_rounded, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportPhotoStudioScreen()))),
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
        const SizedBox(height: 95),
      ],
    );
  }

  Widget _buildSectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Container(width: 4, height: 16, color: appPrimaryColor.value), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]));

  Widget _buildToolCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).cardColor, border: Border.all(color: Colors.grey.withOpacity(0.2))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 20, backgroundColor: color.withOpacity(0.12), foregroundColor: color, child: Icon(icon, size: 20)), const SizedBox(height: 6), Text(title, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text(subtitle, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(color: Colors.grey, fontSize: 9))]),
      ),
    );
  }
}
// ==================== PART 2 END ====================
// ==================== PART 3 START ====================
// ============================================================================
// 3. PRO SCAN FILTER, MANUAL ADJUST & ERASER SCREEN
// ============================================================================
class ScanFilterReviewScreen extends StatefulWidget {
  final List<String> rawImagePaths;
  final String initialFilterId;
  final Function(List<String> filteredPaths) onApplyAndProceed;

  const ScanFilterReviewScreen({super.key, required this.rawImagePaths, this.initialFilterId = 'magic_pro', required this.onApplyAndProceed});
  @override
  State<ScanFilterReviewScreen> createState() => _ScanFilterReviewScreenState();
}

class _ScanFilterReviewScreenState extends State<ScanFilterReviewScreen> {
  int _curPageIndex = 0;
  bool _isSaving = false;
  bool _isRenderingPreview = false;
  bool _showOriginalHold = false;
  // Tabs: 0 = Straighten AI, 1 = Pro Filters, 2 = Adjust (B/C/S), 3 = Eraser, 4 = Tilt & Rotate
  int _activeTopTab = 1;

  late List<String> _workingPaths;
  late Map<int, String> _pageFilterSelections;
  late Map<int, double> _pageFilterIntensities;
  late Map<int, double> _pageBrightness;
  late Map<int, double> _pageContrast;
  late Map<int, double> _pageSharpness;
  late Map<int, double> _pageDeskewAngles;
  late Map<int, List<Map<String, dynamic>>> _pageEraserStrokes;

  double _eraserRadiusNorm = 0.035;
  List<List<double>>? _activeEraserPoints;

  final Map<int, Uint8List> _cachedBasePreviewRgba = {};
  final Map<int, List<int>> _cachedBasePreviewWH = {};
  final Map<int, ui.Image> _renderedPreviewImages = {};
  int _renderRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _workingPaths = List<String>.from(widget.rawImagePaths);
    _pageFilterSelections = {for (var i = 0; i < widget.rawImagePaths.length; i++) i: widget.initialFilterId};
    _pageFilterIntensities = {for (var i = 0; i < widget.rawImagePaths.length; i++) i: 0.62};
    _pageBrightness = {for (var i = 0; i < widget.rawImagePaths.length; i++) i: 0.0};
    _pageContrast = {for (var i = 0; i < widget.rawImagePaths.length; i++) i: 1.0};
    _pageSharpness = {for (var i = 0; i < widget.rawImagePaths.length; i++) i: 0.60};
    _pageDeskewAngles = {for (var i = 0; i < widget.rawImagePaths.length; i++) i: 0.0};
    _pageEraserStrokes = {for (var i = 0; i < widget.rawImagePaths.length; i++) i: []};
    _renderCurrentPagePreview();
  }

  @override
  void dispose() {
    for (final imgObj in _renderedPreviewImages.values) {
      imgObj.dispose();
    }
    _renderedPreviewImages.clear();
    _cachedBasePreviewRgba.clear();
    super.dispose();
  }

  DocFilterPreset get _currentPreset => kDocFilters.firstWhere((f) => f.id == (_pageFilterSelections[_curPageIndex] ?? 'magic_pro'), orElse: () => kDocFilters[1]);
  double get _currentIntensity => _pageFilterIntensities[_curPageIndex] ?? 0.62;
  double get _currentBrightness => _pageBrightness[_curPageIndex] ?? 0.0;
  double get _currentContrast => _pageContrast[_curPageIndex] ?? 1.0;
  double get _currentSharpness => _pageSharpness[_curPageIndex] ?? 0.60;
  double get _currentTiltAngle => _pageDeskewAngles[_curPageIndex] ?? 0.0;
  List<Map<String, dynamic>> get _currentEraserStrokes => _pageEraserStrokes[_curPageIndex] ?? const [];

  void _disposeOldPreviewSafely(ui.Image? oldImg) {
    if (oldImg == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => oldImg.dispose());
  }

  Future<void> _renderCurrentPagePreview() async {
    final int pageIdx = _curPageIndex;
    final int token = ++_renderRequestToken;
    final String filterId = _pageFilterSelections[pageIdx] ?? 'magic_pro';
    final double intensity = _pageFilterIntensities[pageIdx] ?? 0.62;
    final double brightness = _pageBrightness[pageIdx] ?? 0.0;
    final double contrast = _pageContrast[pageIdx] ?? 1.0;
    final double sharpness = _pageSharpness[pageIdx] ?? 0.60;
    final List<Map<String, dynamic>> strokes = _pageEraserStrokes[pageIdx] ?? const [];

    final bool hasAdjustments = brightness.abs() > 0.01 || (contrast - 1.0).abs() > 0.01 || strokes.isNotEmpty;
    if (filterId == 'original' && !hasAdjustments) {
      final oldImg = _renderedPreviewImages.remove(pageIdx);
      if (mounted) setState(() => _isRenderingPreview = false);
      _disposeOldPreviewSafely(oldImg);
      return;
    }
    if (mounted) setState(() => _isRenderingPreview = true);

    if (!_cachedBasePreviewRgba.containsKey(pageIdx)) {
      final wh = [0, 0];
      final rgba = await ProDocImageProcessor.decodeImageToRgba(_workingPaths[pageIdx], maxDimension: 900, outWidthHeight: wh);
      if (rgba != null) {
        _cachedBasePreviewRgba[pageIdx] = rgba;
        _cachedBasePreviewWH[pageIdx] = wh;
      }
    }
    final baseRgba = _cachedBasePreviewRgba[pageIdx];
    final wh = _cachedBasePreviewWH[pageIdx];
    if (baseRgba == null || wh == null) {
      if (mounted) setState(() => _isRenderingPreview = false);
      return;
    }

    final filteredRgba = await ProDocImageProcessor.applyProFilterToRgba(
      rgba: baseRgba,
      width: wh[0],
      height: wh[1],
      filterId: filterId,
      intensity: intensity,
      brightness: brightness,
      contrast: contrast,
      sharpness: sharpness,
      eraserStrokes: strokes,
    );
    if (!mounted || token != _renderRequestToken) return;

    final uiImg = await ProDocImageProcessor.rgbaToUiImage(filteredRgba, wh[0], wh[1]);
    if (!mounted || token != _renderRequestToken) {
      uiImg?.dispose();
      return;
    }
    final oldImg = _renderedPreviewImages[pageIdx];
    setState(() {
      if (uiImg != null) _renderedPreviewImages[pageIdx] = uiImg;
      _isRenderingPreview = false;
    });
    _disposeOldPreviewSafely(oldImg);
  }

  Future<void> _applyAllPagesSameFilter() async {
    final activeFilter = _pageFilterSelections[_curPageIndex] ?? 'magic_pro';
    final activeIntensity = _currentIntensity;
    final activeBright = _currentBrightness;
    final activeContrast = _currentContrast;
    final activeSharp = _currentSharpness;
    final List<ui.Image> toDispose = [];
    setState(() {
      for (int i = 0; i < _workingPaths.length; i++) {
        _pageFilterSelections[i] = activeFilter;
        _pageFilterIntensities[i] = activeIntensity;
        _pageBrightness[i] = activeBright;
        _pageContrast[i] = activeContrast;
        _pageSharpness[i] = activeSharp;
        if (i != _curPageIndex) {
          final removed = _renderedPreviewImages.remove(i);
          if (removed != null) toDispose.add(removed);
        }
      }
    });
    for (final imgObj in toDispose) {
      _disposeOldPreviewSafely(imgObj);
    }
    _renderCurrentPagePreview();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Applied "${_currentPreset.title}" & adjustments to ALL ${_workingPaths.length} pages!')));
  }

  Future<void> _runAutoStraightenAI() async {
    setState(() => _isSaving = true);
    final curImg = _workingPaths[_curPageIndex];
    final detectedAngle = await AIDeskewEngine.detectSkewAngle(curImg);
    if (detectedAngle.abs() > 0.4) {
      final straightened = await AIDeskewEngine.rotateAndDeskewImage(curImg, -detectedAngle);
      _cachedBasePreviewRgba.remove(_curPageIndex);
      final oldImg = _renderedPreviewImages.remove(_curPageIndex);
      setState(() {
        _workingPaths[_curPageIndex] = straightened;
        _pageDeskewAngles[_curPageIndex] = 0.0;
        _isSaving = false;
      });
      _disposeOldPreviewSafely(oldImg);
      _renderCurrentPagePreview();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✨ AI Straightened by ${detectedAngle.toStringAsFixed(1)}°')));
    } else if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Page is already straight!')));
    }
  }

  Future<void> _rotateCurrentPage90() async {
    setState(() => _isSaving = true);
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!await scansDir.exists()) await scansDir.create(recursive: true);
    final rotatedPath = await ProDocImageProcessor.rotateImage90Fast(_workingPaths[_curPageIndex], '${scansDir.path}/rot_${DateTime.now().millisecondsSinceEpoch}.jpg');
    _cachedBasePreviewRgba.remove(_curPageIndex);
    final oldImg = _renderedPreviewImages.remove(_curPageIndex);
    if (mounted) {
      setState(() {
        _workingPaths[_curPageIndex] = rotatedPath;
        _pageEraserStrokes[_curPageIndex] = [];
        _isSaving = false;
      });
      _disposeOldPreviewSafely(oldImg);
      _renderCurrentPagePreview();
    }
  }

  Future<void> _finishAndExport() async {
    setState(() => _isSaving = true);
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!await scansDir.exists()) await scansDir.create(recursive: true);
    List<String> enhancedPaths = [];
    for (int i = 0; i < _workingPaths.length; i++) {
      String sourceImg = _workingPaths[i];
      final double tilt = _pageDeskewAngles[i] ?? 0.0;
      if (tilt.abs() > 0.5) sourceImg = await AIDeskewEngine.rotateAndDeskewImage(sourceImg, tilt);
      final outPath = '${scansDir.path}/pro_${DateTime.now().millisecondsSinceEpoch}_p$i.jpg';
      enhancedPaths.add(await ProDocImageProcessor.processAndSaveHighRes(
        sourcePath: sourceImg,
        filterId: _pageFilterSelections[i] ?? 'magic_pro',
        intensity: _pageFilterIntensities[i] ?? 0.62,
        outputPath: outPath,
        brightness: _pageBrightness[i] ?? 0.0,
        contrast: _pageContrast[i] ?? 1.0,
        sharpness: _pageSharpness[i] ?? 0.60,
        eraserStrokes: _pageEraserStrokes[i],
      ));
    }
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
      widget.onApplyAndProceed(enhancedPaths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePreset = _currentPreset;
    final curImg = File(_workingPaths[_curPageIndex]);
    final previewUiImg = _renderedPreviewImages[_curPageIndex];
    final wh = _cachedBasePreviewWH[_curPageIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF14161B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14161B),
        foregroundColor: Colors.white,
        title: Text('Page ${_curPageIndex + 1}/${_workingPaths.length} • ${activePreset.title}', style: const TextStyle(fontSize: 14)),
        actions: [
          LabeledIconButton(icon: Icons.compare_rounded, label: 'Original', color: _showOriginalHold ? Colors.amber : Colors.white70, onPressed: () => setState(() => _showOriginalHold = !_showOriginalHold)),
          LabeledIconButton(icon: Icons.done_all_rounded, label: 'Apply All', color: const Color(0xFF81C784), onPressed: _applyAllPagesSameFilter),
          LabeledIconButton(icon: Icons.check_circle_rounded, label: AppLang.tr('save'), color: Colors.greenAccent, iconSize: 23, onPressed: _isSaving ? null : _finishAndExport),
        ],
      ),
      body: _isSaving
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: Colors.greenAccent), SizedBox(height: 12), Text('Saving Ultra-Clarity Document...', style: TextStyle(color: Colors.white70, fontSize: 13))]))
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      _buildTopPill('Straighten AI', Icons.auto_awesome, _activeTopTab == 0, () { setState(() => _activeTopTab = 0); _runAutoStraightenAI(); }),
                      const SizedBox(width: 8),
                      _buildTopPill('Pro Filters', Icons.auto_fix_high_rounded, _activeTopTab == 1, () => setState(() => _activeTopTab = 1)),
                      const SizedBox(width: 8),
                      _buildTopPill('Adjust', Icons.tune_rounded, _activeTopTab == 2, () => setState(() => _activeTopTab = 2)),
                      const SizedBox(width: 8),
                      _buildTopPill('Eraser', Icons.cleaning_services_rounded, _activeTopTab == 3, () => setState(() => _activeTopTab = 3)),
                      const SizedBox(width: 8),
                      _buildTopPill('Tilt & Rotate', Icons.crop_rotate_rounded, _activeTopTab == 4, () => setState(() => _activeTopTab = 4)),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Transform.rotate(
                          angle: _currentTiltAngle * pi / 180,
                          child: LayoutBuilder(
                            builder: (ctx, box) {
                              final double aspect = (wh != null && wh[1] > 0) ? (wh[0] / wh[1]) : 0.72;
                              double dispW = box.maxWidth;
                              double dispH = dispW / aspect;
                              if (dispH > box.maxHeight) {
                                dispH = box.maxHeight;
                                dispW = dispH * aspect;
                              }
                              final Widget docImageWidget = ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: (_showOriginalHold || (activePreset.id == 'original' && previewUiImg == null) || previewUiImg == null)
                                    ? Image.file(curImg, fit: BoxFit.contain)
                                    : RawImage(image: previewUiImg, fit: BoxFit.contain),
                              );

                              if (_activeTopTab != 3) return docImageWidget;

                              return SizedBox(
                                width: dispW,
                                height: dispH,
                                child: GestureDetector(
                                  onPanStart: (d) {
                                    final nx = (d.localPosition.dx / dispW).clamp(0.0, 1.0);
                                    final ny = (d.localPosition.dy / dispH).clamp(0.0, 1.0);
                                    setState(() {
                                      _activeEraserPoints = [[nx, ny]];
                                    });
                                  },
                                  onPanUpdate: (d) {
                                    if (_activeEraserPoints == null) return;
                                    final nx = (d.localPosition.dx / dispW).clamp(0.0, 1.0);
                                    final ny = (d.localPosition.dy / dispH).clamp(0.0, 1.0);
                                    setState(() {
                                      _activeEraserPoints!.add([nx, ny]);
                                    });
                                  },
                                  onPanEnd: (_) {
                                    if (_activeEraserPoints != null && _activeEraserPoints!.isNotEmpty) {
                                      final list = _pageEraserStrokes[_curPageIndex] ?? [];
                                      list.add({'points': _activeEraserPoints!, 'radius': _eraserRadiusNorm});
                                      _pageEraserStrokes[_curPageIndex] = list;
                                      _activeEraserPoints = null;
                                      _renderCurrentPagePreview();
                                    }
                                  },
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      docImageWidget,
                                      if (_activeEraserPoints != null)
                                        CustomPaint(
                                          painter: _LiveEraserStrokePainter(points: _activeEraserPoints!, radiusNorm: _eraserRadiusNorm),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (_isRenderingPreview)
                        Positioned(
                          top: 10,
                          right: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)),
                                SizedBox(width: 6),
                                Text('Enhancing...', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_activeTopTab == 4)
                  Container(
                    color: const Color(0xFF1F2229),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [const Icon(Icons.straighten, color: Colors.white70, size: 18), const SizedBox(width: 8), Text('Tilt Angle: ${_currentTiltAngle.toStringAsFixed(1)}°', style: const TextStyle(color: Colors.white, fontSize: 12)), const Spacer(), LabeledIconButton(icon: Icons.refresh_rounded, label: 'Reset', color: const Color(0xFF81C784), onPressed: () => setState(() => _pageDeskewAngles[_curPageIndex] = 0.0)), LabeledIconButton(icon: Icons.rotate_right_rounded, label: 'Rotate 90°', color: Colors.white, onPressed: _rotateCurrentPage90)]),
                        Slider(value: _currentTiltAngle, min: -30.0, max: 30.0, activeColor: const Color(0xFF81C784), inactiveColor: Colors.grey.shade800, onChanged: (val) => setState(() => _pageDeskewAngles[_curPageIndex] = val)),
                      ],
                    ),
                  )
                else if (_activeTopTab == 3)
                  Container(
                    color: const Color(0xFF1F2229),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cleaning_services_rounded, color: Colors.greenAccent, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Swipe on stains/fingers to erase cleanly', style: TextStyle(color: Colors.white70, fontSize: 11))),
                            LabeledIconButton(
                              icon: Icons.undo_rounded,
                              label: 'Undo',
                              color: Colors.white,
                              onPressed: _currentEraserStrokes.isEmpty
                                  ? null
                                  : () {
                                      setState(() => _pageEraserStrokes[_curPageIndex]!.removeLast());
                                      _renderCurrentPagePreview();
                                    },
                            ),
                            LabeledIconButton(
                              icon: Icons.delete_sweep_rounded,
                              label: 'Clear',
                              color: Colors.redAccent,
                              onPressed: _currentEraserStrokes.isEmpty
                                  ? null
                                  : () {
                                      setState(() => _pageEraserStrokes[_curPageIndex] = []);
                                      _renderCurrentPagePreview();
                                    },
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Brush Size:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            Expanded(
                              child: Slider(
                                value: _eraserRadiusNorm,
                                min: 0.015,
                                max: 0.08,
                                activeColor: const Color(0xFF81C784),
                                inactiveColor: Colors.grey.shade700,
                                onChanged: (v) => setState(() => _eraserRadiusNorm = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else if (_activeTopTab == 2)
                  Container(
                    color: const Color(0xFF1F2229),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Manual Clarity Tuning', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            TextButton.icon(
                              icon: const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF81C784)),
                              label: const Text('Reset Adjust', style: TextStyle(color: Color(0xFF81C784), fontSize: 11)),
                              onPressed: () {
                                setState(() {
                                  _pageBrightness[_curPageIndex] = 0.0;
                                  _pageContrast[_curPageIndex] = 1.0;
                                  _pageSharpness[_curPageIndex] = 0.60;
                                });
                                _renderCurrentPagePreview();
                              },
                            ),
                          ],
                        ),
                        _buildAdjustSliderRow('Brightness', _currentBrightness, -0.35, 0.35, '${(_currentBrightness * 100).round()}', (v) => setState(() => _pageBrightness[_curPageIndex] = v)),
                        _buildAdjustSliderRow('Contrast', _currentContrast, 0.6, 1.8, '${_currentContrast.toStringAsFixed(2)}x', (v) => setState(() => _pageContrast[_curPageIndex] = v)),
                        _buildAdjustSliderRow('Sharpness', _currentSharpness, 0.0, 1.3, '${(_currentSharpness * 100).round()}%', (v) => setState(() => _pageSharpness[_curPageIndex] = v)),
                      ],
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF1F2229),
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [const Text('Filter Strength:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)), Expanded(child: Slider(value: _currentIntensity, min: 0.0, max: 1.0, divisions: 10, activeColor: const Color(0xFF81C784), inactiveColor: Colors.grey.shade700, onChanged: (val) => setState(() => _pageFilterIntensities[_curPageIndex] = val), onChangeEnd: (_) => _renderCurrentPagePreview())), Text('${(_currentIntensity * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))]),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: kDocFilters.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1.65),
                          itemBuilder: (ctx, i) {
                            final f = kDocFilters[i];
                            final isSel = activePreset.id == f.id;
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () { setState(() { _showOriginalHold = false; _pageFilterSelections[_curPageIndex] = f.id; }); _renderCurrentPagePreview(); },
                              child: Container(
                                decoration: BoxDecoration(color: isSel ? const Color(0xFF1E4628) : const Color(0xFF2A2D36), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSel ? const Color(0xFF81C784) : Colors.white12, width: isSel ? 2 : 1)),
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(f.icon, color: isSel ? const Color(0xFF81C784) : Colors.white70, size: 17), const SizedBox(height: 2), Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 9.5, fontWeight: isSel ? FontWeight.bold : FontWeight.w500))]),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                if (_workingPaths.length > 1)
                  Container(
                    height: 68,
                    color: const Color(0xFF14161B),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _workingPaths.length,
                      itemBuilder: (ctx, idx) {
                        final isSelectedPage = _curPageIndex == idx;
                        return GestureDetector(
                          onTap: () { setState(() { _curPageIndex = idx; _showOriginalHold = false; }); _renderCurrentPagePreview(); },
                          child: Container(
                            width: 50,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelectedPage ? const Color(0xFF81C784) : Colors.grey.shade700, width: isSelectedPage ? 2.5 : 1)),
                            child: Stack(children: [Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(File(_workingPaths[idx]), fit: BoxFit.cover, cacheWidth: 140))), Positioned(bottom: 2, left: 2, right: 2, child: Container(padding: const EdgeInsets.symmetric(vertical: 1), decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(4)), child: Text('P${idx + 1}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))))]),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildAdjustSliderRow(String label, double val, double minVal, double maxVal, String displayText, ValueChanged<double> onChanged) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(width: 68, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))),
          Expanded(
            child: Slider(
              value: val.clamp(minVal, maxVal),
              min: minVal,
              max: maxVal,
              activeColor: const Color(0xFF81C784),
              inactiveColor: Colors.grey.shade700,
              onChanged: onChanged,
              onChangeEnd: (_) => _renderCurrentPagePreview(),
            ),
          ),
          SizedBox(width: 42, child: Text(displayText, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildTopPill(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: isSelected ? const Color(0xFFA5D6A7) : const Color(0xFF26282E), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: isSelected ? const Color(0xFF0A3D14) : Colors.white), const SizedBox(width: 4), Text(title, style: TextStyle(color: isSelected ? const Color(0xFF0A3D14) : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 11))])),
    );
  }
}

class _LiveEraserStrokePainter extends CustomPainter {
  final List<List<double>> points;
  final double radiusNorm;
  _LiveEraserStrokePainter({required this.points, required this.radiusNorm});

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = max(4.0, radiusNorm * min(size.width, size.height) * 2.0);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.95)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      canvas.drawCircle(Offset(points[0][0] * size.width, points[0][1] * size.height), strokeWidth / 2, Paint()..color = Colors.white.withOpacity(0.95));
      return;
    }
    final path = Path()..moveTo(points[0][0] * size.width, points[0][1] * size.height);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i][0] * size.width, points[i][1] * size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiveEraserStrokePainter oldDelegate) => true;
}

// 4. DOCUMENT DETAIL SCREEN (MOVE/COPY PAGES BETWEEN DOCS & FOLDERS)
class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doc;
  final List<Map<String, dynamic>> allDocs;
  final List<String> userFolders;
  final Future<String?> Function(String name) onCreateFolder;
  final Function(Map<String, dynamic>) onDocUpdated;
  final Future<void> Function({required String sourceDocId, required List<String> pagePaths, required List<String> origPaths, required List<int> sourceIndicesToRemove, required String actionType, String? targetDocId, String? targetFolder, String? newDocTitle}) onTransferPages;
  final VoidCallback onDelete;
  final Function(String) onExtractText;

  const DocumentDetailScreen({super.key, required this.doc, required this.allDocs, required this.userFolders, required this.onCreateFolder, required this.onDocUpdated, required this.onTransferPages, required this.onDelete, required this.onExtractText});
  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late List<String> _images;
  late List<String> _originalImages;
  late String _title;
  late String _folder;
  bool _isSelectionMode = false;
  final List<int> _selectedIndicesOrder = [];

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.doc['images'] ?? []);
    _originalImages = List<String>.from(widget.doc['originalImages'] ?? widget.doc['images'] ?? []);
    _title = widget.doc['title'] ?? 'Document';
    _folder = widget.doc['category'] ?? 'General';
  }

  void _syncDocChanges() {
    widget.doc['images'] = List<String>.from(_images);
    widget.doc['originalImages'] = List<String>.from(_originalImages);
    widget.doc['pages'] = _images.length;
    widget.doc['category'] = _folder;
    widget.doc['title'] = _title;
    widget.onDocUpdated(widget.doc);
  }

  List<String> get _targetImagesInOrder => (_isSelectionMode && _selectedIndicesOrder.isNotEmpty) ? _selectedIndicesOrder.map((i) => _images[i]).toList() : _images;

  void _togglePageSelection(int idx) {
    setState(() {
      if (_selectedIndicesOrder.contains(idx)) {
        _selectedIndicesOrder.remove(idx);
        if (_selectedIndicesOrder.isEmpty) _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
        _selectedIndicesOrder.add(idx);
      }
    });
  }

  void _renameDoc() {
    final ctrl = TextEditingController(text: _title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton.icon(icon: const Icon(Icons.close, size: 16), label: Text(AppLang.tr('cancel')), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white), icon: const Icon(Icons.save, size: 16), label: Text(AppLang.tr('save')), onPressed: () { Navigator.pop(ctx); setState(() => _title = ctrl.text.trim().isEmpty ? _title : ctrl.text.trim()); _syncDocChanges(); }),
        ],
      ),
    ).whenComplete(() => ctrl.dispose());
  }

  void _changeFolderDialog() {
    final List<String> folders = List<String>.from(widget.userFolders);
    if (!folders.contains(_folder)) folders.add(_folder);
    String chosen = _folder;
    final newFolderCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Move Document to Folder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(value: chosen, decoration: const InputDecoration(labelText: 'Select Folder', border: OutlineInputBorder()), items: folders.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: (v) { if (v != null) setDState(() => chosen = v); }),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: TextField(controller: newFolderCtrl, decoration: const InputDecoration(labelText: 'Or New Folder', border: OutlineInputBorder(), isDense: true))), const SizedBox(width: 8), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white), onPressed: () async { final created = await widget.onCreateFolder(newFolderCtrl.text); if (created != null) setDState(() { if (!folders.contains(created)) folders.add(created); chosen = created; newFolderCtrl.clear(); }); }, child: const Text('Add'))]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr('cancel'))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white), onPressed: () { Navigator.pop(ctx); setState(() => _folder = chosen); _syncDocChanges(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Moved to "$chosen" folder!'))); }, child: const Text('Move')),
          ],
        ),
      ),
    ).whenComplete(() => newFolderCtrl.dispose());
  }

  void _openMoveCopySheet() {
    final List<int> indices = (_isSelectionMode && _selectedIndicesOrder.isNotEmpty) ? List<int>.from(_selectedIndicesOrder) : List<int>.generate(_images.length, (i) => i);
    if (indices.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Transfer ${indices.length} Page(s)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListTile(leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: Icon(Icons.drive_file_move_rounded, color: Colors.green.shade700)), title: const Text('Move This Document to Another Folder'), subtitle: Text('Current folder: $_folder'), onTap: () { Navigator.pop(ctx); _changeFolderDialog(); }),
              ListTile(leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.copy_rounded, color: Colors.blue)), title: const Text('Copy Page(s) into Another Document'), subtitle: const Text('Keep here & add to another document'), onTap: () { Navigator.pop(ctx); _pickTargetDocumentDialog(indices: indices, removeFromSource: false); }),
              ListTile(leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: const Icon(Icons.move_to_inbox_rounded, color: Colors.deepOrange)), title: const Text('Move Page(s) into Another Document'), subtitle: const Text('Remove from here & add to another document'), onTap: () { Navigator.pop(ctx); _pickTargetDocumentDialog(indices: indices, removeFromSource: true); }),
              ListTile(leading: CircleAvatar(backgroundColor: Colors.purple.shade50, child: const Icon(Icons.create_new_folder_rounded, color: Colors.purple)), title: const Text('Send Page(s) to New Doc in Any Folder'), subtitle: const Text('Create a separate doc in another folder'), onTap: () { Navigator.pop(ctx); _sendPagesToNewDocInFolderDialog(indices); }),
            ],
          ),
        ),
      ),
    );
  }

  void _pickTargetDocumentDialog({required List<int> indices, required bool removeFromSource}) {
    final otherDocs = widget.allDocs.where((d) => d['id'].toString() != widget.doc['id'].toString()).toList();
    if (otherDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No other documents available. Try "Send to New Doc in Any Folder"!')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(removeFromSource ? 'Move ${indices.length} Page(s) Into:' : 'Copy ${indices.length} Page(s) Into:', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 260,
          child: ListView.builder(
            itemCount: otherDocs.length,
            itemBuilder: (_, i) {
              final target = otherDocs[i];
              return ListTile(
                leading: Icon(Icons.description_rounded, color: appPrimaryColor.value),
                title: Text(target['title'] ?? 'Doc', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${target['pages']} pages • ${target['category']}'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final pagePaths = indices.map((idx) => _images[idx]).toList();
                  final origPaths = indices.map((idx) => idx < _originalImages.length ? _originalImages[idx] : _images[idx]).toList();
                  await widget.onTransferPages(sourceDocId: widget.doc['id'].toString(), pagePaths: pagePaths, origPaths: origPaths, sourceIndicesToRemove: removeFromSource ? indices : const [], actionType: removeFromSource ? 'move_doc' : 'copy_doc', targetDocId: target['id'].toString());
                  if (!mounted) return;
                  if (removeFromSource) {
                    final sortedDesc = indices.toList()..sort((a, b) => b.compareTo(a));
                    setState(() {
                      for (final r in sortedDesc) {
                        if (r < _images.length) _images.removeAt(r);
                        if (r < _originalImages.length) _originalImages.removeAt(r);
                      }
                      _isSelectionMode = false;
                      _selectedIndicesOrder.clear();
                    });
                    if (_images.isEmpty) {
                      Navigator.pop(context);
                      return;
                    }
                  }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${removeFromSource ? "Moved" : "Copied"} ${pagePaths.length} page(s) to "${target['title']}"!')));
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr('cancel')))],
      ),
    );
  }

  void _sendPagesToNewDocInFolderDialog(List<int> indices) {
    final nameCtrl = TextEditingController(text: '${_title}_Part_${DateFormat('HHmm').format(DateTime.now())}');
    String targetFolder = widget.userFolders.isNotEmpty ? widget.userFolders.first : 'General';
    bool removeFromSource = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('New Doc (${indices.length} Pages)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'New Document Name', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(value: targetFolder, decoration: const InputDecoration(labelText: 'Target Folder', border: OutlineInputBorder()), items: widget.userFolders.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: (v) { if (v != null) targetFolder = v; }),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Remove from current document (Move)', style: TextStyle(fontSize: 12)), value: removeFromSource, onChanged: (v) => setDState(() => removeFromSource = v ?? true)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr('cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final pagePaths = indices.map((idx) => _images[idx]).toList();
                final origPaths = indices.map((idx) => idx < _originalImages.length ? _originalImages[idx] : _images[idx]).toList();
                await widget.onTransferPages(sourceDocId: widget.doc['id'].toString(), pagePaths: pagePaths, origPaths: origPaths, sourceIndicesToRemove: removeFromSource ? indices : const [], actionType: 'new_doc_folder', targetFolder: targetFolder, newDocTitle: nameCtrl.text);
                if (!mounted) return;
                if (removeFromSource) {
                  final sortedDesc = indices.toList()..sort((a, b) => b.compareTo(a));
                  setState(() {
                    for (final r in sortedDesc) {
                      if (r < _images.length) _images.removeAt(r);
                      if (r < _originalImages.length) _originalImages.removeAt(r);
                    }
                    _isSelectionMode = false;
                    _selectedIndicesOrder.clear();
                  });
                  if (_images.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Created new doc in "$targetFolder"!')));
              },
              child: Text(AppLang.tr('save')),
            ),
          ],
        ),
      ),
    ).whenComplete(() => nameCtrl.dispose());
  }

  void _reEditSelectedPages() {
    final List<int> indicesToEdit = (_isSelectionMode && _selectedIndicesOrder.isNotEmpty) ? List<int>.from(_selectedIndicesOrder) : List<int>.generate(_images.length, (i) => i);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanFilterReviewScreen(
          rawImagePaths: indicesToEdit.map((i) => i < _originalImages.length ? _originalImages[i] : _images[i]).toList(),
          onApplyAndProceed: (retouchedPaths) {
            setState(() { for (int k = 0; k < indicesToEdit.length; k++) _images[indicesToEdit[k]] = retouchedPaths[k]; });
            _syncDocChanges();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Retouched Pages Saved!')));
          },
        ),
      ),
    );
  }

  Future<void> _addMorePagesSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add More Pages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFE0F7FA), child: Icon(Icons.photo_library_rounded, color: Color(0xFF00B4D8))), title: const Text('Import from Gallery'), subtitle: const Text('Open phone gallery directly'), onTap: () async { Navigator.pop(ctx); final picked = await ImagePicker().pickMultiImage(); if (picked.isNotEmpty) _appendNewImagesThroughFilter(picked.map((x) => x.path).toList()); }),
              ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.camera_alt_rounded, color: Color(0xFF2E7D32))), title: const Text('Scan from Camera'), subtitle: const Text('Capture new pages'), onTap: () async { Navigator.pop(ctx); try { final res = await DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.base, isGalleryImport: true, pageLimit: 20)).scanDocument(); if (res.images.isNotEmpty) _appendNewImagesThroughFilter(res.images); } catch (e) { debugPrint("Add page err: $e"); } }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _appendNewImagesThroughFilter(List<String> rawPaths) async {
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!await scansDir.exists()) await scansDir.create(recursive: true);
    List<String> copiedRaw = [];
    for (int i = 0; i < rawPaths.length; i++) {
      final f = File(rawPaths[i]);
      if (await f.exists()) {
        final target = '${scansDir.path}/add_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        await f.copy(target);
        copiedRaw.add(target);
      }
    }
    if (!mounted || copiedRaw.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ScanFilterReviewScreen(rawImagePaths: copiedRaw, onApplyAndProceed: (filteredPaths) { setState(() { _images.addAll(filteredPaths); _originalImages.addAll(copiedRaw); }); _syncDocChanges(); })));
  }

  Future<Uint8List> _buildOrderedPdfBytes(List<String> orderedImgs) async {
    final pdf = pw.Document();
    for (final path in orderedImgs) {
      final f = File(path);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(8), build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain))));
      }
    }
    return pdf.save();
  }

  Future<void> _shareOrderedPdf() async {
    final imgs = _targetImagesInOrder;
    if (imgs.isEmpty) return;
    final pdfBytes = await _buildOrderedPdfBytes(imgs);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${_title.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path)], text: '$_title (${imgs.length} Pages PDF)');
  }

  Future<void> _saveOrderedPdfToPhone() async {
    final imgs = _targetImagesInOrder;
    if (imgs.isEmpty) return;
    final res = await PhoneStorageManager.savePdfBytesToPublicDownloads(await _buildOrderedPdfBytes(imgs), _title);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.savedPath != null ? '✅ PDF (${imgs.length} pages) saved to ${res.folderLabel}!' : '❌ Failed to save PDF'), backgroundColor: Colors.green.shade700));
  }

  Future<void> _shareImagesDirectly() async {
    final xFiles = _targetImagesInOrder.map((p) => XFile(p)).toList();
    if (xFiles.isNotEmpty) await Share.shareXFiles(xFiles, text: '$_title Photos (${xFiles.length} Pages)');
  }

  Future<void> _saveJpgToPhone() async {
    final imgs = _targetImagesInOrder;
    if (imgs.isEmpty) return;
    final res = await PhoneStorageManager.saveImagesToPublicGallery(imgs, _title);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${res.count} photo(s) saved to ${res.folderLabel}!'), backgroundColor: Colors.green.shade700));
  }

  void _deleteSelectedPages() {
    if (_selectedIndicesOrder.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pages?'),
        content: Text('Delete ${_selectedIndicesOrder.length} selected page(s)?'),
        actions: [
          TextButton.icon(icon: const Icon(Icons.close, size: 16), label: Text(AppLang.tr('cancel')), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: Text(AppLang.tr('delete')),
            onPressed: () {
              Navigator.pop(ctx);
              final sortedDesc = _selectedIndicesOrder.toList()..sort((a, b) => b.compareTo(a));
              for (var idx in sortedDesc) {
                if (idx >= 0 && idx < _images.length) _images.removeAt(idx);
                if (idx >= 0 && idx < _originalImages.length) _originalImages.removeAt(idx);
              }
              if (_images.isEmpty) {
                widget.onDelete();
                Navigator.pop(context);
              } else {
                setState(() { _isSelectionMode = false; _selectedIndicesOrder.clear(); });
                _syncDocChanges();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _isSelectionMode ? null : _renameDoc,
          child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(_isSelectionMode ? '${_selectedIndicesOrder.length} Selected (In Order)' : _title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15))), if (!_isSelectionMode) ...[const SizedBox(width: 6), const Icon(Icons.edit, size: 14)]]),
        ),
        actions: _isSelectionMode
            ? [
                LabeledIconButton(icon: Icons.select_all_rounded, label: AppLang.tr('select_all'), onPressed: () => setState(() { if (_selectedIndicesOrder.length == _images.length) { _selectedIndicesOrder.clear(); } else { for (int i = 0; i < _images.length; i++) if (!_selectedIndicesOrder.contains(i)) _selectedIndicesOrder.add(i); } })),
                LabeledIconButton(icon: Icons.close_rounded, label: 'Done', onPressed: () => setState(() { _isSelectionMode = false; _selectedIndicesOrder.clear(); })),
              ]
            : [
                LabeledIconButton(icon: Icons.auto_fix_high_rounded, label: 'Edit All', onPressed: _reEditSelectedPages),
                LabeledIconButton(icon: Icons.checklist_rounded, label: 'Select', onPressed: () => setState(() => _isSelectionMode = true)),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(onTap: _changeFolderDialog, child: Row(mainAxisSize: MainAxisSize.min, children: [Text('${_images.length} Pages • Folder: $_folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: appPrimaryColor.value)), const SizedBox(width: 4), Icon(Icons.edit_location_alt_outlined, size: 14, color: appPrimaryColor.value)])),
                      Text(_isSelectionMode ? 'Tap pages in exact order (#1, #2...) for PDF or Move!' : 'Long press any page to select, order, or move', style: TextStyle(fontSize: 10, color: _isSelectionMode ? appPrimaryColor.value : Colors.grey)),
                    ],
                  ),
                ),
                ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, visualDensity: VisualDensity.compact), icon: const Icon(Icons.add_photo_alternate_rounded, size: 16), label: Text(AppLang.tr('add_more'), style: const TextStyle(fontSize: 11)), onPressed: _addMorePagesSheet),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72),
                    itemBuilder: (ctx, idx) {
                      final int orderPos = _selectedIndicesOrder.indexOf(idx);
                      final bool isSelected = orderPos != -1;
                      final file = File(_images[idx]);
                      return GestureDetector(
                        onLongPress: () => _togglePageSelection(idx),
                        onTap: () {
                          if (_isSelectionMode) {
                            _togglePageSelection(idx);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenPhotoViewer(
                                  images: _images,
                                  originalImages: _originalImages,
                                  initialIndex: idx,
                                  title: _title,
                                  onPageReplaced: (pageIdx, newPath) {
                                    setState(() { if (pageIdx >= 0 && pageIdx < _images.length) _images[pageIdx] = newPath; });
                                    _syncDocChanges();
                                  },
                                  onExtractText: widget.onExtractText,
                                  onReEditPage: (pageIdx) {
                                    final srcPath = pageIdx < _originalImages.length ? _originalImages[pageIdx] : _images[pageIdx];
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ScanFilterReviewScreen(rawImagePaths: [srcPath], onApplyAndProceed: (retouched) { setState(() => _images[pageIdx] = retouched.first); _syncDocChanges(); })));
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? appPrimaryColor.value : Colors.grey.shade300, width: isSelected ? 3 : 1)),
                          child: Stack(
                            children: [
                              Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: file.existsSync() ? Image.file(file, fit: BoxFit.cover, cacheWidth: 260) : Container(color: Colors.grey.shade200))),
                              Positioned(top: 4, left: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)), child: Text('P${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
                              if (_isSelectionMode) Positioned(top: 4, right: 4, child: isSelected ? CircleAvatar(radius: 12, backgroundColor: appPrimaryColor.value, child: Text('#${orderPos + 1}', style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))) : const Icon(Icons.circle_outlined, color: Colors.white, size: 24)),
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
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: SafeArea(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                LabeledIconButton(icon: Icons.drive_file_move_rounded, label: AppLang.tr('move_copy'), color: Colors.green.shade700, onPressed: _openMoveCopySheet),
                LabeledIconButton(icon: Icons.picture_as_pdf_rounded, label: AppLang.tr('share_pdf'), color: appPrimaryColor.value, onPressed: _shareOrderedPdf),
                LabeledIconButton(icon: Icons.download_for_offline_rounded, label: AppLang.tr('save_pdf'), color: Colors.redAccent, onPressed: _saveOrderedPdfToPhone),
                LabeledIconButton(icon: Icons.image_rounded, label: AppLang.tr('share_jpg'), color: Colors.indigo, onPressed: _shareImagesDirectly),
                LabeledIconButton(icon: Icons.save_alt_rounded, label: AppLang.tr('save_jpg'), color: Colors.teal, onPressed: _saveJpgToPhone),
                LabeledIconButton(icon: Icons.compress_rounded, label: AppLang.tr('compress'), color: Colors.orange.shade800, onPressed: () { final ordered = _targetImagesInOrder; if (ordered.isNotEmpty) ProCompressionEngine.showCompressorDialog(context: context, orderedPaths: ordered, title: _title); }),
                LabeledIconButton(icon: Icons.auto_fix_high_rounded, label: AppLang.tr('edit_doc'), color: Colors.purple, onPressed: _reEditSelectedPages),
                if (_isSelectionMode && _selectedIndicesOrder.isNotEmpty) LabeledIconButton(icon: Icons.delete_rounded, label: AppLang.tr('delete'), color: Colors.red, onPressed: _deleteSelectedPages),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 5. FULL SCREEN PHOTO VIEWER
class FullScreenPhotoViewer extends StatefulWidget {
  final List<String> images;
  final List<String> originalImages;
  final int initialIndex;
  final String title;
  final Function(int index, String newPath) onPageReplaced;
  final Function(String) onExtractText;
  final Function(int pageIndex) onReEditPage;

  const FullScreenPhotoViewer({super.key, required this.images, required this.originalImages, required this.initialIndex, required this.title, required this.onPageReplaced, required this.onExtractText, required this.onReEditPage});
  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late PageController _pageCtrl;
  late List<String> _localImages;
  late int _curPage;
  bool _isRotating = false;

  @override
  void initState() {
    super.initState();
    _curPage = widget.initialIndex;
    _localImages = List<String>.from(widget.images);
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _resetImage() {
    if (_curPage < widget.originalImages.length) {
      final origPath = widget.originalImages[_curPage];
      setState(() => _localImages[_curPage] = origPath);
      widget.onPageReplaced(_curPage, origPath);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Restored Original Camera Photo.')));
    }
  }

  Future<void> _rotatePage() async {
    if (_isRotating) return;
    setState(() => _isRotating = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory('${appDir.path}/scans');
      if (!await scansDir.exists()) await scansDir.create(recursive: true);
      final rotatedPath = await ProDocImageProcessor.rotateImage90Fast(_localImages[_curPage], '${scansDir.path}/rot_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (mounted) {
        setState(() => _localImages[_curPage] = rotatedPath);
        widget.onPageReplaced(_curPage, rotatedPath);
      }
    } finally {
      if (mounted) setState(() => _isRotating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.title} (${_curPage + 1}/${_localImages.length})', style: const TextStyle(fontSize: 13)),
        actions: [
          LabeledIconButton(icon: Icons.auto_fix_high_rounded, label: 'Edit', color: Colors.greenAccent, onPressed: () { Navigator.pop(context); widget.onReEditPage(_curPage); }),
          LabeledIconButton(icon: Icons.rotate_right_rounded, label: 'Rotate', color: Colors.white, onPressed: _isRotating ? null : _rotatePage),
          LabeledIconButton(icon: Icons.restore_rounded, label: 'Reset', color: Colors.orangeAccent, onPressed: _resetImage),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _localImages.length,
            onPageChanged: (i) => setState(() => _curPage = i),
            itemBuilder: (ctx, i) {
              final file = File(_localImages[i]);
              return InteractiveViewer(panEnabled: true, minScale: 0.8, maxScale: 5.0, child: Center(child: file.existsSync() ? Image.file(file, fit: BoxFit.contain) : const Text('Image file not found', style: TextStyle(color: Colors.white))));
            },
          ),
          if (_isRotating) const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              LabeledIconButton(icon: Icons.auto_awesome, label: 'OCR Text', color: Colors.white, onPressed: () { if (_localImages.isNotEmpty) widget.onExtractText(_localImages[_curPage]); }),
              LabeledIconButton(icon: Icons.compress_rounded, label: AppLang.tr('compress'), color: Colors.amberAccent, onPressed: () { if (_localImages.isNotEmpty) ProCompressionEngine.showCompressorDialog(context: context, orderedPaths: [_localImages[_curPage]], title: '${widget.title}_p${_curPage + 1}'); }),
              LabeledIconButton(icon: Icons.save_alt_rounded, label: AppLang.tr('save_jpg'), color: Colors.tealAccent, onPressed: () async { if (_localImages.isNotEmpty) { final res = await PhoneStorageManager.saveImagesToPublicGallery([_localImages[_curPage]], widget.title); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${res.count} JPG saved to ${res.folderLabel}!'))); } }),
              LabeledIconButton(icon: Icons.share_rounded, label: AppLang.tr('share_jpg'), color: Colors.white, onPressed: () { if (_localImages.isNotEmpty) Share.shareXFiles([XFile(_localImages[_curPage])]); }),
            ],
          ),
        ),
      ),
    );
  }
}
// ==================== PART 3 END ====================
// ==================== PART 4 START ====================
// 6. PASSPORT PHOTO STUDIO
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

  Future<void> _pickPhotoFromGallery() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null && mounted) setState(() => _photoPath = x.path);
  }

  Future<void> _scanPhotoCamera() async {
    final res = await DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.base, isGalleryImport: true, pageLimit: 1)).scanDocument();
    if (res.images.isNotEmpty && mounted) setState(() => _photoPath = res.images.first);
  }

  Future<void> _exportPassportSheet() async {
    if (_photoPath == null) return;
    final pdf = pw.Document();
    final passImg = pw.MemoryImage(await File(_photoPath!).readAsBytes());
    double w = 110, h = 145;
    if (_presetSize.contains('US Visa')) { w = 140; h = 140; } else if (_presetSize.contains('PAN Card')) { w = 95; h = 130; } else if (_presetSize.contains('Stamp')) { w = 80; h = 100; }
    PdfColor bgColor = PdfColors.white;
    if (_bgChoice == 'Studio Blue') bgColor = PdfColor.fromInt(0xFFBBDEFB);
    if (_bgChoice == 'Light Grey') bgColor = PdfColor.fromInt(0xFFECEFF1);

    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Container(padding: const pw.EdgeInsets.all(24), child: pw.Wrap(spacing: 16, runSpacing: 20, children: List.generate(_copies, (_) => pw.Container(width: w, height: h, color: bgColor, padding: const pw.EdgeInsets.all(2), child: pw.Container(decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 1)), child: pw.Image(passImg, fit: pw.BoxFit.cover))))))));
    final file = File("${(await getTemporaryDirectory()).path}/Passport_Sheet_${_copies}_Prints.pdf");
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
            Center(child: _photoPath != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_photoPath!), height: 180, width: 140, fit: BoxFit.cover)) : Container(height: 180, width: 140, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.portrait, size: 60, color: Colors.grey))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [ElevatedButton.icon(icon: const Icon(Icons.photo_library_rounded), label: const Text('From Gallery'), onPressed: _pickPhotoFromGallery), const SizedBox(width: 10), ElevatedButton.icon(icon: const Icon(Icons.camera_alt_rounded), label: const Text('Camera Scan'), onPressed: _scanPhotoCamera)]),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(value: _presetSize, decoration: const InputDecoration(labelText: 'Standard Photo Size', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'Indian Passport (3.5x4.5 cm)', child: Text('Indian Passport (3.5x4.5 cm)')), DropdownMenuItem(value: 'PAN Card (2.5x3.5 cm)', child: Text('PAN Card (2.5x3.5 cm)')), DropdownMenuItem(value: 'US Visa / OCI (2x2 inch)', child: Text('US Visa / OCI (2x2 inch)')), DropdownMenuItem(value: 'Stamp Size (2x2.5 cm)', child: Text('Stamp Size (2x2.5 cm)'))], onChanged: (v) { if (v != null) setState(() => _presetSize = v); }),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: _bgChoice, decoration: const InputDecoration(labelText: 'Background Color', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'White', child: Text('Pure White')), DropdownMenuItem(value: 'Studio Blue', child: Text('Studio Light Blue')), DropdownMenuItem(value: 'Light Grey', child: Text('Light Grey'))], onChanged: (v) { if (v != null) setState(() => _bgChoice = v); }),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Number of Copies on A4:', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 6),
            SegmentedButton<int>(segments: const [ButtonSegment(value: 4, label: Text('4')), ButtonSegment(value: 8, label: Text('8')), ButtonSegment(value: 16, label: Text('16')), ButtonSegment(value: 32, label: Text('32'))], selected: {_copies}, onSelectionChanged: (s) => setState(() => _copies = s.first)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white), icon: const Icon(Icons.picture_as_pdf), label: const Text('Export Printable A4 Sheet PDF'), onPressed: _photoPath == null ? null : _exportPassportSheet)),
          ],
        ),
      ),
    );
  }
}

// 7. DIGITAL SIGNATURE
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

    ui.Picture? pic;
    ui.Image? imgUi;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
      canvas.translate(-minX, -minY);
      final paint = Paint()..color = _inkColor..strokeWidth = _strokeWidth..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      for (var stroke in _strokes) {
        for (int i = 0; i < stroke.length - 1; i++) {
          canvas.drawLine(stroke[i], stroke[i + 1], paint);
        }
      }
      pic = recorder.endRecording();
      imgUi = await pic.toImage(width.toInt(), height.toInt());
      final data = await imgUi.toByteData(format: ui.ImageByteFormat.png);
      if (data != null) {
        final file = File("${(await getTemporaryDirectory()).path}/Signature_${DateTime.now().millisecondsSinceEpoch}.png");
        await file.writeAsBytes(data.buffer.asUint8List());
        await Share.shareXFiles([XFile(file.path)], text: 'My Transparent Signature');
      }
    } finally {
      imgUi?.dispose();
      pic?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Digital Signature'), actions: [LabeledIconButton(icon: Icons.undo, label: 'Undo', onPressed: () { if (_strokes.isNotEmpty) setState(() => _strokes.removeLast()); }), LabeledIconButton(icon: Icons.clear_all, label: 'Clear', onPressed: () => setState(() => _strokes.clear()))]),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Text('Ink: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                ...[Colors.black, const Color(0xFF0D47A1), const Color(0xFFB71C1C), const Color(0xFF1B5E20)].map((c) => GestureDetector(onTap: () => setState(() => _inkColor = c), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: 26, height: 26, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _inkColor == c ? Colors.amber : Colors.transparent, width: 2))))),
                const Spacer(),
                const Text('Size: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                Slider(value: _strokeWidth, min: 1.5, max: 8.0, onChanged: (v) => setState(() => _strokeWidth = v)),
              ],
            ),
          ),
          Expanded(child: GestureDetector(onPanStart: (d) => setState(() => _strokes.add([d.localPosition])), onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)), child: CustomPaint(painter: _SignPainter(_strokes, _inkColor, _strokeWidth), size: Size.infinite))),
          Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white), icon: const Icon(Icons.download_rounded), label: const Text('Export Transparent PNG Sign'), onPressed: _strokes.isEmpty ? null : _exportSignaturePng))),
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
    final paint = Paint()..color = color..strokeWidth = strokeWidth..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    for (var stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 8. GST TAX INVOICE MAKER
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
  final List<Map<String, dynamic>> _items = [{'name': 'Professional Consulting', 'price': 1200.0, 'qty': 1}];

  @override
  void dispose() {
    _sellerCtrl.dispose();
    _clientCtrl.dispose();
    _invNumCtrl.dispose();
    _itemCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportInvoicePdf() async {
    final pdf = pw.Document();
    double subtotal = _items.fold(0.0, (s, i) => s + ((i['price'] as double) * (i['qty'] as int)));
    double gstAmount = subtotal * _gstRate;
    double grandTotal = subtotal + gstAmount;
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)), pw.Text('Invoice #: ${_invNumCtrl.text}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
              pw.SizedBox(height: 6),
              pw.Text('Seller: ${_sellerCtrl.text}'),
              pw.Text('Billed To: ${_clientCtrl.text}'),
              pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
              pw.Divider(thickness: 1.5, color: PdfColors.green800),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(headers: ['Item / Service', 'Qty', 'Rate (INR)', 'Total (INR)'], data: _items.map((it) => [it['name'], '${it['qty']}', '${it['price']}', '${(it['price'] * it['qty']).toStringAsFixed(2)}']).toList()),
              pw.SizedBox(height: 16),
              pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [pw.Text('Subtotal: INR ${subtotal.toStringAsFixed(2)}'), pw.Text('GST (${(_gstRate * 100).toInt()}%): INR ${gstAmount.toStringAsFixed(2)}'), pw.Divider(), pw.Text('Grand Total: INR ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800))])),
            ],
          ),
        ),
      ),
    );
    final file = File("${(await getTemporaryDirectory()).path}/Tax_Invoice.pdf");
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
                LabeledIconButton(icon: Icons.add_circle, label: 'Add Item', color: Colors.green, iconSize: 30, onPressed: () { if (_itemCtrl.text.isNotEmpty && _priceCtrl.text.isNotEmpty) { setState(() { _items.add({'name': _itemCtrl.text.trim(), 'qty': int.tryParse(_qtyCtrl.text.trim()) ?? 1, 'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0}); _itemCtrl.clear(); _priceCtrl.clear(); }); } }),
              ],
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('GST Slab Rate:'), DropdownButton<double>(value: _gstRate, items: const [DropdownMenuItem(value: 0.0, child: Text('0% Exempt')), DropdownMenuItem(value: 0.05, child: Text('5% GST')), DropdownMenuItem(value: 0.12, child: Text('12% GST')), DropdownMenuItem(value: 0.18, child: Text('18% Standard')), DropdownMenuItem(value: 0.28, child: Text('28% Luxury'))], onChanged: (v) { if (v != null) setState(() => _gstRate = v); })]),
            const Divider(),
            ..._items.map((it) => ListTile(title: Text(it['name']), subtitle: Text('Qty: ${it['qty']} × INR ${it['price']}'), trailing: Text('INR ${(it['qty'] * it['price']).toStringAsFixed(2)}'))),
            const SizedBox(height: 20),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)), icon: const Icon(Icons.picture_as_pdf), label: const Text('Export Official Tax Invoice PDF'), onPressed: _items.isEmpty ? null : _exportInvoicePdf),
          ],
        ),
      ),
    );
  }
}

// 9. RESUME / CV BUILDER
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

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _summary.dispose();
    _experience.dispose();
    _education.dispose();
    _skills.dispose();
    super.dispose();
  }

  Future<void> _exportCv() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Padding(padding: const pw.EdgeInsets.all(32), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(_name.text, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)), pw.Text(_contact.text, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)), pw.Divider(thickness: 1.5, color: PdfColors.green800), pw.SizedBox(height: 8), pw.Text('PROFESSIONAL SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)), pw.Text(_summary.text, style: const pw.TextStyle(fontSize: 10)), pw.SizedBox(height: 12), pw.Text('WORK EXPERIENCE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)), pw.Text(_experience.text, style: const pw.TextStyle(fontSize: 10)), pw.SizedBox(height: 12), pw.Text('EDUCATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)), pw.Text(_education.text, style: const pw.TextStyle(fontSize: 10)), pw.SizedBox(height: 12), pw.Text('KEY SKILLS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)), pw.Text(_skills.text, style: const pw.TextStyle(fontSize: 10))]))));
    final file = File("${(await getTemporaryDirectory()).path}/Resume_${_name.text.replaceAll(' ', '_')}.pdf");
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
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)), icon: const Icon(Icons.picture_as_pdf), label: const Text('Generate Resume PDF'), onPressed: _exportCv),
          ],
        ),
      ),
    );
  }
}

// 10. POWERPOINT / SLIDES MAKER
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
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4.landscape, build: (_) => pw.Container(padding: const pw.EdgeInsets.all(36), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(s['title'] ?? '', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)), pw.Text('Slide ${i + 1} of ${_slides.length}', style: const pw.TextStyle(color: PdfColors.grey600))]), pw.Divider(thickness: 2, color: PdfColors.green800), pw.SizedBox(height: 20), pw.Text(s['content'] ?? '', style: const pw.TextStyle(fontSize: 18, lineSpacing: 4))]))));
    }
    final file = File("${(await getTemporaryDirectory()).path}/Presentation_Slides.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Presentation Slides');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Slides Maker'), actions: [LabeledIconButton(icon: Icons.share, label: 'Share PDF', onPressed: _exportDeck)]),
      body: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _slides.length, itemBuilder: (ctx, i) => Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [TextFormField(initialValue: _slides[i]['title'], decoration: const InputDecoration(labelText: 'Slide Title'), onChanged: (v) => _slides[i]['title'] = v), TextFormField(initialValue: _slides[i]['content'], maxLines: 3, decoration: const InputDecoration(labelText: 'Bullets / Points'), onChanged: (v) => _slides[i]['content'] = v)])))),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, onPressed: () => setState(() => _slides.add({'title': 'New Slide', 'content': '• Point 1\n• Point 2'})), icon: const Icon(Icons.add), label: const Text('Add Slide')),
    );
  }
}

// 11. FORMAL LETTER TEMPLATES
class LetterTemplatesScreen extends StatefulWidget {
  const LetterTemplatesScreen({super.key});
  @override
  State<LetterTemplatesScreen> createState() => _LetterTemplatesScreenState();
}

class _LetterTemplatesScreenState extends State<LetterTemplatesScreen> {
  final _ctrl = TextEditingController(text: "To,\nThe Branch Manager,\nSubject: Application for New Cheque Book\n\nRespected Sir/Madam,\nI hold a savings account in your branch (Account No: XXXXXXXX). I kindly request you to issue a new cheque book for my account.\n\nThanking You,\nYours Sincerely,\n[Your Name]");

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _exportLetter() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Padding(padding: const pw.EdgeInsets.all(36), child: pw.Text(_ctrl.text, style: const pw.TextStyle(fontSize: 14, lineSpacing: 4)))));
    final file = File("${(await getTemporaryDirectory()).path}/Formal_Letter.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Formal Letter PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Letter Maker'), actions: [LabeledIconButton(icon: Icons.share, label: 'Share PDF', onPressed: _exportLetter)]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ActionChip(label: const Text('Leave Letter'), onPressed: () => setState(() => _ctrl.text = "To,\nThe HR Manager,\nSubject: Leave Application\n\nRespected Sir/Madam,\nI am writing to formally request 3 days of leave from [Start Date] to [End Date] due to urgent personal reasons.\n\nThank you.\nSincerely,\n[Your Name]")),
                ActionChip(label: const Text('Resignation'), onPressed: () => setState(() => _ctrl.text = "To,\nThe Management,\nSubject: Notice of Resignation\n\nPlease accept this letter as formal notification that I am resigning from my position as [Designation]. My last working day will be [Date].\n\nRegards,\n[Your Name]")),
                ActionChip(label: const Text('Bank Manager'), onPressed: () => setState(() => _ctrl.text = "To,\nThe Branch Manager,\nSubject: Request to Update Phone Number\n\nRespected Sir,\nKindly update my mobile number [New Number] in my bank account [Account No].\n\nThanking you,\n[Your Name]")),
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

// 12. TXT & NOTES STUDIO
class TxtEditorNotesScreen extends StatefulWidget {
  const TxtEditorNotesScreen({super.key});
  @override
  State<TxtEditorNotesScreen> createState() => _TxtEditorNotesScreenState();
}

class _TxtEditorNotesScreenState extends State<TxtEditorNotesScreen> {
  final _titleCtrl = TextEditingController(text: 'Quick Note');
  final _bodyCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportTxt() async {
    final file = File("${(await getTemporaryDirectory()).path}/${_titleCtrl.text.replaceAll(' ', '_')}.txt");
    await file.writeAsString(_bodyCtrl.text);
    await Share.shareXFiles([XFile(file.path)], text: 'Exported Note');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes & TXT Studio'), actions: [LabeledIconButton(icon: Icons.share, label: 'Share TXT', onPressed: _exportTxt)]),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())), const SizedBox(height: 10), Expanded(child: TextField(controller: _bodyCtrl, maxLines: null, expands: true, decoration: const InputDecoration(hintText: 'Start writing notes...', border: OutlineInputBorder())))])),
    );
  }
}

// 13. PDF MERGE STUDIO
class PdfStudioScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedDocs;
  const PdfStudioScreen({super.key, required this.savedDocs});
  @override
  State<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends State<PdfStudioScreen> {
  final List<String> _selectedIdsOrder = [];
  bool _isMerging = false;

  Future<void> _mergeDocs({required bool saveToPhone}) async {
    if (_selectedIdsOrder.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least 2 documents to merge!')));
      return;
    }
    setState(() => _isMerging = true);
    try {
      final pdf = pw.Document();
      for (var id in _selectedIdsOrder) {
        final doc = widget.savedDocs.firstWhere((d) => d['id'] == id);
        for (var p in (doc['images'] as List)) {
          final f = File(p);
          if (await f.exists()) {
            final bytes = await f.readAsBytes();
            pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain))));
          }
        }
      }
      final pdfBytes = await pdf.save();
      if (saveToPhone) {
        final res = await PhoneStorageManager.savePdfBytesToPublicDownloads(pdfBytes, 'Merged_${_selectedIdsOrder.length}_Docs');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.savedPath != null ? '✅ Merged PDF saved to ${res.folderLabel}!' : '❌ Failed to save')));
      } else {
        final file = File("${(await getTemporaryDirectory()).path}/Merged_${DateTime.now().millisecondsSinceEpoch}.pdf");
        await file.writeAsBytes(pdfBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Merged PDF Document');
      }
    } finally {
      if (mounted) setState(() => _isMerging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge Documents (Ordered)')),
      body: Stack(
        children: [
          ListView.builder(
            itemCount: widget.savedDocs.length,
            itemBuilder: (ctx, i) {
              final doc = widget.savedDocs[i];
              final orderIdx = _selectedIdsOrder.indexOf(doc['id']);
              final isSel = orderIdx != -1;
              return CheckboxListTile(
                value: isSel,
                secondary: isSel ? CircleAvatar(radius: 13, backgroundColor: appPrimaryColor.value, child: Text('#${orderIdx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))) : null,
                title: Text(doc['title']),
                subtitle: Text('${doc['pages']} pages'),
                onChanged: (v) => setState(() => v == true ? _selectedIdsOrder.add(doc['id']) : _selectedIdsOrder.remove(doc['id'])),
              );
            },
          ),
          if (_isMerging) const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)), icon: const Icon(Icons.download_for_offline_rounded), label: Text('Save PDF (${_selectedIdsOrder.length})'), onPressed: _isMerging ? null : () => _mergeDocs(saveToPhone: true))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)), icon: const Icon(Icons.picture_as_pdf), label: Text('Share PDF (${_selectedIdsOrder.length})'), onPressed: _isMerging ? null : () => _mergeDocs(saveToPhone: false))),
            ],
          ),
        ),
      ),
    );
  }
}

// 14. WATERMARK STUDIO
class WatermarkToolScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedDocs;
  const WatermarkToolScreen({super.key, required this.savedDocs});
  @override
  State<WatermarkToolScreen> createState() => _WatermarkToolScreenState();
}

class _WatermarkToolScreenState extends State<WatermarkToolScreen> {
  final _wmCtrl = TextEditingController(text: 'CONFIDENTIAL');
  String? _selectedDocId;

  @override
  void dispose() {
    _wmCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportWatermarkedPdf() async {
    if (_selectedDocId == null) return;
    final doc = widget.savedDocs.firstWhere((d) => d['id'] == _selectedDocId);
    final pdf = pw.Document();
    for (var path in (doc['images'] as List)) {
      final f = File(path);
      if (await f.exists()) {
        final imgMem = pw.MemoryImage(await f.readAsBytes());
        pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Stack(children: [pw.Center(child: pw.Image(imgMem, fit: pw.BoxFit.contain)), pw.Center(child: pw.Transform.rotate(angle: -0.6, child: pw.Text(_wmCtrl.text, style: pw.TextStyle(fontSize: 48, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0x35000000)))))])));
      }
    }
    final file = File("${(await getTemporaryDirectory()).path}/${doc['title']}_Watermarked.pdf");
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
            DropdownButtonFormField<String>(value: _selectedDocId, hint: const Text('Choose Document'), items: widget.savedDocs.map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text(d['title']))).toList(), onChanged: (v) => setState(() => _selectedDocId = v)),
            const SizedBox(height: 12),
            TextField(controller: _wmCtrl, decoration: const InputDecoration(labelText: 'Watermark Stamp Text', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)), icon: const Icon(Icons.branding_watermark_outlined), label: const Text('Apply Stamp & Share PDF'), onPressed: _selectedDocId == null ? null : _exportWatermarkedPdf),
          ],
        ),
      ),
    );
  }
}

// 15. UNIVERSAL PHOTO ROTATE
class UniversalImageToolScreen extends StatefulWidget {
  const UniversalImageToolScreen({super.key});
  @override
  State<UniversalImageToolScreen> createState() => _UniversalImageToolScreenState();
}

class _UniversalImageToolScreenState extends State<UniversalImageToolScreen> {
  String? _imgPath;
  bool _isRotating = false;

  Future<void> _pickImageGallery() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null && mounted) setState(() => _imgPath = x.path);
  }

  Future<void> _pickImageCamera() async {
    final res = await DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.base, isGalleryImport: true, pageLimit: 1)).scanDocument();
    if (res.images.isNotEmpty && mounted) setState(() => _imgPath = res.images.first);
  }

  Future<void> _rotate90() async {
    if (_imgPath == null || _isRotating) return;
    setState(() => _isRotating = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final rotatedPath = await ProDocImageProcessor.rotateImage90Fast(_imgPath!, '${appDir.path}/rot_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (mounted) setState(() => _imgPath = rotatedPath);
    } finally {
      if (mounted) setState(() => _isRotating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Rotate Studio'),
        actions: [
          if (_imgPath != null) LabeledIconButton(icon: Icons.rotate_right, label: 'Rotate 90°', onPressed: _isRotating ? null : _rotate90),
          if (_imgPath != null) LabeledIconButton(icon: Icons.save_alt_rounded, label: AppLang.tr('save_jpg'), onPressed: () async { final res = await PhoneStorageManager.saveImagesToPublicGallery([_imgPath!], 'Rotated_Photo'); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${res.count} photo saved to ${res.folderLabel}!'))); }),
          if (_imgPath != null) LabeledIconButton(icon: Icons.share, label: 'Share', onPressed: () => Share.shareXFiles([XFile(_imgPath!)])),
        ],
      ),
      body: Stack(
        children: [
          Center(child: _imgPath == null ? Column(mainAxisSize: MainAxisSize.min, children: [ElevatedButton.icon(icon: const Icon(Icons.photo_library_rounded), label: const Text('Select Photo from Gallery'), onPressed: _pickImageGallery), const SizedBox(height: 12), ElevatedButton.icon(icon: const Icon(Icons.camera_alt_rounded), label: const Text('Scan Photo from Camera'), onPressed: _pickImageCamera)]) : Image.file(File(_imgPath!))),
          if (_isRotating) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

// 16. QR & BARCODE GENERATOR STUDIO
class QrBarcodeStudioScreen extends StatefulWidget {
  const QrBarcodeStudioScreen({super.key});
  @override
  State<QrBarcodeStudioScreen> createState() => _QrBarcodeStudioScreenState();
}

class _QrBarcodeStudioScreenState extends State<QrBarcodeStudioScreen> {
  final _qrTextCtrl = TextEditingController(text: 'https://bharatdocscanner.app');

  @override
  void dispose() {
    _qrTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _shareQrCode() async {
    final text = _qrTextCtrl.text.trim();
    if (text.isEmpty) return;
    await Share.share('QR Data: $text');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR & Barcode Studio')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _qrTextCtrl, decoration: const InputDecoration(labelText: 'Enter Text / URL for QR', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)), child: const Icon(Icons.qr_code_2_rounded, size: 160, color: Colors.black87)),
            const SizedBox(height: 20),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)), icon: const Icon(Icons.share), label: const Text('Share QR Data'), onPressed: _shareQrCode),
          ],
        ),
      ),
    );
  }
}
// ==================== PART 4 END ====================
