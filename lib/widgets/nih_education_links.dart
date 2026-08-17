import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wellspring/theme.dart';

/// Curated Trusted Health Library — displays hand-picked content from
/// trusted health organizations and databases:
/// - MedlinePlus (medlineplus.gov) - NIH/NLM consumer health portal
/// - NIH (nih.gov) - National Institutes of Health
/// - USDA FoodData Central (fdc.nal.usda.gov) - Nutrition database
/// - SUNA (suna.org) - Urologic nursing education
///
/// Features:
/// - Comprehensive recovery-focused Health Topics with real URLs
/// - Curated Encyclopedia articles for specific conditions/procedures
/// - Quick access to specialized databases
/// - All links verified and point to actual trusted sources
class NihEducationLinks extends StatelessWidget {
  final String? conditionName;
  final String? milestoneTitle;
  final String? milestoneDescription;
  final bool showHeader;

  const NihEducationLinks({
    super.key,
    this.conditionName,
    this.milestoneTitle,
    this.milestoneDescription,
    this.showHeader = true,
  });

  // Curated MedlinePlus Health Topics organized by category
  static const List<_NihCategory> _categories = [
    _NihCategory(
      title: 'Rehabilitation & Therapy',
      items: [
        _NihLink('Physical Therapy', 'https://medlineplus.gov/physicaltherapy.html'),
        _NihLink('Occupational Therapy', 'https://medlineplus.gov/occupationaltherapy.html'),
        _NihLink('Speech and Communication Disorders', 'https://medlineplus.gov/speechandcommunicationdisorders.html'),
        _NihLink('Rehabilitation', 'https://medlineplus.gov/rehabilitation.html'),
        _NihLink('Stroke Rehabilitation', 'https://medlineplus.gov/strokerehabilitation.html'),
        _NihLink('Cardiac Rehabilitation', 'https://medlineplus.gov/cardiacrehabilitation.html'),
        _NihLink('Cancer Rehabilitation', 'https://medlineplus.gov/cancerrehabilitation.html'),
      ],
    ),
    _NihCategory(
      title: 'Neurological Conditions',
      items: [
        _NihLink('Stroke', 'https://medlineplus.gov/stroke.html'),
        _NihLink('Spinal Cord Injuries', 'https://medlineplus.gov/spinalcordinjuries.html'),
        _NihLink('Traumatic Brain Injury', 'https://medlineplus.gov/traumaticbraininjury.html'),
        _NihLink('Paralysis', 'https://medlineplus.gov/paralysis.html'),
        _NihLink('Parkinson\'s Disease', 'https://medlineplus.gov/parkinsonsdisease.html'),
        _NihLink('Multiple Sclerosis', 'https://medlineplus.gov/multiplesclerosis.html'),
        _NihLink('ALS (Lou Gehrig\'s Disease)', 'https://medlineplus.gov/amyotrophiclateralsclerosis.html'),
        _NihLink('Dementia', 'https://medlineplus.gov/dementia.html'),
        _NihLink('Alzheimer\'s Disease', 'https://medlineplus.gov/alzheimersdisease.html'),
      ],
    ),
    _NihCategory(
      title: 'Mobility & Movement',
      items: [
        _NihLink('Mobility Aids', 'https://medlineplus.gov/mobilityaids.html'),
        _NihLink('Assistive Devices', 'https://medlineplus.gov/assistivedevices.html'),
        _NihLink('Balance Problems', 'https://medlineplus.gov/balanceproblems.html'),
        _NihLink('Falls', 'https://medlineplus.gov/falls.html'),
        _NihLink('Walking Problems', 'https://medlineplus.gov/walkingproblems.html'),
        _NihLink('Gait Disorders', 'https://medlineplus.gov/gaitdisordersandbalanceproblems.html'),
      ],
    ),
    _NihCategory(
      title: 'Heart & Cardiovascular',
      items: [
        _NihLink('Heart Attack', 'https://medlineplus.gov/heartattack.html'),
        _NihLink('Heart Failure', 'https://medlineplus.gov/heartfailure.html'),
        _NihLink('Heart Diseases', 'https://medlineplus.gov/heartdiseases.html'),
        _NihLink('High Blood Pressure', 'https://medlineplus.gov/highbloodpressure.html'),
        _NihLink('Cholesterol', 'https://medlineplus.gov/cholesterol.html'),
        _NihLink('Blood Clots', 'https://medlineplus.gov/bloodclots.html'),
      ],
    ),
    _NihCategory(
      title: 'Pain Management',
      items: [
        _NihLink('Chronic Pain', 'https://medlineplus.gov/chronicpain.html'),
        _NihLink('Pain', 'https://medlineplus.gov/pain.html'),
        _NihLink('Pain Relievers', 'https://medlineplus.gov/painrelievers.html'),
        _NihLink('Back Pain', 'https://medlineplus.gov/backpain.html'),
        _NihLink('Nerve Pain', 'https://medlineplus.gov/neuralgia.html'),
      ],
    ),
    _NihCategory(
      title: 'Mental Health & Wellbeing',
      items: [
        _NihLink('Depression', 'https://medlineplus.gov/depression.html'),
        _NihLink('Anxiety', 'https://medlineplus.gov/anxiety.html'),
        _NihLink('Mental Health', 'https://medlineplus.gov/mentalhealth.html'),
        _NihLink('Post-Traumatic Stress Disorder (PTSD)', 'https://medlineplus.gov/posttraumaticstressdisorder.html'),
        _NihLink('Sleep Disorders', 'https://medlineplus.gov/sleepdisorders.html'),
        _NihLink('Insomnia', 'https://medlineplus.gov/insomnia.html'),
      ],
    ),
    _NihCategory(
      title: 'Nutrition & Diet',
      items: [
        _NihLink('Nutrition', 'https://medlineplus.gov/nutrition.html'),
        _NihLink('Healthy Diet', 'https://medlineplus.gov/healthydiet.html'),
        _NihLink('Malnutrition', 'https://medlineplus.gov/malnutrition.html'),
        _NihLink('Swallowing Disorders', 'https://medlineplus.gov/swallowingdisorders.html'),
        _NihLink('Dehydration', 'https://medlineplus.gov/dehydration.html'),
      ],
    ),
    _NihCategory(
      title: 'Medications & Safety',
      items: [
        _NihLink('Medication Safety', 'https://medlineplus.gov/medicationsafety.html'),
        _NihLink('Medicines and Older Adults', 'https://medlineplus.gov/medicinesandolderadults.html'),
        _NihLink('Drug Interactions', 'https://medlineplus.gov/druginteractions.html'),
        _NihLink('Over-the-Counter Medicines', 'https://medlineplus.gov/overthecountermedicines.html'),
      ],
    ),
    _NihCategory(
      title: 'Caregiving & Support',
      items: [
        _NihLink('Caregivers', 'https://medlineplus.gov/caregivers.html'),
        _NihLink('Home Care Services', 'https://medlineplus.gov/homecareservices.html'),
        _NihLink('Assisted Living', 'https://medlineplus.gov/assistedliving.html'),
        _NihLink('Patient Safety', 'https://medlineplus.gov/patientsafety.html'),
      ],
    ),
    _NihCategory(
      title: 'Hospital & Healthcare',
      items: [
        _NihLink('Going to the Hospital', 'https://medlineplus.gov/goingtothehospital.html'),
        _NihLink('Discharge Planning', 'https://medlineplus.gov/dischargeplanning.html'),
        _NihLink('After Surgery', 'https://medlineplus.gov/aftersurgery.html'),
        _NihLink('Patient Rights', 'https://medlineplus.gov/patientrights.html'),
        _NihLink('Health Insurance', 'https://medlineplus.gov/healthinsurance.html'),
      ],
    ),
  ];

