// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

// Helper to generate an uncompressed RGBA PNG file directly in pure Dart
void createPng({
  required String filePath,
  required int width,
  required int height,
  required int Function(int x, int y) pixelColor,
}) {
  // Simple PPM or raw byte generation or basic valid PNG
  final rawData = BytesBuilder();
  for (int y = 0; y < height; y++) {
    rawData.addByte(0); // Filter type 0 (None)
    for (int x = 0; x < width; x++) {
      final color = pixelColor(x, y);
      rawData.addByte((color >> 16) & 0xFF); // R
      rawData.addByte((color >> 8) & 0xFF);  // G
      rawData.addByte(color & 0xFF);         // B
      rawData.addByte((color >> 24) & 0xFF); // A
    }
  }

  final uncompressed = rawData.toBytes();
  final compressed = zlibCompress(uncompressed);

  final png = BytesBuilder();
  // PNG Signature
  png.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  // IHDR Chunk
  final ihdr = BytesBuilder();
  ihdr.add(uint32(width));
  ihdr.add(uint32(height));
  ihdr.addByte(8); // Bit depth
  ihdr.addByte(6); // Color type (RGBA)
  ihdr.addByte(0); // Compression method
  ihdr.addByte(0); // Filter method
  ihdr.addByte(0); // Interlace method
  writeChunk(png, 'IHDR', ihdr.toBytes());

  // IDAT Chunk
  writeChunk(png, 'IDAT', compressed);

  // IEND Chunk
  writeChunk(png, 'IEND', Uint8List(0));

  final file = File(filePath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(png.toBytes());
}

List<int> uint32(int val) => [
      (val >> 24) & 0xFF,
      (val >> 16) & 0xFF,
      (val >> 8) & 0xFF,
      val & 0xFF,
    ];

void writeChunk(BytesBuilder png, String type, List<int> data) {
  png.add(uint32(data.length));
  final typeBytes = type.codeUnits;
  png.add(typeBytes);
  png.add(data);

  final crc = calculateCrc([...typeBytes, ...data]);
  png.add(uint32(crc));
}

int calculateCrc(List<int> bytes) {
  int crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (int j = 0; j < 8; j++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc = crc >> 1;
      }
    }
  }
  return crc ^ 0xFFFFFFFF;
}

List<int> zlibCompress(Uint8List data) {
  return zlib.encode(data);
}

void main() {
  const size = 512;

  // 1. App Icon (Shield on Slate Background)
  createPng(
    filePath: 'assets/icons/app_icon.png',
    width: size,
    height: size,
    pixelColor: (x, y) {
      // Shield shape condition
      final inShield = (x >= 128 && x <= 384 && y >= 100 && y <= 320) ||
          (y > 320 && y <= 420 && (x - 256).abs() <= (420 - y) * 1.3);

      if (inShield) {
        // Inner keyhole
        final inKeyholeTop = ((x - 256) * (x - 256) + (y - 230) * (y - 230)) <= 400;
        final inKeyholeBottom = (x >= 244 && x <= 268 && y >= 230 && y <= 310);
        if (inKeyholeTop || inKeyholeBottom) {
          return 0xFF0F172A; // Slate hole
        }
        return 0xFF10B981; // Emerald Shield
      }

      // Background Slate
      return 0xFF0F172A;
    },
  );

  // 2. Foreground Adaptive Icon (Transparent BG)
  createPng(
    filePath: 'assets/icons/app_icon_foreground.png',
    width: size,
    height: size,
    pixelColor: (x, y) {
      final inShield = (x >= 128 && x <= 384 && y >= 100 && y <= 320) ||
          (y > 320 && y <= 420 && (x - 256).abs() <= (420 - y) * 1.3);

      if (inShield) {
        final inKeyholeTop = ((x - 256) * (x - 256) + (y - 230) * (y - 230)) <= 400;
        final inKeyholeBottom = (x >= 244 && x <= 268 && y >= 230 && y <= 310);
        if (inKeyholeTop || inKeyholeBottom) {
          return 0xFF0F172A;
        }
        return 0xFF10B981;
      }
      return 0x00000000; // Transparent
    },
  );

  // 3. Native Splash Graphic
  createPng(
    filePath: 'assets/splash/splash.png',
    width: size,
    height: size,
    pixelColor: (x, y) {
      final inShield = (x >= 140 && x <= 372 && y >= 110 && y <= 310) ||
          (y > 310 && y <= 410 && (x - 256).abs() <= (410 - y) * 1.2);

      if (inShield) {
        final inKeyholeTop = ((x - 256) * (x - 256) + (y - 230) * (y - 230)) <= 350;
        final inKeyholeBottom = (x >= 246 && x <= 266 && y >= 230 && y <= 300);
        if (inKeyholeTop || inKeyholeBottom) {
          return 0xFF0F172A;
        }
        return 0xFF10B981;
      }
      return 0x00000000;
    },
  );

  print('Icons & Splash PNG assets successfully generated.');
}
