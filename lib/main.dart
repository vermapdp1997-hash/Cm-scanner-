import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

// ============================================================================
// 1. PRO-GRADE FILTER MODELS & HIGH-QUALITY DOCUMENT IMAGE ENGINE
// ============================================================================

class DocFilterOption {
  final String id;
  final String name;
  final IconData icon;
  final double defaultIntensity;

  const DocFilterOption({
    required this.id,
    required this.name,
    required this.icon,
    this.defaultIntensity = 0.62,
  });
}

const List<DocFilterOption> kDocFilters = [
  DocFilterOption(
    id: 'original',
    name: 'Original',
    icon: Icons.image_outlined,
    defaultIntensity: 0.0,
  ),
  DocFilterOption(
    id: 'magic_pro',
    name: 'Magic Color',
    icon: Icons.auto_fix_high_rounded,
    defaultIntensity: 0.62,
  ),
  DocFilterOption(
    id: 'auto_pro',
    name: 'Auto AI',
    icon: Icons.auto_awesome_rounded,
    defaultIntensity: 0.58,
  ),
  DocFilterOption(
    id: 'lighten_pro',
    name: 'Lighten',
    icon: Icons.wb_sunny_outlined,
    defaultIntensity: 0.60,
  ),
  DocFilterOption(
    id: 'super_bw',
    name: 'B&W Pro',
    icon: Icons.contrast_rounded,
    defaultIntensity: 0.65,
  ),
  DocFilterOption(
    id: 'dark_ink',
    name: 'Dark Ink',
    icon: Icons.edit_note_rounded,
    defaultIntensity: 0.64,
  ),
  DocFilterOption(
    id: 'ocv_crisp',
    name: 'Crisp Clear',
    icon: Icons.tune_rounded,
    defaultIntensity: 0.66,
  ),
  DocFilterOption(
    id: 'vivid_color',
    name: 'Vivid Color',
    icon: Icons.palette_outlined,
    defaultIntensity: 0.56,
  ),
];

class ProDocImageProcessor {
  static Future<({Uint8List rgba, int width, int height})?> decodeImageForPreview(
    String imagePath, {
    int maxDimension = 900,
  }) async {
    return Isolate.run(() {
      final File f = File(imagePath);
      if (!f.existsSync()) return null;
      final Uint8List bytes = f.readAsBytesSync();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      decoded = img.bakeOrientation(decoded);

      if (decoded.width > maxDimension || decoded.height > maxDimension) {
        if (decoded.width >= decoded.height) {
          decoded = img.copyResize(
            decoded,
            width: maxDimension,
            interpolation: img.Interpolation.linear,
          );
        } else {
          decoded = img.copyResize(
            decoded,
            height: maxDimension,
            interpolation: img.Interpolation.linear,
          );
        }
      }

      final img.Image rgbaImg = decoded.convert(numChannels: 4);
      final Uint8List rgba = rgbaImg.getBytes(order: img.ChannelOrder.rgba);
      return (rgba: rgba, width: rgbaImg.width, height: rgbaImg.height);
    });
  }

  static Future<Uint8List> processPreviewRgba(
    Uint8List rawRgba,
    int width,
    int height,
    String filterId,
    double intensity,
  ) async {
    return Isolate.run(() {
      return _processRgbaIsolate(rawRgba, width, height, filterId, intensity);
    });
  }

  static Future<String> processAndSaveHighRes({
    required String inputPath,
    required String outputPath,
    required String filterId,
    double intensity = 0.62,
    double tiltDegrees = 0.0,
    int maxDimension = 2400,
    int quality = 94,
  }) async {
    return Isolate.run(() {
      final File f = File(inputPath);
      if (!f.existsSync()) return inputPath;
      final Uint8List bytes = f.readAsBytesSync();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return inputPath;
      decoded = img.bakeOrientation(decoded);

      if (decoded.width > maxDimension || decoded.height > maxDimension) {
        if (decoded.width >= decoded.height) {
          decoded = img.copyResize(
            decoded,
            width: maxDimension,
            interpolation: img.Interpolation.cubic,
          );
        } else {
          decoded = img.copyResize(
            decoded,
            height: maxDimension,
            interpolation: img.Interpolation.cubic,
          );
        }
      }

      if (tiltDegrees.abs() > 0.25) {
        final img.Image rgbaForRot = decoded.convert(numChannels: 4);
        decoded = img.copyRotate(
          rgbaForRot,
          angle: tiltDegrees,
          interpolation: img.Interpolation.cubic,
        );
      }

      final img.Image rgbaImg = decoded.convert(numChannels: 4);
      final Uint8List rawRgba = rgbaImg.getBytes(order: img.ChannelOrder.rgba);
      final int w = rgbaImg.width;
      final int h = rgbaImg.height;

      if (tiltDegrees.abs() > 0.25) {
        final int total = w * h;
        for (int i = 0; i < total; i++) {
          final int idx = i << 2;
          if (rawRgba[idx + 3] < 128) {
            rawRgba[idx] = 255;
            rawRgba[idx + 1] = 255;
            rawRgba[idx + 2] = 255;
            rawRgba[idx + 3] = 255;
          }
        }
      }

      final Uint8List processedRgba = _processRgbaIsolate(
        rawRgba,
        w,
        h,
        filterId,
        intensity,
      );

      final img.Image outImg = img.Image.fromBytes(
        width: w,
        height: h,
        bytes: processedRgba.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      final Uint8List jpgBytes = Uint8List.fromList(
        img.encodeJpg(outImg, quality: quality),
      );
      File(outputPath).writeAsBytesSync(jpgBytes, flush: true);
      return outputPath;
    });
  }

  static Future<String> rotateImage90Fast(String imagePath) async {
    return Isolate.run(() {
      final File f = File(imagePath);
      if (!f.existsSync()) return imagePath;
      final Uint8List bytes = f.readAsBytesSync();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return imagePath;
      decoded = img.bakeOrientation(decoded);
      final img.Image rotated = img.copyRotate(decoded, angle: 90);
      final Uint8List jpg = Uint8List.fromList(img.encodeJpg(rotated, quality: 94));
      f.writeAsBytesSync(jpg, flush: true);
      return imagePath;
    });
  }
}

Uint8List _processRgbaIsolate(
  Uint8List rawSrc,
  int w,
  int h,
  String filter,
  double intensity,
) {
  final int totalPixels = w * h;
  if (w <= 0 || h <= 0 || rawSrc.length < totalPixels * 4) {
    return Uint8List.fromList(rawSrc);
  }

  if (filter == 'original') {
    return Uint8List.fromList(rawSrc);
  }

  intensity = intensity.clamp(0.0, 1.0);
  final double scaleFactor = (min(w, h) / 900.0).clamp(0.85, 3.0);
  final bool isBw = filter == 'super_bw';

  // STEP 1: YCbCr Decomposition + Edge-Preserving Chroma & Luma Denoise
  final Float32List yPlane = Float32List(totalPixels);
  final Float32List cbPlane = isBw ? Float32List(0) : Float32List(totalPixels);
  final Float32List crPlane = isBw ? Float32List(0) : Float32List(totalPixels);

  for (int i = 0; i < totalPixels; i++) {
    final int idx = i << 2;
    final double r = rawSrc[idx].toDouble();
    final double g = rawSrc[idx + 1].toDouble();
    final double b = rawSrc[idx + 2].toDouble();
    final double y = 0.299 * r + 0.587 * g + 0.114 * b;
    yPlane[i] = y;
    if (!isBw) {
      cbPlane[i] = b - y;
      crPlane[i] = r - y;
    }
  }

  final Float32List smoothY = Float32List.fromList(yPlane);
  final Float32List smoothCb = isBw ? Float32List(0) : Float32List.fromList(cbPlane);
  final Float32List smoothCr = isBw ? Float32List(0) : Float32List.fromList(crPlane);

  final int cStep = scaleFactor > 1.55 ? 2 : 1;
  final double lumaSmoothThresh = isBw ? 14.0 : 10.5;
  const double chromaSmoothThresh = 26.0;

  for (int y = cStep; y < h - cStep; y++) {
    final int row = y * w;
    for (int x = cStep; x < w - cStep; x++) {
      final int i = row + x;
      final double yc = yPlane[i];

      double yAcc = yc * 2.0;
      double yW = 2.0;
      final int nUp = i - w;
      final int nDn = i + w;
      final int nLt = i - 1;
      final int nRt = i + 1;

      if ((yPlane[nUp] - yc).abs() <= lumaSmoothThresh) {
        yAcc += yPlane[nUp];
        yW += 1.0;
      }
      if ((yPlane[nDn] - yc).abs() <= lumaSmoothThresh) {
        yAcc += yPlane[nDn];
        yW += 1.0;
      }
      if ((yPlane[nLt] - yc).abs() <= lumaSmoothThresh) {
        yAcc += yPlane[nLt];
        yW += 1.0;
      }
      if ((yPlane[nRt] - yc).abs() <= lumaSmoothThresh) {
        yAcc += yPlane[nRt];
        yW += 1.0;
      }
      smoothY[i] = yAcc / yW;

      if (!isBw) {
        double cbAcc = cbPlane[i] * 2.0;
        double crAcc = crPlane[i] * 2.0;
        double cW = 2.0;

        for (int dy = -1; dy <= 1; dy++) {
          final int nRow = (y + dy * cStep) * w;
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final int ni = nRow + x + dx * cStep;
            if ((yPlane[ni] - yc).abs() <= chromaSmoothThresh) {
              cbAcc += cbPlane[ni];
              crAcc += crPlane[ni];
              cW += 1.0;
            }
          }
        }
        smoothCb[i] = cbAcc / cW;
        smoothCr[i] = crAcc / cW;
      }
    }
  }