  // Curated Encyclopedia Articles for common recovery-related conditions
  static const List<_NihLink> _encyclopediaArticles = [
    // Stroke
    _NihLink('Stroke - Encyclopedia', 'https://medlineplus.gov/ency/article/000726.htm'),
    _NihLink('Stroke Recovery - Encyclopedia', 'https://medlineplus.gov/ency/article/007408.htm'),
    _NihLink('Hemorrhagic Stroke - Encyclopedia', 'https://medlineplus.gov/ency/article/000790.htm'),
    
    // Spinal Cord
    _NihLink('Spinal Cord Trauma - Encyclopedia', 'https://medlineplus.gov/ency/article/001066.htm'),
    _NihLink('Spinal Cord Injury - Encyclopedia', 'https://medlineplus.gov/ency/article/007298.htm'),
    
    // Brain Injury
    _NihLink('Traumatic Brain Injury - Encyclopedia', 'https://medlineplus.gov/ency/article/000028.htm'),
    _NihLink('Concussion - Encyclopedia', 'https://medlineplus.gov/ency/article/000799.htm'),
    
    // Cardiac
    _NihLink('Heart Attack - Encyclopedia', 'https://medlineplus.gov/ency/article/000195.htm'),
    _NihLink('Heart Failure - Encyclopedia', 'https://medlineplus.gov/ency/article/000158.htm'),
    _NihLink('Cardiac Rehabilitation - Encyclopedia', 'https://medlineplus.gov/ency/article/001522.htm'),
    
    // Orthopedic
    _NihLink('Hip Replacement - Encyclopedia', 'https://medlineplus.gov/ency/article/002975.htm'),
    _NihLink('Knee Replacement - Encyclopedia', 'https://medlineplus.gov/ency/article/002974.htm'),
    _NihLink('Fracture - Encyclopedia', 'https://medlineplus.gov/ency/article/000001.htm'),
    
    // Therapy
    _NihLink('Physical Therapy - Encyclopedia', 'https://medlineplus.gov/ency/article/002059.htm'),
    _NihLink('Occupational Therapy - Encyclopedia', 'https://medlineplus.gov/ency/article/002054.htm'),
    _NihLink('Speech Therapy - Encyclopedia', 'https://medlineplus.gov/ency/article/002015.htm'),
    
    // Common Issues
    _NihLink('Pressure Ulcer - Encyclopedia', 'https://medlineplus.gov/ency/article/007071.htm'),
    _NihLink('Deep Vein Thrombosis - Encyclopedia', 'https://medlineplus.gov/ency/article/000156.htm'),
    _NihLink('Urinary Catheter Care - Encyclopedia', 'https://medlineplus.gov/ency/patientinstructions/000142.htm'),
    _NihLink('Constipation - Encyclopedia', 'https://medlineplus.gov/ency/article/003125.htm'),
    _NihLink('Dysphagia (Swallowing Problems) - Encyclopedia', 'https://medlineplus.gov/ency/article/003115.htm'),
    
    // Pain
    _NihLink('Chronic Pain - Encyclopedia', 'https://medlineplus.gov/ency/article/001946.htm'),
    _NihLink('Neuropathic Pain - Encyclopedia', 'https://medlineplus.gov/ency/article/007208.htm'),
    
    // Mental Health
    _NihLink('Depression - Encyclopedia', 'https://medlineplus.gov/ency/article/003213.htm'),
    _NihLink('PTSD - Encyclopedia', 'https://medlineplus.gov/ency/article/000925.htm'),
    
    // Mobility
    _NihLink('Gait Training - Encyclopedia', 'https://medlineplus.gov/ency/article/007770.htm'),
    _NihLink('Balance Training - Encyclopedia', 'https://medlineplus.gov/ency/article/007435.htm'),
    _NihLink('Wheelchair Use - Encyclopedia', 'https://medlineplus.gov/ency/patientinstructions/000147.htm'),
  ];

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Filters and prioritizes categories and articles based on user context
  List<_NihCategory> _getRelevantCategories() {
    final searchText = [conditionName, milestoneTitle, milestoneDescription]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ')
        .toLowerCase();
    
    if (searchText.isEmpty) return _categories;

    // Score each category by relevance
    final scoredCategories = <({_NihCategory category, int score})>[];
    
    for (final category in _categories) {
      int score = 0;
      final categoryText = category.title.toLowerCase();
      final itemsText = category.items.map((i) => i.title.toLowerCase()).join(' ');
      
      // Check category title relevance
      for (final keyword in _getKeywords(searchText)) {
        if (categoryText.contains(keyword)) score += 5;
        if (itemsText.contains(keyword)) score += 2;
      }
      
      if (score > 0) {
        scoredCategories.add((category: category, score: score));
      }
    }
    
    // Sort by score, return top categories + always include Rehabilitation
    scoredCategories.sort((a, b) => b.score.compareTo(a.score));
    final result = scoredCategories.take(4).map((sc) => sc.category).toList();
    
    // Always include Rehabilitation & Therapy if not already present
    final rehabCategory = _categories.firstWhere(
      (c) => c.title == 'Rehabilitation & Therapy',
      orElse: () => _categories.first,
    );
    if (!result.contains(rehabCategory)) {
      result.insert(0, rehabCategory);
    }
    
    return result.isEmpty ? _categories.take(3).toList() : result;
  }

