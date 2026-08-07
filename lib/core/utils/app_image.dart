import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Resolves an image value that may be either a Supabase Storage URL
/// (`https://...`) or a legacy base64 data URL (`data:image/...;base64,...`).
class AppImage {
  const AppImage._();

  static final Map<int, Uint8List> _decodedCache = <int, Uint8List>{};
  static const int _maxDecodedCacheEntries = 48;

  static bool isDataUrl(String value) => value.startsWith('data:');

  static Uint8List decodeDataUrl(String value) =>
      base64Decode(value.split(',').last);

  /// Decodes a data URL once and reuses bytes across rebuilds/scroll.
  static Uint8List decodeDataUrlCached(String value) {
    final key = Object.hash(value.length, value.hashCode);
    final cached = _decodedCache[key];
    if (cached != null) return cached;

    final bytes = decodeDataUrl(value);
    if (_decodedCache.length >= _maxDecodedCacheEntries) {
      _decodedCache.remove(_decodedCache.keys.first);
    }
    _decodedCache[key] = bytes;
    return bytes;
  }

  static void clearDecodedCache() => _decodedCache.clear();

  static int? _cachePixels(double? logical, double dpr) {
    if (logical == null) return null;
    return (logical * dpr).round().clamp(1, 4096);
  }

  /// Builds an [ImageProvider] for either format, or null when empty.
  static ImageProvider? provider(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (isDataUrl(value)) {
      return MemoryImage(decodeDataUrlCached(value));
    }
    return NetworkImage(value);
  }

  /// Neutral avatar / logo placeholder used across the alumni portal.
  static Widget placeholder({
    double? width,
    double? height,
    IconData icon = Icons.person_outline,
    Color? color,
  }) {
    final c = color ?? const Color(0xFF090A4F);
    return ColoredBox(
      color: c.withValues(alpha: 0.06),
      child: Center(
        child: Icon(icon, color: c.withValues(alpha: 0.45), size: 28),
      ),
    );
  }

  /// Builds an [Image] widget for either format.
  ///
  /// Decode cache uses **one** dimension only. Passing both [cacheWidth] and
  /// [cacheHeight] forces a decode aspect ratio and warps photos in avatars.
  static Widget widget(
    String value, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
    String? semanticLabel,
    FilterQuality filterQuality = FilterQuality.medium,
  }) {
    final dpr = WidgetsBinding.instance.platformDispatcher.views.isEmpty
        ? 1.0
        : WidgetsBinding
            .instance.platformDispatcher.views.first.devicePixelRatio;

    // Prefer width; if only height is known, use height. Never both.
    // Decode at ~2× display size for sharper avatars on high-DPI screens.
    final int? cacheW;
    final int? cacheH;
    if (width != null) {
      final basis =
          height != null && height > width ? height : width;
      cacheW = _cachePixels(basis * 2, dpr);
      cacheH = null;
    } else if (height != null) {
      cacheW = null;
      cacheH = _cachePixels(height * 2, dpr);
    } else {
      cacheW = null;
      cacheH = null;
    }

    if (isDataUrl(value)) {
      return Image.memory(
        decodeDataUrlCached(value),
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        filterQuality: filterQuality,
        errorBuilder: errorBuilder,
        semanticLabel: semanticLabel,
      );
    }
    return Image.network(
      value,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder ??
          (context, error, stack) => SizedBox(
                width: width,
                height: height,
                child: placeholder(width: width, height: height),
              ),
      semanticLabel: semanticLabel,
    );
  }
}