  // STEP 2: Global Paper White-Balance + Luminance-Only 2D Illumination Field
  final Int32List lumHist = Int32List(256);
  final int histStep = totalPixels > 450000 ? 2 : 1;
  int histTotal = 0;
  for (int i = 0; i < totalPixels; i += histStep) {
    final int bin = smoothY[i].round().clamp(0, 255);
    lumHist[bin]++;
    histTotal++;
  }

  int p85Lum = 215;
  int p85Count = 0;
  final int p85Target = (histTotal * 0.85).round();
  for (int b = 0; b < 256; b++) {
    p85Count += lumHist[b];
    if (p85Count >= p85Target) {
      p85Lum = b;
      break;
    }
  }

  double shiftCb = 0.0;
  double shiftCr = 0.0;
  if (!isBw) {
    final double brightThresh = p85Lum * 0.82;
    double sumCb = 0.0;
    double sumCr = 0.0;
    int paperSamples = 0;
    final int wbStep = max(2, totalPixels ~/ 120000);

    for (int i = 0; i < totalPixels; i += wbStep) {
      if (smoothY[i] >= brightThresh &&
          (smoothCb[i].abs() + smoothCr[i].abs()) < 48.0) {
        sumCb += smoothCb[i];
        sumCr += smoothCr[i];
        paperSamples++;
      }
    }

    if (paperSamples > 30) {
      final double wbStrength = (filter == 'magic_pro' ||
              filter == 'lighten_pro' ||
              filter == 'ocv_crisp')
          ? 0.72
          : (filter == 'vivid_color' ? 0.35 : 0.48);
      shiftCb = ((sumCb / paperSamples) * wbStrength).clamp(-22.0, 22.0);
      shiftCr = ((sumCr / paperSamples) * wbStrength).clamp(-22.0, 22.0);
    }
  }

  final int gridCols = max(20, min(36, w ~/ 48));
  final int gridRows = max(20, min(36, h ~/ 48));
  final double blockW = w / gridCols;
  final double blockH = h / gridRows;
  final Float32List bgLGrid = Float32List(gridRows * gridCols);
  final double minFloorL = max(62.0, p85Lum * 0.56);

  final Int32List blkHist = Int32List(256);
  for (int gy = 0; gy < gridRows; gy++) {
    final int y0 = (gy * blockH).floor();
    final int y1 = min(h, ((gy + 1) * blockH).ceil());
    for (int gx = 0; gx < gridCols; gx++) {
      final int x0 = (gx * blockW).floor();
      final int x1 = min(w, ((gx + 1) * blockW).ceil());

      blkHist.fillRange(0, 256, 0);
      int samples = 0;
      final int stepY = (y1 - y0) > 28 ? 2 : 1;
      final int stepX = (x1 - x0) > 28 ? 2 : 1;

      for (int py = y0; py < y1; py += stepY) {
        final int rBase = py * w;
        for (int px = x0; px < x1; px += stepX) {
          final int bin = smoothY[rBase + px].round().clamp(0, 255);
          blkHist[bin]++;
          samples++;
        }
      }

      if (samples == 0) {
        bgLGrid[gy * gridCols + gx] = max(180.0, minFloorL);
        continue;
      }

      final int target = max(1, (samples * 0.14).round());
      int acc = 0;
      double sumTop = 0.0;
      for (int bin = 255; bin >= 0; bin--) {
        final int c = blkHist[bin];
        if (c > 0) {
          final int take = min(c, target - acc);
          sumTop += bin * take;
          acc += take;
          if (acc >= target) break;
        }
      }
      final double estL = sumTop / max(1, acc);
      bgLGrid[gy * gridCols + gx] = max(estL, minFloorL).clamp(55.0, 255.0);
    }
  }

  final Float32List dilL = Float32List(gridRows * gridCols);
  for (int gy = 0; gy < gridRows; gy++) {
    for (int gx = 0; gx < gridCols; gx++) {
      double mL = 0.0;
      for (int dy = -1; dy <= 1; dy++) {
        final int ny = (gy + dy).clamp(0, gridRows - 1);
        for (int dx = -1; dx <= 1; dx++) {
          final int nx = (gx + dx).clamp(0, gridCols - 1);
          final double v = bgLGrid[ny * gridCols + nx];
          if (v > mL) mL = v;
        }
      }
      final int gIdx = gy * gridCols + gx;
      dilL[gIdx] = mL * 0.78 + bgLGrid[gIdx] * 0.22;
    }
  }

  Float32List smoothGridA = dilL;
  Float32List smoothGridB = Float32List(gridRows * gridCols);
  for (int pass = 0; pass < 2; pass++) {
    for (int gy = 0; gy < gridRows; gy++) {
      for (int gx = 0; gx < gridCols; gx++) {
        double acc = 0.0;
        double wSum = 0.0;
        for (int dy = -1; dy <= 1; dy++) {
          final int ny = (gy + dy).clamp(0, gridRows - 1);
          final double wy = dy == 0 ? 2.0 : 1.0;
          for (int dx = -1; dx <= 1; dx++) {
            final int nx = (gx + dx).clamp(0, gridCols - 1);
            final double wx = dx == 0 ? 2.0 : 1.0;
            final double weight = wx * wy;
            acc += smoothGridA[ny * gridCols + nx] * weight;
            wSum += weight;
          }
        }
        smoothGridB[gy * gridCols + gx] = acc / wSum;
      }
    }
    final Float32List tmp = smoothGridA;
    smoothGridA = smoothGridB;
    smoothGridB = tmp;
  }
  final Float32List finalBgL = smoothGridA;

  // STEP 3: Shadow Normalization
  final double maxGain = switch (filter) {
    'super_bw' => 2.70,
    'lighten_pro' => 2.85,
    'vivid_color' => 1.85,
    'auto_pro' => 2.15,
    _ => 2.48,
  };

  final Float32List normY = Float32List(totalPixels);
  final Float32List pixelGain = isBw ? Float32List(0) : Float32List(totalPixels);

  for (int y = 0; y < h; y++) {
    final double fy = ((y + 0.5) / blockH) - 0.5;
    final int gy0 = fy.floor().clamp(0, gridRows - 1);
    final int gy1 = min(gridRows - 1, gy0 + 1);
    final double ty = (fy - gy0).clamp(0.0, 1.0);
    final int row = y * w;

    for (int x = 0; x < w; x++) {
      final double fx = ((x + 0.5) / blockW) - 0.5;
      final int gx0 = fx.floor().clamp(0, gridCols - 1);
      final int gx1 = min(gridCols - 1, gx0 + 1);
      final double tx = (fx - gx0).clamp(0.0, 1.0);

      final double l00 = finalBgL[gy0 * gridCols + gx0];
      final double l10 = finalBgL[gy0 * gridCols + gx1];
      final double l01 = finalBgL[gy1 * gridCols + gx0];
      final double l11 = finalBgL[gy1 * gridCols + gx1];
      final double bgL = (l00 * (1.0 - tx) + l10 * tx) * (1.0 - ty) +
          (l01 * (1.0 - tx) + l11 * tx) * ty;

      final int i = row + x;
      final double g = (252.0 / bgL).clamp(1.0, maxGain);
      normY[i] = (smoothY[i] * g).clamp(0.0, 255.0);
      if (!isBw) {
        pixelGain[i] = g;
      }
    }
  }

  final Uint8List out = Uint8List(totalPixels * 4);

  // STEP 4A: B&W PRO (Multi-Scale Sauvola + Hollow-Text Fix + Speckle Removal)
  if (isBw) {
    final int iw = w + 1;
    final Float64List sumLum = Float64List(iw * (h + 1));
    final Float64List sumSqLum = Float64List(iw * (h + 1));

    for (int y = 0; y < h; y++) {
      double rowS = 0.0;
      double rowSq = 0.0;
      final int rBase = y * w;
      final int iBase = (y + 1) * iw;
      final int prevBase = y * iw;
      for (int x = 0; x < w; x++) {
        final double v = normY[rBase + x];
        rowS += v;
        rowSq += v * v;
        sumLum[iBase + x + 1] = sumLum[prevBase + x + 1] + rowS;
        sumSqLum[iBase + x + 1] = sumSqLum[prevBase + x + 1] + rowSq;
      }
    }

    final int rad = max(12, min(w, h) ~/ 36);
    final double kSauvola = 0.16 + 0.18 * (1.0 - intensity);
    const double band = 6.5;
    final Uint8List bwBuf = Uint8List(totalPixels);

    for (int y = 0; y < h; y++) {
      final int y0 = max(0, y - rad);
      final int y1 = min(h - 1, y + rad);
      final int row = y * w;
      final int r0Idx = y0 * iw;
      final int r1Idx = (y1 + 1) * iw;

      for (int x = 0; x < w; x++) {
        final int i = row + x;
        final double cur = normY[i];

        if (cur < 62.0) {
          bwBuf[i] = 0;
          continue;
        }
        if (cur > 236.0) {
          bwBuf[i] = 255;
          continue;
        }

        final int x0 = max(0, x - rad);
        final int x1 = min(w - 1, x + rad);
        final int area = (x1 - x0 + 1) * (y1 - y0 + 1);

        final double s = sumLum[r1Idx + x1 + 1] -
            sumLum[r0Idx + x1 + 1] -
            sumLum[r1Idx + x0] +
            sumLum[r0Idx + x0];
        final double sq = sumSqLum[r1Idx + x1 + 1] -
            sumSqLum[r0Idx + x1 + 1] -
            sumSqLum[r1Idx + x0] +
            sumSqLum[r0Idx + x0];

        final double mean = s / area;
        final double variance = max(0.0, (sq / area) - mean * mean);
        final double stdDev = sqrt(variance);

        if (cur > 224.0 && stdDev < 13.0) {
          bwBuf[i] = 255;
          continue;
        }

        double thresh = mean * (1.0 + kSauvola * ((stdDev / 128.0) - 1.0));
        if (mean < 115.0) {
          thresh = max(thresh, mean * 0.88 + 16.0);
        }

        final double d = cur - thresh;
        if (d <= -band) {
          bwBuf[i] = 0;
        } else if (d >= band) {
          bwBuf[i] = 255;
        } else {
          bwBuf[i] = (((d + band) / (2.0 * band)) * 255.0).round().clamp(0, 255);
        }
      }
    }

    for (int y = 1; y < h - 1; y++) {
      final int row = y * w;
      for (int x = 1; x < w - 1; x++) {
        final int i = row + x;
        if (bwBuf[i] < 110) {
          if (bwBuf[i - w - 1] >= 220 &&
              bwBuf[i - w] >= 220 &&
              bwBuf[i - w + 1] >= 220 &&
              bwBuf[i - 1] >= 220 &&
              bwBuf[i + 1] >= 220 &&
              bwBuf[i + w - 1] >= 220 &&
              bwBuf[i + w] >= 220 &&
              bwBuf[i + w + 1] >= 220) {
            bwBuf[i] = 255;
          }
        }
      }
    }

    for (int i = 0; i < totalPixels; i++) {
      final int v = bwBuf[i];
      final int idx = i << 2;
      out[idx] = v;
      out[idx + 1] = v;
      out[idx + 2] = v;
      out[idx + 3] = 255;
    }
    return out;
  }