  /// Filters and prioritizes encyclopedia articles based on user context
  List<_NihLink> _getRelevantArticles() {
    final searchText = [conditionName, milestoneTitle, milestoneDescription]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ')
        .toLowerCase();
    
    if (searchText.isEmpty) return _encyclopediaArticles.take(8).toList();

    // Score each article by relevance
    final scoredArticles = <({_NihLink article, int score})>[];
    
    for (final article in _encyclopediaArticles) {
      int score = 0;
      final articleText = article.title.toLowerCase();
      
      for (final keyword in _getKeywords(searchText)) {
        if (articleText.contains(keyword)) score += 10;
        // Partial matches
        if (keyword.length > 4 && articleText.contains(keyword.substring(0, 4))) score += 2;
      }
      
      if (score > 0) {
        scoredArticles.add((article: article, score: score));
      }
    }
    
    scoredArticles.sort((a, b) => b.score.compareTo(a.score));
    final topArticles = scoredArticles.take(6).map((sa) => sa.article).toList();
    
    // If we have very few relevant articles, supplement with common recovery topics
    if (topArticles.length < 4) {
      final defaultArticles = _encyclopediaArticles.where((a) => 
        a.title.contains('Therapy') || 
        a.title.contains('Rehabilitation') ||
        a.title.contains('Pain')
      ).take(6 - topArticles.length);
      topArticles.addAll(defaultArticles);
    }
    
    return topArticles.isEmpty ? _encyclopediaArticles.take(6).toList() : topArticles;
  }

