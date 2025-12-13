import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A widget that displays apparatus-specific icons.
/// This allows easy switching between Material icons and custom icon assets.
class ApparatusIcon extends StatelessWidget {
  final String apparatus;
  final double size;
  final Color? color;

  const ApparatusIcon({
    super.key,
    required this.apparatus,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;
    
    // Check if custom asset exists, otherwise fall back to Material icon
    final assetPath = _getAssetPath(apparatus);
    
    if (assetPath != null) {
      // Use custom SVG asset
      return SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        placeholderBuilder: (context) => Icon(
          _getMaterialIcon(apparatus),
          size: size,
          color: iconColor,
        ),
      );
    }
    
    // Use Material Design icon
    return Icon(
      _getMaterialIcon(apparatus),
      size: size,
      color: iconColor,
    );
  }

  /// Returns the asset path for custom apparatus icons if they exist.
  /// Returns null to use Material icons instead.
  /// 
  /// To use custom icons, place SVG files in assets/icons/ with these names:
  /// - vault.svg
  /// - bars.svg
  /// - beam.svg
  /// - floor_exercise.svg
  /// - other.svg
  String? _getAssetPath(String apparatus) {
    final Map<String, String> assetPaths = {
      'Vault': 'assets/icons/vault.svg',
      'Bars': 'assets/icons/bars.svg',
      'Beam': 'assets/icons/beam.svg',
      'Floor': 'assets/icons/floor.svg',
      'Other': 'assets/icons/other.svg',
    };
    
    // Returns the SVG asset path. Will fall back to Material icons if the file doesn't exist.
    return assetPaths[apparatus];
  }

  /// Material Design icon fallback
  IconData _getMaterialIcon(String apparatus) {
    switch (apparatus) {
      case 'Vault':
        return Icons.table_chart;
      case 'Bars':
        return Icons.event;
      case 'Beam':
        return Icons.straighten;
      case 'Floor':
        return Icons.dashboard;
      default:
        return Icons.category;
    }
  }
}

/// Helper function to get apparatus icon data for use in Icon widgets directly
IconData getApparatusIconData(String? apparatus) {
  switch (apparatus) {
    case 'Vault':
      return Icons.table_chart;
    case 'Bars':
      return Icons.event;
    case 'Beam':
      return Icons.straighten;
    case 'Floor':
      return Icons.dashboard;
    default:
      return Icons.category;
  }
}