  // STEP 4B: COLOR MODES (Optional Local Stroke Boost + Smooth Tone Curve)
  if (filter == 'dark_ink') {
    final int iw = w + 1;
    final Float64List sumLum = Float64List(iw * (h + 1));
    for (int y = 0; y < h; y++) {
      double rowS = 0.0;
      final int rBase = y * w;
      final int iBase = (y + 1) * iw;
      final int prevBase = y * iw;
      for (int x = 0; x < w; x++) {
        rowS += normY[rBase + x];
        sumLum[iBase + x + 1] = sumLum[prevBase + x + 1] + rowS;
      }
    }

    final int rad = max(8, min(w, h) ~/ 60);
    final double boostStrength = 0.35 + 0.35 * intensity;
    for (int y = 0; y < h; y++) {
      final int y0 = max(0, y - rad);
      final int y1 = min(h - 1, y + rad);
      final int row = y * w;
      final int r0Idx = y0 * iw;
      final int r1Idx = (y1 + 1) * iw;
      for (int x = 0; x < w; x++) {
        final int i = row + x;
        final double cur = normY[i];
        if (cur <= 25.0 || cur >= 232.0) continue;

        final int x0 = max(0, x - rad);
        final int x1 = min(w - 1, x + rad);
        final int area = (x1 - x0 + 1) * (y1 - y0 + 1);
        final double s = sumLum[r1Idx + x1 + 1] -
            sumLum[r0Idx + x1 + 1] -
            sumLum[r1Idx + x0] +
            sumLum[r0Idx + x0];
        final double localMean = s / area;
        if (cur < localMean - 7.0) {
          final double delta = ((localMean - cur) * boostStrength).clamp(0.0, 44.0);
          normY[i] = (cur - delta).clamp(0.0, 255.0);
        }
      }
    }
  }

  late double whitePoint;
  late double blackPoint;
  late double inkGamma;
  late double sMix;
  late double satBoost;
  late double sharpAmt;

  switch (filter) {
    case 'magic_pro':
      whitePoint = 238.0 - 15.0 * intensity;
      blackPoint = 8.0 + 12.0 * intensity;
      inkGamma = 1.12 + 0.24 * intensity;
      sMix = 0.24;
      satBoost = 1.18 + 0.22 * intensity;
      sharpAmt = 0.55 + 0.50 * intensity;
      break;
    case 'auto_pro':
      whitePoint = 244.0 - 10.0 * intensity;
      blackPoint = 5.0 + 7.0 * intensity;
      inkGamma = 1.04 + 0.14 * intensity;
      sMix = 0.12;
      satBoost = 1.08 + 0.14 * intensity;
      sharpAmt = 0.38 + 0.35 * intensity;
      break;
    case 'lighten_pro':
      whitePoint = 236.0 - 14.0 * intensity;
      blackPoint = 4.0 + 8.0 * intensity;
      inkGamma = 0.88 + 0.14 * (1.0 - intensity);
      sMix = 0.05;
      satBoost = 1.10 + 0.14 * intensity;
      sharpAmt = 0.40 + 0.35 * intensity;
      break;
    case 'dark_ink':
      whitePoint = 235.0 - 14.0 * intensity;
      blackPoint = 14.0 + 18.0 * intensity;
      inkGamma = 1.28 + 0.36 * intensity;
      sMix = 0.26;
      satBoost = 0.94;
      sharpAmt = 0.62 + 0.55 * intensity;
      break;
    case 'ocv_crisp':
      whitePoint = 232.0 - 14.0 * intensity;
      blackPoint = 10.0 + 14.0 * intensity;
      inkGamma = 1.18 + 0.28 * intensity;
      sMix = 0.28;
      satBoost = 0.86;
      sharpAmt = 0.68 + 0.55 * intensity;
      break;
    case 'vivid_color':
      whitePoint = 247.0 - 6.0 * intensity;
      blackPoint = 4.0 + 6.0 * intensity;
      inkGamma = 1.02 + 0.12 * intensity;
      sMix = 0.12;
      satBoost = 1.26 + 0.28 * intensity;
      sharpAmt = 0.32 + 0.30 * intensity;
      break;
    default:
      whitePoint = 238.0 - 15.0 * intensity;
      blackPoint = 8.0 + 12.0 * intensity;
      inkGamma = 1.12 + 0.24 * intensity;
      sMix = 0.22;
      satBoost = 1.15;
      sharpAmt = 0.50;
  }

  final Float32List toneLut = Float32List(256);
  final double span = max(40.0, whitePoint - blackPoint);
  for (int v = 0; v < 256; v++) {
    if (v <= blackPoint) {
      toneLut[v] = (v / max(1.0, blackPoint)) * 4.0;
    } else if (v >= whitePoint) {
      toneLut[v] = 255.0;
    } else {
      final double t = ((v - blackPoint) / span).clamp(0.0, 1.0);
      final double g = pow(t, inkGamma).toDouble();
      final double s = g * g * (3.0 - 2.0 * g);
      final double curved = g * (1.0 - sMix) + s * sMix;
      toneLut[v] = (4.0 + curved * 251.0).clamp(0.0, 255.0);
    }
  }

  final Uint8List outLum = Uint8List(totalPixels);
  for (int i = 0; i < totalPixels; i++) {
    final double nY = normY[i];
    final int lo = nY.floor().clamp(0, 254);
    final double frac = (nY - lo).clamp(0.0, 1.0);
    final double targetY = toneLut[lo] * (1.0 - frac) + toneLut[lo + 1] * frac;
    outLum[i] = targetY.round().clamp(0, 255);

    if (targetY >= 254.5) {
      final int idx = i << 2;
      out[idx] = 255;
      out[idx + 1] = 255;
      out[idx + 2] = 255;
      out[idx + 3] = 255;
      continue;
    }

    final double wbScale = (smoothY[i] / 225.0).clamp(0.15, 1.0);
    final double gainChroma = pow(pixelGain[i], 0.42).toDouble();
    final double cbRaw = (smoothCb[i] - shiftCb * wbScale) * gainChroma;
    final double crRaw = (smoothCr[i] - shiftCr * wbScale) * gainChroma;

    final double paperFade = ((255.0 - targetY) / 36.0).clamp(0.0, 1.0);
    double effSat = satBoost * paperFade;
    if (targetY > 205.0 && (cbRaw.abs() + crRaw.abs()) < 14.0) {
      effSat *= 0.4;
    }

    final double cb = cbRaw * effSat;
    final double cr = crRaw * effSat;

    final int r = (targetY + cr).round().clamp(0, 255);
    final int b = (targetY + cb).round().clamp(0, 255);
    final int g = (targetY - 0.50937 * cr - 0.19421 * cb).round().clamp(0, 255);

    final int idx = i << 2;
    out[idx] = r;
    out[idx + 1] = g;
    out[idx + 2] = b;
    out[idx + 3] = 255;
  }

  // STEP 5: Resolution-Independent Edge-Aware Unsharp Mask with Coring
  final int sharpRad = max(1, (min(w, h) / 900.0).round());
  final int win = 2 * sharpRad + 1;
  final Float32List blurH = Float32List(totalPixels);
  final Float32List blurV = Float32List(totalPixels);

  for (int y = 0; y < h; y++) {
    final int row = y * w;
    double sum = 0.0;
    for (int kx = -sharpRad; kx <= sharpRad; kx++) {
      sum += outLum[row + kx.clamp(0, w - 1)];
    }
    for (int x = 0; x < w; x++) {
      blurH[row + x] = sum / win;
      final int addX = min(w - 1, x + 1 + sharpRad);
      final int remX = max(0, x - sharpRad);
      sum += outLum[row + addX] - outLum[row + remX];
    }
  }

  for (int x = 0; x < w; x++) {
    double sum = 0.0;
    for (int ky = -sharpRad; ky <= sharpRad; ky++) {
      sum += blurH[ky.clamp(0, h - 1) * w + x];
    }
    for (int y = 0; y < h; y++) {
      blurV[y * w + x] = sum / win;
      final int addY = min(h - 1, y + 1 + sharpRad);
      final int remY = max(0, y - sharpRad);
      sum += blurH[addY * w + x] - blurH[remY * w + x];
    }
  }