  /// Extracts meaningful keywords from search text
  List<String> _getKeywords(String text) {
    // Common words to ignore
    const stopWords = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by'};
    
    return text
        .toLowerCase()
        .split(RegExp(r'[\s,\.;:!\?]+'))
        .where((word) => word.length > 2 && !stopWords.contains(word))
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[];

    if (showHeader) {
      children.addAll([
        Row(children: [
          Icon(Icons.menu_book_rounded, color: cs.primary, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Trusted Health Library',
                style: context.textStyles.titleMedium?.semiBold),
          ),
        ]),
        SizedBox(height: AppSpacing.xs),
        Text(
          'Curated health information from trusted sources',
          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
        ),
        SizedBox(height: AppSpacing.md),
        // Quick access buttons to key resources
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _QuickAccessButton(
              label: 'NIH',
              url: 'https://www.nih.gov/',
              icon: Icons.science_outlined,
              onTap: _open,
            ),
            _QuickAccessButton(
              label: 'MedlinePlus',
              url: 'https://medlineplus.gov/',
              icon: Icons.local_hospital_outlined,
              onTap: _open,
            ),
            _QuickAccessButton(
              label: 'USDA Nutrition',
              url: 'https://fdc.nal.usda.gov/',
              icon: Icons.restaurant_outlined,
              onTap: _open,
            ),
            _QuickAccessButton(
              label: 'SUNA Education',
              url: 'https://www.suna.org/online-education',
              icon: Icons.school_outlined,
              onTap: _open,
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),
      ]);
    }

