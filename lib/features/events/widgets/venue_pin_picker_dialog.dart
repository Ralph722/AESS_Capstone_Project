import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

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
  return showAdminDialogSurface<VenuePinResult>(
    context: context,
    maxWidth: 720,
    barrierDismissible: false,
    child: _VenuePinPickerDialog(
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
          const SnackBar(
            content: Text('No map match found for that venue text.'),
          ),
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not look up that venue right now. Tap the map to drop a pin manually.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SizedBox(
      height: size.height.clamp(420.0, 640.0).toDouble(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminModalHeader(
            title: 'Pin exact location',
            subtitle: 'Tap the map to drop or move the venue pin.',
            icon: Icons.add_location_alt_outlined,
            onClose: () => Navigator.pop(context),
          ),
          const Divider(height: 1, color: AdminColors.border),
          if (widget.venueLabel.trim().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: AdminColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Venue: ${widget.venueLabel.trim()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _searching ? null : _searchVenueText,
                    style: AdminButtonStyles.outlined(),
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
            const Divider(height: 1, color: AdminColors.border),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
                  border: Border.all(color: AdminColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
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
          ),
          const Divider(height: 1, color: AdminColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(
                          AdminSurfaces.radiusSm,
                        ),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: Text(
                        _pin == null
                            ? 'No pin dropped yet'
                            : '${_pin!.latitude.toStringAsFixed(5)}, '
                                '${_pin!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AdminColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_pin != null) ...[
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => setState(() => _pin = null),
                        style: AdminButtonStyles.ghost(),
                        child: const Text('Clear pin'),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: AdminButtonStyles.outlined(),
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
                      style: AdminButtonStyles.filled(),
                      child: Text(_pin == null ? 'Save without pin' : 'Save pin'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
