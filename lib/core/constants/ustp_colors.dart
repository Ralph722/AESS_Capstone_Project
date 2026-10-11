import 'package:flutter/material.dart';

/// Official USTP colour palette (The USTP Branding Manual, section 1.3–1.4).
///
/// Other colours need STRATCOMM approval, so UI themes should build on these.
abstract final class UstpColors {
  // —— Primary ——
  /// USTP Blue. Pantone 274 C · CMYK 100 100 33 35 · RGB 26 23 82.
  static const Color blue = Color(0xFF1A1851);

  /// USTP Gold. Pantone 1235 C · CMYK 1 33 100 0 · RGB 252 179 21.
  static const Color gold = Color(0xFFFCB315);

  // —— Primary greyscale ——
  /// Pantone Black 6 C · CMYK 73 67 65 81 · RGB 21 21 21.
  static const Color black = Color(0xFF151515);

  /// Pantone 421 C · CMYK 31 24 25 0 · RGB 179 179 179.
  static const Color grey = Color(0xFFB3B3B3);

  // —— Secondary ——
  /// Pantone 1585 C · CMYK 0 75 99 0 · RGB 255 100 24.
  static const Color orange = Color(0xFFFF6418);

  /// Pantone 1375 C · CMYK 0 49 98 0 · RGB 255 151 24.
  static const Color lightOrange = Color(0xFFFF9718);

  /// Pantone 296 C · CMYK 92 76 54 67 · RGB 3 28 46.
  static const Color darkNavy = Color(0xFF031C2E);

  /// Pantone 4154 C · CMYK 99 74 30 13 · RGB 13 74 119.
  static const Color midBlue = Color(0xFF0D4A77);

  /// Pantone 279 C · CMYK 69 27 0 0 · RGB 50 157 234.
  static const Color skyBlue = Color(0xFF329DEA);
}