  const int coring = 6;
  for (int i = 0; i < totalPixels; i++) {
    final int center = outLum[i];
    if (center >= 242) continue;

    final double diff = center - blurV[i];
    if (diff.abs() <= coring) continue;

    final double effectiveDiff = diff > 0 ? (diff - coring) : (diff + coring);
    final int delta = (effectiveDiff * sharpAmt).round().clamp(-42, 30);
    if (delta == 0) continue;

    final int idx = i << 2;
    out[idx] = (out[idx] + delta).clamp(0, 255);
    out[idx + 1] = (out[idx + 1] + delta).clamp(0, 255);
    out[idx + 2] = (out[idx + 2] + delta).clamp(0, 255);
  }

  return out;
}

// ============================================================================
// 2. AI PROJECTION-PROFILE DESKEW & ROTATION ENGINE
// ============================================================================

class AIDeskewEngine {
  static Future<double> detectTiltAngle(String imagePath) async {
    return Isolate.run(() {
      final File f = File(imagePath);
      if (!f.existsSync()) return 0.0;
      final Uint8List bytes = f.readAsBytesSync();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return 0.0;
      decoded = img.bakeOrientation(decoded);

      const int thumbW = 280;
      final img.Image small = img.copyResize(
        decoded,
        width: thumbW,
        interpolation: img.Interpolation.linear,
      );
      final int w = small.width;
      final int h = small.height;
      final Uint8List rgba = small.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);

      final Uint8List edges = Uint8List(w * h);
      final Uint8List lum = Uint8List(w * h);
      for (int i = 0; i < w * h; i++) {
        final int idx = i << 2;
        lum[i] = (rgba[idx] * 77 + rgba[idx + 1] * 150 + rgba[idx + 2] * 29) >> 8;
      }

      for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
          final int i = y * w + x;
          final int gy = (lum[i + w] - lum[i - w]).abs();
          final int gx = (lum[i + 1] - lum[i - 1]).abs();
          if (gy > 22 && gy >= gx) {
            edges[i] = 1;
          }
        }
      }

      double bestAngle = 0.0;
      double bestScore = -1.0;

      for (double deg = -12.0; deg <= 12.0; deg += 0.5) {
        final double rad = deg * pi / 180.0;
        final double tanA = tan(rad);
        final Int32List rowProj = Int32List(h);

        for (int y = 0; y < h; y++) {
          final int rBase = y * w;
          for (int x = 0; x < w; x++) {
            if (edges[rBase + x] == 1) {
              final int ny = (y - (x - w * 0.5) * tanA).round();
              if (ny >= 0 && ny < h) {
                rowProj[ny]++;
              }
            }
          }
        }

        double score = 0.0;
        for (int y = 0; y < h; y++) {
          final double v = rowProj[y].toDouble();
          score += v * v;
        }

        if (score > bestScore) {
          bestScore = score;
          bestAngle = deg;
        }
      }

      return -bestAngle;
    });
  }

  static Future<String> rotateAndDeskewImage(
    String inputPath,
    String outputPath,
    double angleDegrees,
  ) async {
    return Isolate.run(() {
      final File f = File(inputPath);
      if (!f.existsSync()) return inputPath;
      final Uint8List bytes = f.readAsBytesSync();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return inputPath;
      decoded = img.bakeOrientation(decoded);

      final img.Image rgbaForRot = decoded.convert(numChannels: 4);
      final img.Image rotated = img.copyRotate(
        rgbaForRot,
        angle: angleDegrees,
        interpolation: img.Interpolation.cubic,
      );

      final Uint8List raw = rotated.getBytes(order: img.ChannelOrder.rgba);
      final int total = rotated.width * rotated.height;
      for (int i = 0; i < total; i++) {
        final int idx = i << 2;
        if (raw[idx + 3] < 128) {
          raw[idx] = 255;
          raw[idx + 1] = 255;
          raw[idx + 2] = 255;
          raw[idx + 3] = 255;
        }
      }

      final img.Image clean = img.Image.fromBytes(
        width: rotated.width,
        height: rotated.height,
        bytes: raw.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      final Uint8List jpg = Uint8List.fromList(img.encodeJpg(clean, quality: 94));
      File(outputPath).writeAsBytesSync(jpg, flush: true);
      return outputPath;
    });
  }
}

// ============================================================================
// 3. DATA MODELS & PERSISTENT STORAGE
// ============================================================================

class DocumentModel {
  final String id;
  String title;
  List<String> imagePaths;
  String filterUsed;
  final DateTime createdAt;
  DateTime updatedAt;
  String tag;

  DocumentModel({
    required this.id,
    required this.title,
    required this.imagePaths,
    this.filterUsed = 'magic_pro',
    required this.createdAt,
    required this.updatedAt,
    this.tag = 'Document',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'imagePaths': imagePaths,
        'filterUsed': filterUsed,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'tag': tag,
      };

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? 'Untitled Scan',
      imagePaths: (json['imagePaths'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      filterUsed: (json['filterUsed'] as String?) ?? 'magic_pro',
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
      tag: (json['tag'] as String?) ?? 'Document',
    );
  }
}

class DocumentStorageService {
  static const String _storageKey = 'pro_scanner_docs_v2';
  static const String _settingsKey = 'pro_scanner_settings_v1';

  static Future<Directory> getAppDocsDir() async {
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${base.path}/ProDocScanner');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> createUniqueImagePath({String prefix = 'page'}) async {
    final Directory dir = await getAppDocsDir();
    final int ts = DateTime.now().microsecondsSinceEpoch;
    final int rnd = Random().nextInt(9999);
    return '${dir.path}/${prefix}_${ts}_$rnd.jpg';
  }

  static Future<String> createUniquePdfPath(String title) async {
    final Directory dir = await getAppDocsDir();
    final String safe = title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final int ts = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/${safe}_$ts.pdf';
  }

  static Future<List<DocumentModel>> loadDocuments() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <DocumentModel>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final List<DocumentModel> docs = list
          .map((dynamic e) => DocumentModel.fromJson(e as Map<String, dynamic>))
          .where((DocumentModel d) => d.imagePaths.isNotEmpty)
          .toList();
      docs.sort((DocumentModel a, DocumentModel b) =>
          b.updatedAt.compareTo(a.updatedAt));
      return docs;
    } catch (_) {
      return <DocumentModel>[];
    }
  }

  static Future<void> saveDocuments(List<DocumentModel> docs) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded =
        jsonEncode(docs.map((DocumentModel d) => d.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  static Future<void> saveDocument(DocumentModel doc) async {
    final List<DocumentModel> docs = await loadDocuments();
    final int idx = docs.indexWhere((DocumentModel d) => d.id == doc.id);
    if (idx >= 0) {
      docs[idx] = doc;
    } else {
      docs.insert(0, doc);
    }
    await saveDocuments(docs);
  }

  static Future<void> deleteDocument(String docId) async {
    final List<DocumentModel> docs = await loadDocuments();
    final int idx = docs.indexWhere((DocumentModel d) => d.id == docId);
    if (idx >= 0) {
      for (final String p in docs[idx].imagePaths) {
        try {
          final File f = File(p);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      docs.removeAt(idx);
      await saveDocuments(docs);
    }
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{
        'defaultFilter': 'magic_pro',
        'pdfQuality': 'High (2400px)',
        'autoEnhance': true,
      };
    }
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{
        'defaultFilter': 'magic_pro',
        'pdfQuality': 'High (2400px)',
        'autoEnhance': true,
      };
    }
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }
}
// ============================================================================
// 4. ML KIT DOCUMENT SCANNER SERVICE
// ============================================================================

class DocumentScannerService {
  static Future<List<String>> scanWithCamera({
    bool allowImport = true,
    int pageLimit = 30,
  }) async {
    final DocumentScannerOptions options = DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.base,
      pageLimit: pageLimit,
      isGalleryImport: allowImport,
    );

    final DocumentScanner scanner = DocumentScanner(options: options);
    try {
      final DocumentScanningResult result = await scanner.scanDocument();
      return result.images;
    } finally {
      await scanner.close();
    }
  }
}

