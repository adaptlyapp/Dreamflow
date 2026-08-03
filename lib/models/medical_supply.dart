/// A medical supply or equipment item with instructional resources
class MedicalSupply {
  final String id;
  final String name;
  final String category;
  final String description;
  final String whoUsesIt;
  final List<String> commonBrands;
  final List<InstructionalResource> resources;
  final MaintenanceInfo? maintenance;
  final String? troubleshooting;
  final List<ObtainmentOption> whereToObtain;
  final InsuranceInfo? insuranceInfo;
  final String? iconEmoji;

  const MedicalSupply({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.whoUsesIt,
    this.commonBrands = const [],
    this.resources = const [],
    this.maintenance,
    this.troubleshooting,
    this.whereToObtain = const [],
    this.insuranceInfo,
    this.iconEmoji,
  });

  bool matchesQuery(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q)) return true;
    if (description.toLowerCase().contains(q)) return true;
    if (category.toLowerCase().contains(q)) return true;
    if (whoUsesIt.toLowerCase().contains(q)) return true;
    for (final brand in commonBrands) {
      if (brand.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

class InstructionalResource {
  final String title;
  final String url;
  final ResourceType type;
  final String? description;

  const InstructionalResource({
    required this.title,
    required this.url,
    required this.type,
    this.description,
  });
}

enum ResourceType { video, article, guide, pdf, website }

extension ResourceTypeX on ResourceType {
  String get label {
    switch (this) {
      case ResourceType.video:
        return 'Video';
      case ResourceType.article:
        return 'Article';
      case ResourceType.guide:
        return 'Guide';
      case ResourceType.pdf:
        return 'PDF';
      case ResourceType.website:
        return 'Website';
    }
  }

  String get emoji {
    switch (this) {
      case ResourceType.video:
        return '🎥';
      case ResourceType.article:
        return '📄';
      case ResourceType.guide:
        return '📖';
      case ResourceType.pdf:
        return '📑';
      case ResourceType.website:
        return '🌐';
    }
  }
}

class MaintenanceInfo {
  final String cleaningInstructions;
  final String replacementSchedule;

  const MaintenanceInfo({
    required this.cleaningInstructions,
    required this.replacementSchedule,
  });
}

class ObtainmentOption {
  final String source;
  final String details;

  const ObtainmentOption({
    required this.source,
    required this.details,
  });
}

class InsuranceInfo {
  final String coverage;
  final String tips;

  const InsuranceInfo({
    required this.coverage,
    required this.tips,
  });
}

/// Supply categories for the hub
class SupplyCategory {
  final String id;
  final String name;
  final String emoji;
  final String description;

  const SupplyCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
  });
}
