import 'package:flutter/material.dart';
import 'package:wellspring/models/pain_detail.dart';
import 'package:wellspring/theme.dart';

class PainMappingWidget extends StatefulWidget {
  final List<PainDetail> initialPainMap;
  final ValueChanged<List<PainDetail>> onChanged;

  const PainMappingWidget({
    super.key,
    required this.initialPainMap,
    required this.onChanged,
  });

  @override
  State<PainMappingWidget> createState() => _PainMappingWidgetState();
}

class _PainMappingWidgetState extends State<PainMappingWidget> {
  bool _expanded = false;
  late List<PainDetail> _painMap;

  @override
  void initState() {
    super.initState();
    _painMap = List.from(widget.initialPainMap);
    _expanded = _painMap.isNotEmpty;
  }

  void _toggleArea(String area) async {
    final existing = _painMap.firstWhere(
      (p) => p.area == area,
      orElse: () => PainDetail(area: area, type: PainTypes.ache, intensity: 5),
    );

    final isNew = !_painMap.any((p) => p.area == area);

    if (isNew) {
      // Show detail modal for new area
      final result = await showModalBottomSheet<PainDetail>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PainDetailModal(area: area),
      );

      if (result != null) {
        setState(() {
          _painMap.add(result);
          widget.onChanged(_painMap);
        });
      }
    } else {
      // Show modal to edit or remove
      final result = await showModalBottomSheet<PainDetail?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PainDetailModal(area: area, existing: existing),
      );