// ============================================================================
// 5. MAIN APPLICATION & NAVIGATION SHELL
// ============================================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProDoc Scanner AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E56F0),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F6FA),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF111827),
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: Color(0xFF111827)),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  List<DocumentModel> _docs = <DocumentModel>[];
  bool _isLoading = true;
  Map<String, dynamic> _settings = <String, dynamic>{};
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final List<DocumentModel> loadedDocs =
        await DocumentStorageService.loadDocuments();
    final Map<String, dynamic> loadedSettings =
        await DocumentStorageService.loadSettings();
    if (!mounted) return;
    setState(() {
      _docs = loadedDocs;
      _settings = loadedSettings;
      _isLoading = false;
    });
  }

  Future<void> _startScan({required bool allowGalleryImport}) async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    try {
      final List<String> scannedPaths =
          await DocumentScannerService.scanWithCamera(
        allowImport: allowGalleryImport,
        pageLimit: 30,
      );
      if (scannedPaths.isEmpty || !mounted) return;

      final bool autoEnhance = (_settings['autoEnhance'] as bool?) ?? true;
      final String defaultFilter = autoEnhance
          ? ((_settings['defaultFilter'] as String?) ?? 'magic_pro')
          : 'original';

      final DocumentModel? newDoc = await Navigator.push<DocumentModel>(
        context,
        MaterialPageRoute<DocumentModel>(
          builder: (_) => ScanFilterReviewScreen(
            rawPaths: scannedPaths,
            initialFilter: defaultFilter,
          ),
        ),
      );

      if (newDoc != null) {
        await DocumentStorageService.saveDocument(newDoc);
        await _loadAllData();
        if (mounted) {
          setState(() => _currentIndex = 0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Saved "${newDoc.title}" (${newDoc.imagePaths.length} page${newDoc.imagePaths.length > 1 ? 's' : ''})',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF0F172A),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanner error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _openQuickCamera() => _startScan(allowGalleryImport: true);

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      HomeScreen(
        docs: _docs,
        isLoading: _isLoading,
        onRefresh: _loadAllData,
        onScanPressed: () => _startScan(allowGalleryImport: true),
        onImportPressed: () => _startScan(allowGalleryImport: true),
      ),
      PdfStudioScreen(
        docs: _docs,
        onRefresh: _loadAllData,
      ),
      SettingsScreen(
        settings: _settings,
        onSettingsChanged: (Map<String, dynamic> updated) async {
          await DocumentStorageService.saveSettings(updated);
          if (mounted) {
            setState(() => _settings = updated);
          }
        },
        onClearAllDocs: () async {
          for (final DocumentModel d in _docs) {
            await DocumentStorageService.deleteDocument(d.id);
          }
          await _loadAllData();
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _isScanning ? null : _openQuickCamera,
              backgroundColor: const Color(0xFF1E56F0),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.document_scanner_rounded),
              label: Text(
                _isScanning ? 'Opening...' : 'Scan',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: const Color(0xFF1E56F0).withOpacity(0.14),
        onDestinationSelected: (int idx) {
          setState(() => _currentIndex = idx);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon:
                Icon(Icons.folder_rounded, color: Color(0xFF1E56F0)),
            label: 'Docs',
          ),
          NavigationDestination(
            icon: Icon(Icons.picture_as_pdf_outlined),
            selectedIcon:
                Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF1E56F0)),
            label: 'PDF Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon:
                Icon(Icons.settings_rounded, color: Color(0xFF1E56F0)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. HOME SCREEN (DOCUMENT VAULT, SEARCH, GRID/LIST, QUICK ACTIONS)
// ============================================================================

class HomeScreen extends StatefulWidget {
  final List<DocumentModel> docs;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final VoidCallback onScanPressed;
  final VoidCallback onImportPressed;

  const HomeScreen({
    super.key,
    required this.docs,
    required this.isLoading,
    required this.onRefresh,
    required this.onScanPressed,
    required this.onImportPressed,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  String _selectedTag = 'All';
  bool _isGridView = true;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _tags = <String>[
    'All',
    'Document',
    'ID Card',
    'Receipt',
    'Notes',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DocumentModel> get _filteredDocs {
    return widget.docs.where((DocumentModel doc) {
      final bool matchesSearch = _searchQuery.isEmpty ||
          doc.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final bool matchesTag =
          _selectedTag == 'All' || doc.tag == _selectedTag;
      return matchesSearch && matchesTag;
    }).toList();
  }

  Future<void> _renameDoc(DocumentModel doc) async {
    final TextEditingController ctrl = TextEditingController(text: doc.title);
    final String? updated = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document Title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (updated != null && updated.isNotEmpty) {
      doc.title = updated;
      doc.updatedAt = DateTime.now();
      await DocumentStorageService.saveDocument(doc);
      await widget.onRefresh();
    }
  }

  Future<void> _deleteDoc(DocumentModel doc) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text(
          'Are you sure you want to permanently delete "${doc.title}" (${doc.imagePaths.length} pages)?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DocumentStorageService.deleteDocument(doc.id);
      await widget.onRefresh();
    }
  }

  Future<void> _sharePdf(DocumentModel doc) async {
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final pw.Document pdf = pw.Document();
      for (final String imgPath in doc.imagePaths) {
        final File f = File(imgPath);
        if (!await f.exists()) continue;
        final Uint8List bytes = await f.readAsBytes();
        final pw.MemoryImage pdfImg = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(8),
            build: (pw.Context ctx) {
              return pw.Center(
                child: pw.Image(pdfImg, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      final String outPath =
          await DocumentStorageService.createUniquePdfPath(doc.title);
      final File outFile = File(outPath);
      await outFile.writeAsBytes(await pdf.save());

      if (mounted) Navigator.pop(context);

      await Share.shareXFiles(
        <XFile>[XFile(outPath)],
        text: 'Scanned Document: ${doc.title}',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    }
  }

  Future<void> _changeTag(DocumentModel doc) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Assign Category Tag',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ..._tags.where((String t) => t != 'All').map((String tag) {
              return ListTile(
                leading: Icon(
                  doc.tag == tag
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: const Color(0xFF1E56F0),
                ),
                title: Text(tag),
                onTap: () => Navigator.pop(ctx, tag),
              );
            }),
          ],
        ),
      ),
    );
    if (picked != null) {
      doc.tag = picked;
      doc.updatedAt = DateTime.now();
      await DocumentStorageService.saveDocument(doc);
      await widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<DocumentModel> docs = _filteredDocs;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              expandedHeight: 70,
              title: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF1E56F0), Color(0xFF0EA5E9)],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('ProDoc Scanner'),
                ],
              ),
              actions: <Widget>[
                IconButton(
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                  icon: Icon(
                    _isGridView
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                  ),
                  onPressed: () =>
                      setState(() => _isGridView = !_isGridView),
                ),
                IconButton(
                  tooltip: 'Import / Scan',
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onPressed: widget.onImportPressed,
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _searchController,
                      onChanged: (String v) =>
                          setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search scanned documents...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tags.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (BuildContext ctx, int idx) {
                          final String tag = _tags[idx];
                          final bool selected = _selectedTag == tag;
                          return ChoiceChip(
                            label: Text(tag),
                            selected: selected,
                            showCheckmark: false,
                            selectedColor: const Color(0xFF1E56F0),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF374151),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFF1E56F0)
                                  : const Color(0xFFE5E7EB),
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedTag = tag),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (docs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyHomeView(
                  hasAnyDocs: widget.docs.isNotEmpty,
                  onScanPressed: widget.onScanPressed,
                  onImportPressed: widget.onImportPressed,
                ),
              )
            else if (_isGridView)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext ctx, int i) {
                      final DocumentModel doc = docs[i];
                      return _DocumentGridCard(
                        doc: doc,
                        onTap: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => DocumentDetailScreen(doc: doc),
                            ),
                          );
                          await widget.onRefresh();
                        },
                        onAction: (String action) {
                          if (action == 'rename') _renameDoc(doc);
                          if (action == 'share') _sharePdf(doc);
                          if (action == 'tag') _changeTag(doc);
                          if (action == 'delete') _deleteDoc(doc);
                        },
                      );
                    },
                    childCount: docs.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext ctx, int i) {
                    final DocumentModel doc = docs[i];
                    return _DocumentListCard(
                      doc: doc,
                      onTap: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => DocumentDetailScreen(doc: doc),
                          ),
                        );
                        await widget.onRefresh();
                      },
                      onAction: (String action) {
                        if (action == 'rename') _renameDoc(doc);
                        if (action == 'share') _sharePdf(doc);
                        if (action == 'tag') _changeTag(doc);
                        if (action == 'delete') _deleteDoc(doc);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHomeView extends StatelessWidget {
  final bool hasAnyDocs;
  final VoidCallback onScanPressed;
  final VoidCallback onImportPressed;

  const _EmptyHomeView({
    required this.hasAnyDocs,
    required this.onScanPressed,
    required this.onImportPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFF1E56F0).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              size: 46,
              color: Color(0xFF1E56F0),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasAnyDocs ? 'No matching documents' : 'Ready for Pro Scanning',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasAnyDocs
                ? 'Try clearing your search or selecting the "All" category.'
                : 'Auto edge crop, YCbCr shadow removal, Magic Color & crisp B&W filters built directly on-device.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          if (!hasAnyDocs) ...<Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: const <Widget>[
                _FeatureBadge(icon: Icons.crop_free, label: 'Auto Edge Crop'),
                _FeatureBadge(icon: Icons.auto_fix_high, label: 'Magic Color'),
                _FeatureBadge(icon: Icons.wb_sunny_outlined, label: 'Shadow Wipe'),
                _FeatureBadge(icon: Icons.picture_as_pdf, label: 'HD PDF'),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: onScanPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E56F0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Scan Document'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onImportPressed,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Import Gallery'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: const Color(0xFF1E56F0)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentGridCard extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onTap;
  final void Function(String action) onAction;

  const _DocumentGridCard({
    required this.doc,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final String thumbPath = doc.imagePaths.first;
    final String dateStr = DateFormat('dd MMM, hh:mm a').format(doc.updatedAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Container(
                    color: const Color(0xFFF3F4F6),
                    child: File(thumbPath).existsSync()
                        ? Hero(
                            tag: 'doc_${doc.id}',
                            child: Image.file(
                              File(thumbPath),
                              fit: BoxFit.cover,
                              cacheWidth: 420,
                            ),
                          )
                        : const Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: Colors.grey,
                          ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${doc.imagePaths.length}p',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.90),
                        shape: BoxShape.circle,
                      ),
                      child: PopupMenuButton<String>(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: onAction,
                        itemBuilder: (_) => const <PopupMenuEntry<String>>[
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(value: 'tag', child: Text('Change Tag')),
                          PopupMenuItem(
                              value: 'share', child: Text('Share PDF')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          dateStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          doc.tag,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E56F0),
                          ),
                        ),
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
}
class _DocumentListCard extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onTap;
  final void Function(String action) onAction;

  const _DocumentListCard({
    required this.doc,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final String thumbPath = doc.imagePaths.first;
    final String dateStr =
        DateFormat('dd MMM yyyy, hh:mm a').format(doc.updatedAt);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 54,
            height: 68,
            color: const Color(0xFFF3F4F6),
            child: File(thumbPath).existsSync()
                ? Image.file(
                    File(thumbPath),
                    fit: BoxFit.cover,
                    cacheWidth: 160,
                  )
                : const Icon(Icons.broken_image_outlined),
          ),
        ),
        title: Text(
          doc.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$dateStr • ${doc.imagePaths.length} page${doc.imagePaths.length > 1 ? 's' : ''} • ${doc.tag}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: onAction,
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'tag', child: Text('Change Tag')),
            PopupMenuItem(value: 'share', child: Text('Share PDF')),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 7. PRO SCAN FILTER & AI DESKEW REVIEW STUDIO
// ============================================================================

class ScanFilterReviewScreen extends StatefulWidget {
  final List<String> rawPaths;
  final String initialFilter;
  final String initialTag;
  final String? suggestedTitle;

  const ScanFilterReviewScreen({
    super.key,
    required this.rawPaths,
    this.initialFilter = 'magic_pro',
    this.initialTag = 'Document',
    this.suggestedTitle,
  });

  @override
  State<ScanFilterReviewScreen> createState() => _ScanFilterReviewScreenState();
}

class _ScanFilterReviewScreenState extends State<ScanFilterReviewScreen> {
  late List<String> _workingPaths;
  late List<String> _pageFilters;
  late List<double> _pageIntensities;
  late List<double> _tiltAngles;

  int _currentIndex = 0;
  late String _docTitle;
  late String _selectedTag;

  final Map<String, ({Uint8List rgba, int width, int height})>
      _cachedBasePreviewRgba =
      <String, ({Uint8List rgba, int width, int height})>{};
  final Map<String, ui.Image> _cachedFilteredImages = <String, ui.Image>{};
  final Map<String, ui.Image> _cachedOriginalImages = <String, ui.Image>{};

  bool _isUpdatingPreview = false;
  bool _isSavingAll = false;
  bool _isDeskewing = false;
  bool _showOriginalCompare = false;
  int _previewRequestToken = 0;
  Timer? _intensityDebounce;

  @override
  void initState() {
    super.initState();
    _workingPaths = List<String>.from(widget.rawPaths);
    final DocFilterOption defaultOpt = kDocFilters.firstWhere(
      (DocFilterOption f) => f.id == widget.initialFilter,
      orElse: () => kDocFilters[1],
    );
    _pageFilters = List<String>.filled(_workingPaths.length, defaultOpt.id);
    _pageIntensities =
        List<double>.filled(_workingPaths.length, defaultOpt.defaultIntensity);
    _tiltAngles = List<double>.filled(_workingPaths.length, 0.0);

    _docTitle = widget.suggestedTitle ??
        'Scan ${DateFormat('dd_MMM_HHmm').format(DateTime.now())}';
    _selectedTag = widget.initialTag;

    _loadAndProcessCurrentPreview();
  }

  @override
  void dispose() {
    _intensityDebounce?.cancel();
    for (final ui.Image imgObj in _cachedFilteredImages.values) {
      imgObj.dispose();
    }
    for (final ui.Image imgObj in _cachedOriginalImages.values) {
      imgObj.dispose();
    }
    super.dispose();
  }

  String _cacheKeyFor(int index) {
    return '${_workingPaths[index]}_${_pageFilters[index]}_${_pageIntensities[index].toStringAsFixed(2)}';
  }

  Future<ui.Image> _rgbaToUiImage(Uint8List rgba, int w, int h) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (ui.Image result) => completer.complete(result),
    );
    return completer.future;
  }

  Future<void> _loadAndProcessCurrentPreview() async {
    final int idx = _currentIndex;
    final String path = _workingPaths[idx];
    final String filterId = _pageFilters[idx];
    final double intensity = _pageIntensities[idx];
    final String cacheKey = _cacheKeyFor(idx);

    if (_cachedFilteredImages.containsKey(cacheKey) &&
        _cachedOriginalImages.containsKey(path)) {
      if (mounted) setState(() {});
      return;
    }

    final int token = ++_previewRequestToken;
    if (mounted) setState(() => _isUpdatingPreview = true);

    try {
      ({Uint8List rgba, int width, int height})? base =
          _cachedBasePreviewRgba[path];
      if (base == null) {
        base = await ProDocImageProcessor.decodeImageForPreview(
          path,
          maxDimension: 900,
        );
        if (base != null) {
          _cachedBasePreviewRgba[path] = base;
          if (!_cachedOriginalImages.containsKey(path)) {
            _cachedOriginalImages[path] =
                await _rgbaToUiImage(base.rgba, base.width, base.height);
          }
        }
      }

      if (base == null || token != _previewRequestToken) return;

      final Uint8List outRgba = await ProDocImageProcessor.processPreviewRgba(
        base.rgba,
        base.width,
        base.height,
        filterId,
        intensity,
      );

      if (token != _previewRequestToken) return;

      final ui.Image uiImg =
          await _rgbaToUiImage(outRgba, base.width, base.height);

      if (token != _previewRequestToken) {
        uiImg.dispose();
        return;
      }

      _cachedFilteredImages[cacheKey] = uiImg;
    } finally {
      if (mounted && token == _previewRequestToken) {
        setState(() => _isUpdatingPreview = false);
      }
    }
  }

  void _selectFilter(DocFilterOption opt) {
    setState(() {
      _pageFilters[_currentIndex] = opt.id;
      _pageIntensities[_currentIndex] = opt.defaultIntensity;
    });
    _loadAndProcessCurrentPreview();
  }

  void _onIntensityChanged(double value) {
    setState(() {
      _pageIntensities[_currentIndex] = value;
    });
    _intensityDebounce?.cancel();
    _intensityDebounce = Timer(const Duration(milliseconds: 90), () {
      _loadAndProcessCurrentPreview();
    });
  }

  void _applyFilterToAllPages() {
    final String activeFilter = _pageFilters[_currentIndex];
    final double activeIntensity = _pageIntensities[_currentIndex];
    setState(() {
      for (int i = 0; i < _workingPaths.length; i++) {
        _pageFilters[i] = activeFilter;
        _pageIntensities[i] = activeIntensity;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Applied filter & strength to all scanned pages'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _rotate90CurrentPage() async {
    final String rawPath = _workingPaths[_currentIndex];
    setState(() => _isUpdatingPreview = true);
    try {
      final String rotatedPath =
          await ProDocImageProcessor.rotateImage90Fast(rawPath);
      _cachedBasePreviewRgba.remove(rawPath);
      _cachedOriginalImages.remove(rawPath)?.dispose();
      _cachedFilteredImages.removeWhere((String k, ui.Image v) {
        if (k.startsWith('${rawPath}_')) {
          v.dispose();
          return true;
        }
        return false;
      });
      _workingPaths[_currentIndex] = rotatedPath;
      await _loadAndProcessCurrentPreview();
    } finally {
      if (mounted) setState(() => _isUpdatingPreview = false);
    }
  }

  Future<void> _autoStraightenCurrentPage() async {
    if (_isDeskewing) return;
    setState(() => _isDeskewing = true);
    try {
      final String rawPath = _workingPaths[_currentIndex];
      final double angle = await AIDeskewEngine.detectTiltAngle(rawPath);
      if (angle.abs() < 0.4) {
        if (mounted) {
          setState(() => _tiltAngles[_currentIndex] = 0.0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document is already aligned straight!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final double clamped = angle.clamp(-15.0, 15.0);
      if (mounted) {
        setState(() => _tiltAngles[_currentIndex] = clamped);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto-straightened by ${clamped.toStringAsFixed(1)}°',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeskewing = false);
    }
  }

  Future<void> _editTitleDialog() async {
    final TextEditingController ctrl = TextEditingController(text: _docTitle);
    final String? res = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Document Name & Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTag,
              decoration: const InputDecoration(
                labelText: 'Category Tag',
                border: OutlineInputBorder(),
              ),
              items: const <String>['Document', 'ID Card', 'Receipt', 'Notes']
                  .map((String t) =>
                      DropdownMenuItem<String>(value: t, child: Text(t)))
                  .toList(),
              onChanged: (String? v) {
                if (v != null) _selectedTag = v;
              },
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty && mounted) {
      setState(() => _docTitle = res);
    }
  }

  Future<void> _finishAndExport() async {
    if (_isSavingAll) return;
    setState(() => _isSavingAll = true);

    try {
      final Map<String, dynamic> settings =
          await DocumentStorageService.loadSettings();
      final String qualityLabel =
          (settings['pdfQuality'] as String?) ?? 'High (2400px)';
      final int maxDim = qualityLabel.contains('3000')
          ? 3000
          : (qualityLabel.contains('1800') ? 1800 : 2400);

      final List<String> finalPaths = <String>[];
      for (int i = 0; i < _workingPaths.length; i++) {
        final String src = _workingPaths[i];
        final String filter = _pageFilters[i];
        final double intensity = _pageIntensities[i];
        final double tilt = _tiltAngles[i];

        final String outPath =
            await DocumentStorageService.createUniqueImagePath(
          prefix: 'doc_${i + 1}',
        );

        await ProDocImageProcessor.processAndSaveHighRes(
          inputPath: src,
          outputPath: outPath,
          filterId: filter,
          intensity: intensity,
          tiltDegrees: tilt,
          maxDimension: maxDim,
          quality: 94,
        );
        finalPaths.add(outPath);
      }

      final DateTime now = DateTime.now();
      final DocumentModel doc = DocumentModel(
        id: 'doc_${now.microsecondsSinceEpoch}',
        title: _docTitle,
        imagePaths: finalPaths,
        filterUsed: _pageFilters.first,
        createdAt: now,
        updatedAt: now,
        tag: _selectedTag,
      );

      if (mounted) {
        Navigator.pop(context, doc);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingAll = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process scan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String activePath = _workingPaths[_currentIndex];
    final String activeFilter = _pageFilters[_currentIndex];
    final double activeIntensity = _pageIntensities[_currentIndex];
    final double activeTilt = _tiltAngles[_currentIndex];
    final String cacheKey = _cacheKeyFor(_currentIndex);

    final ui.Image? displayImg = _showOriginalCompare
        ? _cachedOriginalImages[activePath]
        : (_cachedFilteredImages[cacheKey] ?? _cachedOriginalImages[activePath]);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: _isSavingAll ? null : () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: _editTitleDialog,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    _docTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_rounded, size: 15, color: Colors.white70),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          if (_workingPaths.length > 1)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_workingPaths.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.icon(
              onPressed: _isSavingAll ? null : _finishAndExport,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E56F0),
                foregroundColor: Colors.white,
              ),
              icon: _isSavingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_isSavingAll ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.5,
                    child: Transform.rotate(
                      angle: activeTilt * pi / 180.0,
                      child: displayImg != null
                          ? RawImage(
                              image: displayImg,
                              fit: BoxFit.contain,
                            )
                          : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 14,
                  child: GestureDetector(
                    onTapDown: (_) =>
                        setState(() => _showOriginalCompare = true),
                    onTapUp: (_) =>
                        setState(() => _showOriginalCompare = false),
                    onTapCancel: () =>
                        setState(() => _showOriginalCompare = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _showOriginalCompare
                            ? const Color(0xFF1E56F0)
                            : Colors.black.withOpacity(0.60),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.compare_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showOriginalCompare ? 'Original' : 'Hold Compare',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isUpdatingPreview || _isDeskewing)
                  Positioned(
                    top: 12,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.68),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isDeskewing ? 'AI Deskewing...' : 'Enhancing...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_workingPaths.length > 1) ...<Widget>[
                  if (_currentIndex > 0)
                    Positioned(
                      left: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() => _currentIndex--);
                            _loadAndProcessCurrentPreview();
                          },
                        ),
                      ),
                    ),
                  if (_currentIndex < _workingPaths.length - 1)
                    Positioned(
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() => _currentIndex++);
                            _loadAndProcessCurrentPreview();
                          },
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _StudioMiniBtn(
                        icon: Icons.rotate_right_rounded,
                        label: 'Rotate 90°',
                        onTap: _rotate90CurrentPage,
                      ),
                      const SizedBox(width: 8),
                      _StudioMiniBtn(
                        icon: Icons.straighten_rounded,
                        label: 'Straighten AI',
                        onTap: _autoStraightenCurrentPage,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.rotate_90_degrees_ccw_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2.5,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7,
                                  ),
                                ),
                                child: Slider(
                                  value: activeTilt.clamp(-15.0, 15.0),
                                  min: -15.0,
                                  max: 15.0,
                                  activeColor: const Color(0xFF38BDF8),
                                  inactiveColor: Colors.white24,
                                  onChanged: (double v) {
                                    setState(
                                      () => _tiltAngles[_currentIndex] = v,
                                    );
                                  },
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(
                                () => _tiltAngles[_currentIndex] = 0.0,
                              ),
                              child: Text(
                                '${activeTilt.toStringAsFixed(1)}°',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (activeFilter != 'original') ...<Widget>[
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.tune_rounded,
                          color: Colors.white70,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Strength',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                            ),
                            child: Slider(
                              value: activeIntensity,
                              min: 0.0,
                              max: 1.0,
                              activeColor: const Color(0xFF1E56F0),
                              inactiveColor: Colors.white24,
                              onChanged: _onIntensityChanged,
                            ),
                          ),
                        ),
                        Text(
                          '${(activeIntensity * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_workingPaths.length > 1) ...<Widget>[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _applyFilterToAllPages,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              backgroundColor: Colors.white.withOpacity(0.10),
                              foregroundColor: const Color(0xFF38BDF8),
                            ),
                            child: const Text(
                              'Apply All',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kDocFilters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (BuildContext ctx, int idx) {
                        final DocFilterOption opt = kDocFilters[idx];
                        final bool isSelected = activeFilter == opt.id;
                        return GestureDetector(
                          onTap: () => _selectFilter(opt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 78,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1E56F0)
                                  : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF60A5FA)
                                    : Colors.white.withOpacity(0.12),
                                width: isSelected ? 1.6 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  opt.icon,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  opt.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioMiniBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StudioMiniBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.09),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 8. DOCUMENT DETAIL SCREEN (MULTI-PAGE VIEW, REORDER, ADD PAGES, EXPORT PDF)
// ============================================================================

class DocumentDetailScreen extends StatefulWidget {
  final DocumentModel doc;

  const DocumentDetailScreen({super.key, required this.doc});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late DocumentModel _doc;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
  }

  Future<void> _renameDocument() async {
    final TextEditingController ctrl = TextEditingController(text: _doc.title);
    final String? res = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      setState(() {
        _doc.title = res;
        _doc.updatedAt = DateTime.now();
      });
      await DocumentStorageService.saveDocument(_doc);
    }
  }

  Future<void> _addMorePages() async {
    try {
      final List<String> newRaw = await DocumentScannerService.scanWithCamera(
        allowImport: true,
        pageLimit: 20,
      );
      if (newRaw.isEmpty || !mounted) return;

      final DocumentModel? subDoc = await Navigator.push<DocumentModel>(
        context,
        MaterialPageRoute<DocumentModel>(
          builder: (_) => ScanFilterReviewScreen(
            rawPaths: newRaw,
            initialFilter: _doc.filterUsed,
            initialTag: _doc.tag,
            suggestedTitle: _doc.title,
          ),
        ),
      );

      if (subDoc != null) {
        setState(() {
          _doc.imagePaths.addAll(subDoc.imagePaths);
          _doc.updatedAt = DateTime.now();
        });
        await DocumentStorageService.saveDocument(_doc);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add pages: $e')),
        );
      }
    }
  }

  Future<void> _reEditPage(int index) async {
    final String currentPath = _doc.imagePaths[index];
    final DocumentModel? edited = await Navigator.push<DocumentModel>(
      context,
      MaterialPageRoute<DocumentModel>(
        builder: (_) => ScanFilterReviewScreen(
          rawPaths: <String>[currentPath],
          initialFilter: _doc.filterUsed,
          initialTag: _doc.tag,
          suggestedTitle: _doc.title,
        ),
      ),
    );

    if (edited != null && edited.imagePaths.isNotEmpty) {
      setState(() {
        _doc.imagePaths[index] = edited.imagePaths.first;
        _doc.updatedAt = DateTime.now();
      });
      await DocumentStorageService.saveDocument(_doc);
      imageCache.clear();
      imageCache.clearLiveImages();
    }
  }

  Future<void> _rotatePage(int index) async {
    setState(() => _isBusy = true);
    try {
      await ProDocImageProcessor.rotateImage90Fast(_doc.imagePaths[index]);
      imageCache.clear();
      imageCache.clearLiveImages();
      _doc.updatedAt = DateTime.now();
      await DocumentStorageService.saveDocument(_doc);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deletePage(int index) async {
    if (_doc.imagePaths.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Document must have at least 1 page. Delete doc from Home instead.'),
        ),
      );
      return;
    }

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Remove Page ${index + 1}?'),
        content: const Text('This page will be removed from the document.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final String removed = _doc.imagePaths.removeAt(index);
      try {
        final File f = File(removed);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      _doc.updatedAt = DateTime.now();
      await DocumentStorageService.saveDocument(_doc);
      if (mounted) setState(() {});
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isBusy = true);
    try {
      final pw.Document pdf = pw.Document();
      for (final String path in _doc.imagePaths) {
        final File f = File(path);
        if (!await f.exists()) continue;
        final Uint8List bytes = await f.readAsBytes();
        final pw.MemoryImage pdfImg = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(8),
            build: (pw.Context ctx) {
              return pw.Center(
                child: pw.Image(pdfImg, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      final String outPath =
          await DocumentStorageService.createUniquePdfPath(_doc.title);
      await File(outPath).writeAsBytes(await pdf.save());

      if (mounted) setState(() => _isBusy = false);

      await Share.shareXFiles(
        <XFile>[XFile(outPath)],
        text: '${_doc.title}.pdf',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export PDF failed: $e')),
        );
      }
    }
  }

  Future<void> _shareImages() async {
    final List<XFile> files = _doc.imagePaths
        .where((String p) => File(p).existsSync())
        .map((String p) => XFile(p))
        .toList();
    if (files.isEmpty) return;
    await Share.shareXFiles(files, text: _doc.title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _renameDocument,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  _doc.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_outlined, size: 17, color: Colors.grey),
            ],
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Share Images',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _isBusy ? null : _shareImages,
          ),
          IconButton(
            tooltip: 'Export & Share PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _isBusy ? null : _exportPdf,
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            itemCount: _doc.imagePaths.length,
            itemBuilder: (BuildContext ctx, int idx) {
              final String path = _doc.imagePaths[idx];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => FullScreenPhotoViewer(
                                imagePaths: _doc.imagePaths,
                                initialIndex: idx,
                                title: _doc.title,
                              ),
                            ),
                          );
                          setState(() {});
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            File(path).existsSync()
                                ? Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                    cacheWidth: 500,
                                  )
                                : const Icon(Icons.broken_image_outlined),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Page ${idx + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          IconButton(
                            tooltip: 'Filter / Edit',
                            icon: const Icon(Icons.auto_fix_high_rounded,
                                size: 19),
                            onPressed: () => _reEditPage(idx),
                          ),
                          IconButton(
                            tooltip: 'Rotate 90°',
                            icon: const Icon(Icons.rotate_right_rounded,
                                size: 19),
                            onPressed: () => _rotatePage(idx),
                          ),
                          IconButton(
                            tooltip: 'Remove Page',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _deletePage(idx),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_isBusy)
            Container(
              color: Colors.black38,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Processing HD PDF...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBusy ? null : _addMorePages,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add Pages'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isBusy ? null : _exportPdf,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E56F0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Share PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FullScreenPhotoViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  final String title;

  const FullScreenPhotoViewer({
    super.key,
    required this.imagePaths,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${widget.title} (${_index + 1}/${widget.imagePaths.length})',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagePaths.length,
        onPageChanged: (int i) => setState(() => _index = i),
        itemBuilder: (BuildContext ctx, int idx) {
          final String p = widget.imagePaths[idx];
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 5.0,
            child: Center(
              child: File(p).existsSync()
                  ? Image.file(File(p), fit: BoxFit.contain)
                  : const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 54,
                    ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 9. PDF STUDIO & MERGER SCREEN
// ============================================================================

class PdfStudioScreen extends StatefulWidget {
  final List<DocumentModel> docs;
  final Future<void> Function() onRefresh;

  const PdfStudioScreen({
    super.key,
    required this.docs,
    required this.onRefresh,
  });

  @override
  State<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends State<PdfStudioScreen> {
  final Set<String> _selectedDocIds = <String>{};
  bool _isMerging = false;

  Future<void> _mergeSelectedDocs() async {
    if (_selectedDocIds.length < 2 || _isMerging) return;

    final TextEditingController ctrl = TextEditingController(
      text: 'Merged_${DateFormat('ddMMM_HHmm').format(DateTime.now())}',
    );
    final String? mergedTitle = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Merge into One PDF'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Merged PDF File Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Merge & Share'),
          ),
        ],
      ),
    );

    if (mergedTitle == null || mergedTitle.isEmpty) return;

    setState(() => _isMerging = true);
    try {
      final pw.Document pdf = pw.Document();
      final List<DocumentModel> orderedDocs = widget.docs
          .where((DocumentModel d) => _selectedDocIds.contains(d.id))
          .toList();

      for (final DocumentModel doc in orderedDocs) {
        for (final String path in doc.imagePaths) {
          final File f = File(path);
          if (!await f.exists()) continue;
          final Uint8List bytes = await f.readAsBytes();
          final pw.MemoryImage pdfImg = pw.MemoryImage(bytes);
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(8),
              build: (pw.Context ctx) {
                return pw.Center(
                  child: pw.Image(pdfImg, fit: pw.BoxFit.contain),
                );
              },
            ),
          );
        }
      }

      final String outPath =
          await DocumentStorageService.createUniquePdfPath(mergedTitle);
      await File(outPath).writeAsBytes(await pdf.save());

      if (mounted) {
        setState(() {
          _isMerging = false;
          _selectedDocIds.clear();
        });
      }

      await Share.shareXFiles(
        <XFile>[XFile(outPath)],
        text: '$mergedTitle.pdf',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isMerging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF merge failed: $e')),
        );
      }
    }
  }

  Future<void> _exportSingleDocPdf(DocumentModel doc) async {
    setState(() => _isMerging = true);
    try {
      final pw.Document pdf = pw.Document();
      for (final String path in doc.imagePaths) {
        final File f = File(path);
        if (!await f.exists()) continue;
        final Uint8List bytes = await f.readAsBytes();
        final pw.MemoryImage pdfImg = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(8),
            build: (pw.Context ctx) {
              return pw.Center(
                child: pw.Image(pdfImg, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      final String outPath =
          await DocumentStorageService.createUniquePdfPath(doc.title);
      await File(outPath).writeAsBytes(await pdf.save());

      if (mounted) setState(() => _isMerging = false);

      await Share.shareXFiles(
        <XFile>[XFile(outPath)],
        text: '${doc.title}.pdf',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isMerging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Studio & Merger'),
        actions: <Widget>[
          if (_selectedDocIds.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _selectedDocIds.clear()),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: widget.docs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 64,
                      color: Color(0xFF9CA3AF),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'No Scanned Docs Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Scan documents first to merge multiple scans into a single clean HD PDF.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[
                            Color(0xFF1E56F0),
                            Color(0xFF0EA5E9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: <Widget>[
                          Icon(
                            Icons.merge_type_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Multi-Document PDF Merger',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tick 2 or more documents to combine them into one crisp A4 PDF, or tap the PDF icon to export singly.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: widget.onRefresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: widget.docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext ctx, int idx) {
                            final DocumentModel doc = widget.docs[idx];
                            final bool checked =
                                _selectedDocIds.contains(doc.id);
                            final String thumb = doc.imagePaths.first;

                            return Card(
                              child: ListTile(
                                onTap: () {
                                  setState(() {
                                    if (checked) {
                                      _selectedDocIds.remove(doc.id);
                                    } else {
                                      _selectedDocIds.add(doc.id);
                                    }
                                  });
                                },
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Checkbox(
                                      value: checked,
                                      activeColor: const Color(0xFF1E56F0),
                                      onChanged: (bool? v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedDocIds.add(doc.id);
                                          } else {
                                            _selectedDocIds.remove(doc.id);
                                          }
                                        });
                                      },
                                    ),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 42,
                                        height: 54,
                                        child: File(thumb).existsSync()
                                            ? Image.file(
                                                File(thumb),
                                                fit: BoxFit.cover,
                                                cacheWidth: 140,
                                              )
                                            : const Icon(
                                                Icons.broken_image_outlined,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  doc.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${doc.imagePaths.length} page${doc.imagePaths.length > 1 ? 's' : ''} • ${doc.tag}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Export Single PDF',
                                  icon: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Color(0xFF1E56F0),
                                  ),
                                  onPressed: _isMerging
                                      ? null
                                      : () => _exportSingleDocPdf(doc),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isMerging)
                  Container(
                    color: Colors.black38,
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Building HD PDF...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: _selectedDocIds.length >= 2
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: FilledButton.icon(
                  onPressed: _isMerging ? null : _mergeSelectedDocs,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E56F0),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: const Icon(Icons.merge_type_rounded),
                  label: Text(
                    'Merge ${_selectedDocIds.length} Documents into PDF',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ============================================================================
// 10. SETTINGS & ENGINE PREFERENCES SCREEN
// ============================================================================

class SettingsScreen extends StatelessWidget {
  final Map<String, dynamic> settings;
  final Future<void> Function(Map<String, dynamic> updated) onSettingsChanged;
  final Future<void> Function() onClearAllDocs;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.onClearAllDocs,
  });

  @override
  Widget build(BuildContext context) {
    final String defaultFilter =
        (settings['defaultFilter'] as String?) ?? 'magic_pro';
    final String pdfQuality =
        (settings['pdfQuality'] as String?) ?? 'High (2400px)';
    final bool autoEnhance = (settings['autoEnhance'] as bool?) ?? true;

    final DocFilterOption activeFilterObj = kDocFilters.firstWhere(
      (DocFilterOption f) => f.id == defaultFilter,
      orElse: () => kDocFilters[1],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'SCANNER DEFAULTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
                letterSpacing: 0.7,
              ),
            ),
          ),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(
                    Icons.auto_fix_high_rounded,
                    color: Color(0xFF1E56F0),
                  ),
                  title: const Text('Default Scan Filter'),
                  subtitle: Text(activeFilterObj.name),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final String? picked = await showModalBottomSheet<String>(
                      context: context,
                      showDragHandle: true,
                      builder: (BuildContext ctx) => SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: <Widget>[
                            const Padding(
                              padding: EdgeInsets.all(14),
                              child: Text(
                                'Choose Default Filter',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...kDocFilters.map((DocFilterOption opt) {
                              return ListTile(
                                leading: Icon(opt.icon),
                                title: Text(opt.name),
                                trailing: opt.id == defaultFilter
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF1E56F0),
                                      )
                                    : null,
                                onTap: () => Navigator.pop(ctx, opt.id),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                    if (picked != null) {
                      final Map<String, dynamic> updated =
                          Map<String, dynamic>.from(settings);
                      updated['defaultFilter'] = picked;
                      await onSettingsChanged(updated);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.high_quality_rounded,
                    color: Color(0xFF1E56F0),
                  ),
                  title: const Text('Scan & PDF Resolution'),
                  subtitle: Text(pdfQuality),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final List<String> options = <String>[
                      'Balanced (1800px)',
                      'High (2400px)',
                      'Ultra (3000px)',
                    ];
                    final String? picked = await showModalBottomSheet<String>(
                      context: context,
                      showDragHandle: true,
                      builder: (BuildContext ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Padding(
                              padding: EdgeInsets.all(14),
                              child: Text(
                                'Select Output Quality',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...options.map((String q) {
                              return ListTile(
                                title: Text(q),
                                trailing: q == pdfQuality
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF1E56F0),
                                      )
                                    : null,
                                onTap: () => Navigator.pop(ctx, q),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                    if (picked != null) {
                      final Map<String, dynamic> updated =
                          Map<String, dynamic>.from(settings);
                      updated['pdfQuality'] = picked;
                      await onSettingsChanged(updated);
                    }
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF1E56F0),
                  ),
                  title: const Text('Auto-Enhance on Capture'),
                  subtitle: const Text(
                    'Apply YCbCr shadow wipe & crisp ink automatically',
                  ),
                  value: autoEnhance,
                  activeColor: const Color(0xFF1E56F0),
                  onChanged: (bool v) async {
                    final Map<String, dynamic> updated =
                        Map<String, dynamic>.from(settings);
                    updated['autoEnhance'] = v;
                    await onSettingsChanged(updated);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'PRO IMAGE ENGINE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
                letterSpacing: 0.7,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.verified_rounded, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text(
                        'On-Device YCbCr Scanner Engine v2',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• YCbCr Chroma Denoise removes camera grain without blurring fine Hindi/English text\n'
                    '• Luminance-only 2D Illumination Field removes hand & fold shadows while keeping blue ink vivid\n'
                    '• Multi-scale Sauvola B&W Pro protects bold headings & QR codes from hollowing\n'
                    '• Resolution-independent edge sharpening matches 900px preview to 2400px–3000px export',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF4B5563),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'STORAGE & DATA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
                letterSpacing: 0.7,
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Clear All Scanned Documents',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text('Frees all local scanned images & PDFs'),
              onTap: () async {
                final bool? ok = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext ctx) => AlertDialog(
                    title: const Text('Clear Everything?'),
                    content: const Text(
                      'All saved documents and pages will be permanently deleted from this device.',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete All'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await onClearAllDocs();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All documents cleared'),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
