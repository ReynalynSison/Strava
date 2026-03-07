import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Reusable map widget that renders a recorded route using CartoDB tiles.
///
/// [interactive] = false → locked map for cards/thumbnails (no pan/zoom).
/// [interactive] = true  → full pan/zoom for Summary screen.
///
/// Auto-fits the camera to show the full route on load.
/// Green dot = start, red dot = end, orange polyline = route.
class RouteMapWidget extends StatefulWidget {
  final List<Map<String, double>> coordinates;
  final bool interactive;
  final double height;

  const RouteMapWidget({
    super.key,
    required this.coordinates,
    this.interactive = true,
    this.height = 220,
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Calculates the center and zoom needed to fit all route points.
  ({LatLng center, double zoom}) _fitBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return (center: const LatLng(0, 0), zoom: 13.0);
    }
    if (points.length == 1) {
      return (center: points.first, zoom: 15.0);
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // Estimate zoom from lat/lng span
    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final span = latSpan > lngSpan ? latSpan : lngSpan;

    double zoom = 15.0;
    if (span > 0.1) zoom = 12.0;
    else if (span > 0.05) zoom = 13.0;
    else if (span > 0.02) zoom = 14.0;
    else if (span > 0.005) zoom = 15.0;
    else zoom = 16.0;

    // Non-interactive mode uses slightly less zoom to show context
    if (!widget.interactive) zoom = (zoom - 0.5).clamp(10.0, 16.0);

    return (center: LatLng(centerLat, centerLng), zoom: zoom);
  }

  @override
  Widget build(BuildContext context) {
    // No route — show placeholder
    if (widget.coordinates.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: widget.height,
          color: CupertinoColors.systemGrey6,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.map, size: 40,
                    color: CupertinoColors.systemGrey2),
                SizedBox(height: 8),
                Text('No route data',
                    style: TextStyle(color: CupertinoColors.secondaryLabel)),
              ],
            ),
          ),
        ),
      );
    }

    final points =
        widget.coordinates.map((c) => LatLng(c['lat']!, c['lng']!)).toList();
    final fit = _fitBounds(points);

    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: fit.center,
            initialZoom: fit.zoom,
            // Disable all gestures in non-interactive mode
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            // ── Tiles ──────────────────────────────────────────────
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.example.strava_like_app',
              retinaMode: MediaQuery.devicePixelRatioOf(context) > 1.0,
            ),

            // ── Route Polyline ─────────────────────────────────────
            if (points.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    color: CupertinoColors.systemOrange,
                    strokeWidth: widget.interactive ? 4.0 : 3.0,
                  ),
                ],
              ),

            // ── Start & End Markers ────────────────────────────────
            MarkerLayer(
              markers: [
                // Start — green
                Marker(
                  point: points.first,
                  width: 14,
                  height: 14,
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: CupertinoColors.white, width: 2),
                    ),
                  ),
                ),
                // End — red
                Marker(
                  point: points.last,
                  width: 14,
                  height: 14,
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: CupertinoColors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

