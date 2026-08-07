import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Result of the admin map pin picker.
class VenuePinResult {
  const VenuePinResult({this.latitude, this.longitude});

  final double? latitude;
  final double? longitude;

  bool get hasPin =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite;
}

/// Opens a map dialog so admins can drop / adjust a venue pin.
Future<VenuePinResult?> showVenuePinPickerDialog({
  required BuildContext context,
  String venueLabel = '',
  double? initialLatitude,
  double? initialLongitude,
}) {
  return showDialog<VenuePinResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _VenuePinPickerDialog(
      venueLabel: venueLabel,
      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,
    ),
  );
}

class _VenuePinPickerDialog extends StatefulWidget {
  const _VenuePinPickerDialog({
    required this.venueLabel,
    this.initialLatitude,
    this.initialLongitude,
  });

  final String venueLabel;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<_VenuePinPickerDialog> createState() => _VenuePinPickerDialogState();
}

class _VenuePinPickerDialogState extends State<_VenuePinPickerDialog> {
  static const _navy = Color(0xFF090A4F);
  // Default center near USTP Cagayan de Oro (common campus area for this app).
  static const _defaultCenter = LatLng(8.4859, 124.6565);

  late final MapController _mapController;
  LatLng? _pin;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _pin = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng get _center => _pin ?? _defaultCenter;

  Future<void> _searchVenueText() async {
    final q = widget.venueLabel.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a venue name first, then search.')),
      );
      return;
    }
    setState(() => _searching = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'json',
        'limit': '1',
      });
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'alumni_system/1.0 (event-venue-pin)'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Search failed (${response.statusCode})');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No map match found for that venue text.')),
        );
        return;
      }
      final first = decoded.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lon == null) {
        throw Exception('Invalid coordinates');
      }
      final point = LatLng(lat, lon);
      setState(() => _pin = point);
      _mapController.move(point, 16);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not find venue: $e')),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: size.width.clamp(320, 720),
        height: size.height.clamp(420, 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.add_location_alt_outlined, color: _navy),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pin exact location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tap the map to drop or move the pin.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (widget.venueLabel.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Venue: ${widget.venueLabel.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _searching ? null : _searchVenueText,
                      icon: _searching
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search, size: 16),
                      label: const Text('Find from text'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: _pin == null ? 13 : 16,
                      onTap: (_, point) => setState(() => _pin = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'alumni_system',
                      ),
                      if (_pin != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _pin!,
                              width: 44,
                              height: 44,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                Icons.location_on,
                                color: Color(0xFFDC2626),
                                size: 44,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  if (_pin != null)
                    Text(
                      '${_pin!.latitude.toStringAsFixed(5)}, '
                      '${_pin!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const Spacer(),
                  if (_pin != null)
                    TextButton(
                      onPressed: () => setState(() => _pin = null),
                      child: const Text('Clear pin'),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        VenuePinResult(
                          latitude: _pin?.latitude,
                          longitude: _pin?.longitude,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(backgroundColor: _navy),
                    child: Text(_pin == null ? 'Save without pin' : 'Save pin'),
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
