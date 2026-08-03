/// A trusted educational resource (article, video, anatomy explainer, etc.)
/// surfaced in the Family Education Hub.
class EducationResource {
  final String id;
  final String title;
  final String description;
  final String summary;
  final List<String> keyTakeaways;
  final String whyItMatters;
  final String category;
  final List<String> tags;
  final EducationResourceType type;
  final String sourceName; // e.g. "MedlinePlus"
  final String url;
  final String? thumbnailUrl;
  final int estimatedMinutes;

  const EducationResource({
    required this.id,
    required this.title,
    required this.description,
    required this.summary,
    required this.keyTakeaways,
    required this.whyItMatters,
    required this.category,
    required this.tags,
    required this.type,
    required this.sourceName,
    required this.url,
    this.thumbnailUrl,
    this.estimatedMinutes = 5,
  });

  bool matchesQuery(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q)) return true;
    if (description.toLowerCase().contains(q)) return true;
    if (category.toLowerCase().contains(q)) return true;
    if (sourceName.toLowerCase().contains(q)) return true;
    for (final t in tags) {
      if (t.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

enum EducationResourceType { video, article, guide, anatomy }

extension EducationResourceTypeX on EducationResourceType {
  String get label {
    switch (this) {
      case EducationResourceType.video:
        return 'Video';
      case EducationResourceType.article:
        return 'Article';
      case EducationResourceType.guide:
        return 'Guide';
      case EducationResourceType.anatomy:
        return 'Anatomy';
    }
  }
}