      setState(() {
        if (result == null) {
          // Remove if user deleted
          _painMap.removeWhere((p) => p.area == area);
        } else {
          // Update existing
          final index = _painMap.indexWhere((p) => p.area == area);
          _painMap[index] = result;
        }
        widget.onChanged(_painMap);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with expand button
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: cs.primary,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Pain Location & Type',
                    style: context.textStyles.titleMedium?.semiBold,
                  ),
                ),
                if (_painMap.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_painMap.length}',
                      style: context.textStyles.labelSmall?.semiBold.withColor(cs.primary),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Expanded content
        if (_expanded) ...[
          SizedBox(height: AppSpacing.md),
          
          // Body diagram
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tap body regions to record pain details (49 clinical zones)',
                    style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                  ),
                  SizedBox(height: AppSpacing.md),
                  BodyDiagram(
                    selectedAreas: _painMap.map((p) => p.area).toList(),
                    onAreaTap: _toggleArea,
                  ),
                ],
              ),
            ),
          ),

          // Pain summary
          if (_painMap.isNotEmpty) ...[
            SizedBox(height: AppSpacing.md),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: AppSpacing.paddingLg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list_alt, color: cs.primary, size: 20),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'Pain Details',
                          style: context.textStyles.titleMedium?.semiBold,
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.md),
                    ..._painMap.map((pain) => Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: PainSummaryItem(
                        pain: pain,
                        onTap: () => _toggleArea(pain.area),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class BodyDiagram extends StatelessWidget {
  final List<String> selectedAreas;
  final ValueChanged<String> onAreaTap;

  const BodyDiagram({
    super.key,
    required this.selectedAreas,
    required this.onAreaTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Image.asset(
        'assets/images/ChatGPT_Image_Feb_17_2026_02_10_51_PM.png',
        width: 400,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame == null) return child;
          
          return Stack(
            alignment: Alignment.center,
            children: [
              child,
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    onTapUp: (details) {
                      final RenderBox box = context.findRenderObject() as RenderBox;
                      final localPosition = box.globalToLocal(details.globalPosition);
                      final area = _getAreaFromPosition(localPosition, box.size);
                      if (area != null) {
                        onAreaTap(area);
                      }
                    },
                    child: CustomPaint(
                      painter: _BodyOverlayPainter(
                        selectedAreas: selectedAreas,
                        colorScheme: cs,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _getAreaFromPosition(Offset position, Size size) {
    final x = position.dx;
    final y = position.dy;
    final width = size.width;
    final height = size.height;

    // Image has front view on left, back view on right
    final isFront = x < width * 0.5;
    
    // Normalize coordinates for each half
    final normalizedX = isFront ? (x / (width * 0.5)) : ((x - width * 0.5) / (width * 0.5));
    final normalizedY = y / height;

    // Define clickable regions matching the exact image layout
    final regions = isFront ? _getFrontRegions() : _getBackRegions();

    for (final region in regions) {
      if (normalizedX >= region.left && 
          normalizedX <= region.left + region.width &&
          normalizedY >= region.top && 
          normalizedY <= region.top + region.height) {
        return region.area;
      }
    }

    return null;
  }

  List<_HitRegion> _getFrontRegions() => [
    // Zone 1-2: Head – Forehead
    _HitRegion(BodyAreas.headFront, 0.32, 0.06, 0.36, 0.10),
    // Zone 3: Neck / Throat
    _HitRegion(BodyAreas.neckFront, 0.42, 0.15, 0.16, 0.04),
    // Zone 4: Left Upper Chest (Pectoral)
    _HitRegion(BodyAreas.chestLeft, 0.30, 0.19, 0.20, 0.10),
    // Zone 5: Right Upper Chest (Pectoral)
    _HitRegion(BodyAreas.chestRight, 0.50, 0.19, 0.20, 0.10),
    // Zone 6: Left Upper Arm
    _HitRegion(BodyAreas.leftUpperArm, 0.08, 0.22, 0.18, 0.12),
    // Zone 7: Right Upper Arm
    _HitRegion(BodyAreas.rightUpperArm, 0.74, 0.22, 0.18, 0.12),
    // Zone 9: Left Forearm
    _HitRegion(BodyAreas.leftForearm, 0.04, 0.34, 0.16, 0.12),
    // Right Forearm (mirrored)
    _HitRegion(BodyAreas.rightForearm, 0.80, 0.34, 0.16, 0.12),
    // Zone 11: Hands / Wrists
    _HitRegion(BodyAreas.leftHandPalm, 0.02, 0.46, 0.14, 0.10),
    _HitRegion(BodyAreas.rightHandPalm, 0.84, 0.46, 0.14, 0.10),
    // Zone 12: Left Upper Abdomen
    _HitRegion(BodyAreas.abdomenLeft, 0.38, 0.29, 0.12, 0.09),
    // Zone 13: Right Upper Abdomen
    _HitRegion(BodyAreas.abdomenRight, 0.50, 0.29, 0.12, 0.09),
    // Zone 14: Left Lower Abdomen
    _HitRegion(BodyAreas.abdomenUpper, 0.38, 0.38, 0.12, 0.09),
    // Zone 15: Right Lower Abdomen
    _HitRegion(BodyAreas.abdomenLower, 0.50, 0.38, 0.12, 0.09),
    // Zone 17: Pelvis / Groin / Upper Thigh Joint
    _HitRegion(BodyAreas.leftHipFront, 0.32, 0.47, 0.18, 0.10),
    _HitRegion(BodyAreas.rightHipFront, 0.50, 0.47, 0.18, 0.10),
    // Zone 18: Left Upper Thigh
    _HitRegion(BodyAreas.leftThighFront, 0.30, 0.57, 0.16, 0.12),
    // Zone 18: Right Upper Thigh
    _HitRegion(BodyAreas.rightThighFront, 0.54, 0.57, 0.16, 0.12),
    // Zone 21: Left Knee / Upper Shin
    _HitRegion(BodyAreas.leftKnee, 0.30, 0.69, 0.16, 0.09),
    // Zone 22: Right Knee / Upper Shin
    _HitRegion(BodyAreas.rightKnee, 0.54, 0.69, 0.16, 0.09),
    // Zone 29: Left Lower Shin / Calf (Front)
    _HitRegion(BodyAreas.leftCalfFront, 0.30, 0.78, 0.16, 0.12),
    // Right Lower Shin / Calf (Front)
    _HitRegion(BodyAreas.rightCalfFront, 0.54, 0.78, 0.16, 0.12),
    // Feet
    _HitRegion(BodyAreas.leftFootTop, 0.30, 0.90, 0.14, 0.06),
    _HitRegion(BodyAreas.rightFootTop, 0.56, 0.90, 0.14, 0.06),
  ];

  List<_HitRegion> _getBackRegions() => [
    // Region 23-24: Head back
    _HitRegion(BodyAreas.headBack, 0.32, 0.06, 0.36, 0.10),
    // Region 24: Neck back
    _HitRegion(BodyAreas.neckBack, 0.42, 0.15, 0.16, 0.04),
    // Region 25: Left shoulder back
    _HitRegion(BodyAreas.leftShoulderBack, 0.18, 0.19, 0.22, 0.09),
    // Region 27: Right shoulder back
    _HitRegion(BodyAreas.rightShoulderBack, 0.60, 0.19, 0.22, 0.09),
    // Region 30: Left hand back
    _HitRegion(BodyAreas.leftHandBack, 0.02, 0.52, 0.16, 0.11),
    // Region 31: Right hand back
    _HitRegion(BodyAreas.rightHandBack, 0.82, 0.52, 0.16, 0.11),
    // Region 36: Left upper back
    _HitRegion(BodyAreas.upperBackLeft, 0.30, 0.28, 0.20, 0.10),
    // Region 37: Right upper back
    _HitRegion(BodyAreas.upperBackRight, 0.50, 0.28, 0.20, 0.10),
    // Region 36: Left middle back
    _HitRegion(BodyAreas.middleBackLeft, 0.38, 0.38, 0.12, 0.09),
    // Region 37: Right middle back
    _HitRegion(BodyAreas.middleBackRight, 0.50, 0.38, 0.12, 0.09),
    // Region 40: Left lower back
    _HitRegion(BodyAreas.lowerBackLeft, 0.38, 0.47, 0.12, 0.09),
    // Region 39: Right lower back
    _HitRegion(BodyAreas.lowerBackRight, 0.50, 0.47, 0.12, 0.09),
    // Region 43: Left hip back
    _HitRegion(BodyAreas.leftHipBack, 0.32, 0.56, 0.18, 0.10),
    // Region 42: Right hip back
    _HitRegion(BodyAreas.rightHipBack, 0.50, 0.56, 0.18, 0.10),
    // Region 43: Left thigh back (upper)
    _HitRegion(BodyAreas.leftThighBack, 0.30, 0.66, 0.16, 0.12),
    // Region 42: Right thigh back (upper)
    _HitRegion(BodyAreas.rightThighBack, 0.54, 0.66, 0.16, 0.12),
    // Region 43: Left calf back
    _HitRegion(BodyAreas.leftCalfBack, 0.30, 0.85, 0.16, 0.10),
    // Region 42: Right calf back
    _HitRegion(BodyAreas.rightCalfBack, 0.54, 0.85, 0.16, 0.10),
    // Region 47: Left foot bottom
    _HitRegion(BodyAreas.leftFootBottom, 0.30, 0.95, 0.16, 0.04),
    // Region 48: Right foot bottom
    _HitRegion(BodyAreas.rightFootBottom, 0.54, 0.95, 0.16, 0.04),
  ];
}

class _HitRegion {
  final String area;
  final double left;
  final double top;
  final double width;
  final double height;

  _HitRegion(this.area, this.left, this.top, this.width, this.height);
}

class _BodyOverlayPainter extends CustomPainter {
  final List<String> selectedAreas;
  final ColorScheme colorScheme;

  _BodyOverlayPainter({
    required this.selectedAreas,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedAreas.isEmpty) return;

    final selectedColor = const Color(0xFFEF4444).withValues(alpha: 0.35); // Red with transparency
    final borderColor = const Color(0xFFEF4444);

    final paint = Paint()
      ..color = selectedColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw highlights for selected areas
    for (final area in selectedAreas) {
      final region = _getRegionForArea(area);
      if (region != null) {
        final isFront = _isFrontArea(area);
        final halfWidth = size.width * 0.5;
        final xOffset = isFront ? 0.0 : halfWidth;
        
        final rect = Rect.fromLTWH(
          xOffset + region.left * halfWidth,
          region.top * size.height,
          region.width * halfWidth,
          region.height * size.height,
        );

        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
        canvas.drawRRect(rrect, paint);
        canvas.drawRRect(rrect, borderPaint);

        // Draw checkmark
        final center = rect.center;
        final checkPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;

        final checkSize = rect.width * 0.3;
        final checkPath = Path()
          ..moveTo(center.dx - checkSize * 0.4, center.dy)
          ..lineTo(center.dx - checkSize * 0.1, center.dy + checkSize * 0.3)
          ..lineTo(center.dx + checkSize * 0.4, center.dy - checkSize * 0.3);

        canvas.drawPath(checkPath, checkPaint);
      }
    }
  }

  bool _isFrontArea(String area) {
    return area.contains('front') || 
           area == BodyAreas.headFront ||
           area == BodyAreas.neckFront ||
           area.contains('palm') ||
           area.contains('chest') ||
           area.contains('abdomen') ||
           area.contains('forearm') ||
           area == BodyAreas.leftKnee ||
           area == BodyAreas.rightKnee ||
           area == BodyAreas.leftFootTop ||
           area == BodyAreas.rightFootTop;
  }

  _HitRegion? _getRegionForArea(String area) {
    final frontRegions = _getFrontRegions();
    final backRegions = _getBackRegions();
    
    for (final region in [...frontRegions, ...backRegions]) {
      if (region.area == area) return region;
    }
    return null;
  }

  List<_HitRegion> _getFrontRegions() => [
    // Zone 1-2: Head – Forehead
    _HitRegion(BodyAreas.headFront, 0.32, 0.06, 0.36, 0.10),
    // Zone 3: Neck / Throat
    _HitRegion(BodyAreas.neckFront, 0.42, 0.15, 0.16, 0.04),
    // Zone 4: Left Upper Chest (Pectoral)
    _HitRegion(BodyAreas.chestLeft, 0.30, 0.19, 0.20, 0.10),
    // Zone 5: Right Upper Chest (Pectoral)
    _HitRegion(BodyAreas.chestRight, 0.50, 0.19, 0.20, 0.10),
    // Zone 6: Left Upper Arm
    _HitRegion(BodyAreas.leftUpperArm, 0.08, 0.22, 0.18, 0.12),
    // Zone 7: Right Upper Arm
    _HitRegion(BodyAreas.rightUpperArm, 0.74, 0.22, 0.18, 0.12),
    // Zone 9: Left Forearm
    _HitRegion(BodyAreas.leftForearm, 0.04, 0.34, 0.16, 0.12),
    // Right Forearm (mirrored)
    _HitRegion(BodyAreas.rightForearm, 0.80, 0.34, 0.16, 0.12),
    // Zone 11: Hands / Wrists
    _HitRegion(BodyAreas.leftHandPalm, 0.02, 0.46, 0.14, 0.10),
    _HitRegion(BodyAreas.rightHandPalm, 0.84, 0.46, 0.14, 0.10),
    // Zone 12: Left Upper Abdomen
    _HitRegion(BodyAreas.abdomenLeft, 0.38, 0.29, 0.12, 0.09),
    // Zone 13: Right Upper Abdomen
    _HitRegion(BodyAreas.abdomenRight, 0.50, 0.29, 0.12, 0.09),
    // Zone 14: Left Lower Abdomen
    _HitRegion(BodyAreas.abdomenUpper, 0.38, 0.38, 0.12, 0.09),
    // Zone 15: Right Lower Abdomen
    _HitRegion(BodyAreas.abdomenLower, 0.50, 0.38, 0.12, 0.09),
    // Zone 17: Pelvis / Groin / Upper Thigh Joint
    _HitRegion(BodyAreas.leftHipFront, 0.32, 0.47, 0.18, 0.10),
    _HitRegion(BodyAreas.rightHipFront, 0.50, 0.47, 0.18, 0.10),
    // Zone 18: Left Upper Thigh
    _HitRegion(BodyAreas.leftThighFront, 0.30, 0.57, 0.16, 0.12),
    // Zone 18: Right Upper Thigh
    _HitRegion(BodyAreas.rightThighFront, 0.54, 0.57, 0.16, 0.12),
    // Zone 21: Left Knee / Upper Shin
    _HitRegion(BodyAreas.leftKnee, 0.30, 0.69, 0.16, 0.09),
    // Zone 22: Right Knee / Upper Shin
    _HitRegion(BodyAreas.rightKnee, 0.54, 0.69, 0.16, 0.09),
    // Zone 29: Left Lower Shin / Calf (Front)
    _HitRegion(BodyAreas.leftCalfFront, 0.30, 0.78, 0.16, 0.12),
    // Right Lower Shin / Calf (Front)
    _HitRegion(BodyAreas.rightCalfFront, 0.54, 0.78, 0.16, 0.12),
    // Feet
    _HitRegion(BodyAreas.leftFootTop, 0.30, 0.90, 0.14, 0.06),
    _HitRegion(BodyAreas.rightFootTop, 0.56, 0.90, 0.14, 0.06),
  ];

  List<_HitRegion> _getBackRegions() => [
    _HitRegion(BodyAreas.headBack, 0.32, 0.06, 0.36, 0.10),
    _HitRegion(BodyAreas.neckBack, 0.42, 0.15, 0.16, 0.04),
    _HitRegion(BodyAreas.leftShoulderBack, 0.18, 0.19, 0.22, 0.09),
    _HitRegion(BodyAreas.rightShoulderBack, 0.60, 0.19, 0.22, 0.09),
    _HitRegion(BodyAreas.leftHandBack, 0.02, 0.52, 0.16, 0.11),
    _HitRegion(BodyAreas.rightHandBack, 0.82, 0.52, 0.16, 0.11),
    _HitRegion(BodyAreas.upperBackLeft, 0.30, 0.28, 0.20, 0.10),
    _HitRegion(BodyAreas.upperBackRight, 0.50, 0.28, 0.20, 0.10),
    _HitRegion(BodyAreas.middleBackLeft, 0.38, 0.38, 0.12, 0.09),
    _HitRegion(BodyAreas.middleBackRight, 0.50, 0.38, 0.12, 0.09),
    _HitRegion(BodyAreas.lowerBackLeft, 0.38, 0.47, 0.12, 0.09),
    _HitRegion(BodyAreas.lowerBackRight, 0.50, 0.47, 0.12, 0.09),
    _HitRegion(BodyAreas.leftHipBack, 0.32, 0.56, 0.18, 0.10),
    _HitRegion(BodyAreas.rightHipBack, 0.50, 0.56, 0.18, 0.10),
    _HitRegion(BodyAreas.leftThighBack, 0.30, 0.66, 0.16, 0.12),
    _HitRegion(BodyAreas.rightThighBack, 0.54, 0.66, 0.16, 0.12),
    _HitRegion(BodyAreas.leftCalfBack, 0.30, 0.85, 0.16, 0.10),
    _HitRegion(BodyAreas.rightCalfBack, 0.54, 0.85, 0.16, 0.10),
    _HitRegion(BodyAreas.leftFootBottom, 0.30, 0.95, 0.16, 0.04),
    _HitRegion(BodyAreas.rightFootBottom, 0.54, 0.95, 0.16, 0.04),
  ];

  @override
  bool shouldRepaint(covariant _BodyOverlayPainter oldDelegate) =>
      selectedAreas != oldDelegate.selectedAreas;
}

class InteractiveBodyDiagram extends StatelessWidget {
  final String imagePath;
  final bool isFront;
  final List<String> selectedAreas;
  final ValueChanged<String> onAreaTap;

  const InteractiveBodyDiagram({
    super.key,
    required this.imagePath,
    required this.isFront,
    required this.selectedAreas,
    required this.onAreaTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width * 2.5; // Approximate body aspect ratio

        // Define clickable regions as percentages of the image dimensions
        final regions = isFront ? _getFrontRegions() : _getBackRegions();

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              // Body silhouette image
              Positioned.fill(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  color: cs.onSurface.withValues(alpha: 0.15),
                ),
              ),

              // Clickable areas
              ...regions.map((region) {
                final isSelected = selectedAreas.contains(region.area);
                return Positioned(
                  left: region.left * width,
                  top: region.top * height,
                  width: region.width * width,
                  height: region.height * height,
                  child: GestureDetector(
                    onTap: () => onAreaTap(region.area),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primary.withValues(alpha: 0.3)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? cs.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(region.radius),
                      ),
                      child: isSelected
                          ? Center(
                              child: Icon(
                                Icons.check_circle,
                                color: cs.primary,
                                size: 16,
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  List<_BodyRegion> _getFrontRegions() => [
    _BodyRegion(area: BodyAreas.head, left: 0.35, top: 0.02, width: 0.3, height: 0.08, radius: 50),
    _BodyRegion(area: BodyAreas.neck, left: 0.38, top: 0.10, width: 0.24, height: 0.04, radius: 8),
    _BodyRegion(area: BodyAreas.leftShoulder, left: 0.15, top: 0.14, width: 0.22, height: 0.08, radius: 12),
    _BodyRegion(area: BodyAreas.rightShoulder, left: 0.63, top: 0.14, width: 0.22, height: 0.08, radius: 12),
    _BodyRegion(area: BodyAreas.leftArm, left: 0.10, top: 0.22, width: 0.14, height: 0.16, radius: 8),
    _BodyRegion(area: BodyAreas.rightArm, left: 0.76, top: 0.22, width: 0.14, height: 0.16, radius: 8),
    _BodyRegion(area: BodyAreas.chest, left: 0.30, top: 0.20, width: 0.40, height: 0.14, radius: 12),
    _BodyRegion(area: BodyAreas.abdomen, left: 0.32, top: 0.34, width: 0.36, height: 0.12, radius: 12),
    _BodyRegion(area: BodyAreas.leftHand, left: 0.06, top: 0.38, width: 0.12, height: 0.10, radius: 12),
    _BodyRegion(area: BodyAreas.rightHand, left: 0.82, top: 0.38, width: 0.12, height: 0.10, radius: 12),
    _BodyRegion(area: BodyAreas.leftHip, left: 0.30, top: 0.46, width: 0.18, height: 0.10, radius: 8),
    _BodyRegion(area: BodyAreas.rightHip, left: 0.52, top: 0.46, width: 0.18, height: 0.10, radius: 8),
    _BodyRegion(area: BodyAreas.leftThigh, left: 0.28, top: 0.56, width: 0.18, height: 0.16, radius: 8),
    _BodyRegion(area: BodyAreas.rightThigh, left: 0.54, top: 0.56, width: 0.18, height: 0.16, radius: 8),
    _BodyRegion(area: BodyAreas.leftKnee, left: 0.28, top: 0.72, width: 0.16, height: 0.08, radius: 12),
    _BodyRegion(area: BodyAreas.rightKnee, left: 0.56, top: 0.72, width: 0.16, height: 0.08, radius: 12),
    _BodyRegion(area: BodyAreas.leftCalf, left: 0.28, top: 0.80, width: 0.14, height: 0.12, radius: 8),
    _BodyRegion(area: BodyAreas.rightCalf, left: 0.58, top: 0.80, width: 0.14, height: 0.12, radius: 8),
    _BodyRegion(area: BodyAreas.leftFoot, left: 0.26, top: 0.92, width: 0.16, height: 0.06, radius: 8),
    _BodyRegion(area: BodyAreas.rightFoot, left: 0.58, top: 0.92, width: 0.16, height: 0.06, radius: 8),
  ];

  List<_BodyRegion> _getBackRegions() => [
    _BodyRegion(area: BodyAreas.head, left: 0.35, top: 0.02, width: 0.3, height: 0.08, radius: 50),
    _BodyRegion(area: BodyAreas.neck, left: 0.38, top: 0.10, width: 0.24, height: 0.04, radius: 8),
    _BodyRegion(area: BodyAreas.leftShoulder, left: 0.63, top: 0.14, width: 0.22, height: 0.08, radius: 12),
    _BodyRegion(area: BodyAreas.rightShoulder, left: 0.15, top: 0.14, width: 0.22, height: 0.08, radius: 12),
    _BodyRegion(area: BodyAreas.upperBack, left: 0.30, top: 0.20, width: 0.40, height: 0.14, radius: 12),
    _BodyRegion(area: BodyAreas.lowerBack, left: 0.32, top: 0.34, width: 0.36, height: 0.12, radius: 12),
  ];
}

class _BodyRegion {
  final String area;
  final double left;
  final double top;
  final double width;
  final double height;
  final double radius;

  _BodyRegion({
    required this.area,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.radius,
  });
}

class PainSummaryItem extends StatelessWidget {
  final PainDetail pain;
  final VoidCallback onTap;

  const PainSummaryItem({super.key, required this.pain, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: cs.primary),
                SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    BodyAreas.displayName(pain.area),
                    style: context.textStyles.titleSmall?.semiBold,
                  ),
                ),
                Text(
                  '${pain.intensity}/10',
                  style: context.textStyles.titleSmall?.semiBold.withColor(cs.primary),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              PainTypes.displayName(pain.type),
              style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
            if (pain.note != null && pain.note!.isNotEmpty) ...[
              SizedBox(height: 4),
              Text(
                '"${pain.note}"',
                style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant).copyWith(
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PainDetailModal extends StatefulWidget {
  final String area;
  final PainDetail? existing;

  const PainDetailModal({super.key, required this.area, this.existing});

  @override
  State<PainDetailModal> createState() => _PainDetailModalState();
}

class _PainDetailModalState extends State<PainDetailModal> {
  late String _type;
  late int _intensity;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ?? PainTypes.ache;
    _intensity = widget.existing?.intensity ?? 5;
    _noteController.text = widget.existing?.note ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final result = PainDetail(
      area: widget.area,
      type: _type,
      intensity: _intensity,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );
    Navigator.of(context).pop(result);
  }

  void _delete() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.lg),

              // Title
              Text(
                BodyAreas.displayName(widget.area),
                style: context.textStyles.headlineSmall?.semiBold,
              ),
              SizedBox(height: AppSpacing.lg),

              // Pain type
              Text('Pain Type', style: context.textStyles.titleMedium?.semiBold),
              SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PainTypes.all.map((type) {
                  final selected = _type == type;
                  return ChoiceChip(
                    label: Text(PainTypes.displayName(type)),
                    selected: selected,
                    onSelected: (v) => setState(() => _type = type),
                    selectedColor: cs.primaryContainer,
                    backgroundColor: cs.surfaceContainerHighest,
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              SizedBox(height: AppSpacing.lg),

              // Intensity slider
              Text('Intensity (1-10)', style: context.textStyles.titleMedium?.semiBold),
              SizedBox(height: AppSpacing.sm),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 12,
                  activeTrackColor: cs.primary,
                  inactiveTrackColor: cs.surfaceContainerHighest,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: _intensity.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: _intensity.toString(),
                  onChanged: (value) => setState(() => _intensity = value.toInt()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1', style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)),
                  Text('10', style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)),
                ],
              ),
              SizedBox(height: AppSpacing.lg),

              // Notes
              Text('Notes (Optional)', style: context.textStyles.titleMedium?.semiBold),
              SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: 'e.g., "Worse after sitting"',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                maxLines: 2,
              ),
              SizedBox(height: AppSpacing.xl),

              // Actions
              Row(
                children: [
                  if (widget.existing != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _delete,
                        style: ButtonStyle(
                          foregroundColor: WidgetStatePropertyAll(cs.error),
                          side: WidgetStatePropertyAll(BorderSide(color: cs.error.withValues(alpha: 0.5))),
                        ),
                        child: const Text('Remove'),
                      ),
                    ),
                  if (widget.existing != null) SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
