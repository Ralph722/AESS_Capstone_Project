import 'package:flutter/material.dart';

/// Scales card typography for accessibility without blowing up ID-card layout.
double alumniCardFontSize(BuildContext context, double size) {
  final scaler = MediaQuery.textScalerOf(
    context,
  ).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.35);
  return scaler.scale(size);
}