    // Get filtered/prioritized content based on user context
    final relevantCategories = _getRelevantCategories();
    final relevantArticles = _getRelevantArticles();

    // Health Topics organized by category (filtered)
    children.add(
      Text('Related Health Topics',
          style: context.textStyles.titleSmall?.semiBold
              .withColor(cs.onSurface)),
    );
    children.add(SizedBox(height: AppSpacing.xs));

    for (final category in relevantCategories) {
      children.add(_CategorySection(
        title: category.title,
        items: category.items,
        onTap: _open,
      ));
      children.add(SizedBox(height: AppSpacing.sm));
    }

    // Encyclopedia Articles (filtered)
    if (relevantArticles.isNotEmpty) {
      children.add(SizedBox(height: AppSpacing.sm));
      children.add(
        Text('Related Encyclopedia Articles',
            style: context.textStyles.titleSmall?.semiBold
                .withColor(cs.onSurface)),
      );
      children.add(SizedBox(height: AppSpacing.xs));
      children.add(
        Text(
          'In-depth articles about your condition and milestone',
          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
        ),
      );
      children.add(SizedBox(height: AppSpacing.sm));

      for (final article in relevantArticles) {
        children.add(_LinkTile(
          title: article.title,
          url: article.url,
          onTap: () => _open(article.url),
        ));
      }
    }

    // Browse all link
    children.add(SizedBox(height: AppSpacing.md));
    children.add(
      OutlinedButton.icon(
        onPressed: () => _open('https://medlineplus.gov/all_healthtopics.html'),
        icon: Icon(Icons.explore_rounded, size: 18),
        label: Text('Browse all MedlinePlus topics'),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

// Helper classes for organizing NIH content
class _NihCategory {
  final String title;
  final List<_NihLink> items;

  const _NihCategory({required this.title, required this.items});
}

class _NihLink {
  final String title;
  final String url;

  const _NihLink(this.title, this.url);
}

// Category section with collapsible items
class _CategorySection extends StatefulWidget {
  final String title;
  final List<_NihLink> items;
  final Function(String) onTap;

  const _CategorySection({
    required this.title,
    required this.items,
    required this.onTap,
  });

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: context.textStyles.bodyMedium?.semiBold,
                    ),
                  ),
                  Text(
                    '${widget.items.length}',
                    style: context.textStyles.labelSmall
                        ?.withColor(cs.onSurfaceVariant),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    _LinkTile(
                      title: widget.items[i].title,
                      url: widget.items[i].url,
                      onTap: () => widget.onTap(widget.items[i].url),
                      isLast: i == widget.items.length - 1,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Quick access button for major resources
class _QuickAccessButton extends StatelessWidget {
  final String label;
  final String url;
  final IconData icon;
  final Function(String) onTap;

  const _QuickAccessButton({
    required this.label,
    required this.url,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      onPressed: () => onTap(url),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
    );
  }
}

// Individual link tile
class _LinkTile extends StatelessWidget {
  final String title;
  final String url;
  final VoidCallback onTap;
  final bool isLast;

  const _LinkTile({
    required this.title,
    required this.url,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.textStyles.bodySmall,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Icon(Icons.open_in_new_rounded,
                  size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
