import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Milestone Detail Screen - Shows comprehensive information about a milestone
/// Includes overview, why it matters, key concepts, step-by-step, research links, nearby support, products, and health library
class MilestoneDetailScreen extends StatefulWidget {
  final String milestoneId;

  const MilestoneDetailScreen({
    super.key,
    required this.milestoneId,
  });

  @override
  State<MilestoneDetailScreen> createState() => _MilestoneDetailScreenState();
}

class _MilestoneDetailScreenState extends State<MilestoneDetailScreen> {
  bool _isLoading = true;
  String _milestoneName = '';
  String _overview = '';
  String _whyItMatters = '';
  List<String> _keyConcepts = [];
  List<_StepByStep> _stepBySteps = [];
  List<String> _researchTopics = [];
  List<_Provider> _nearbyProviders = [];
  List<_Product> _products = [];
  List<_HealthTopic> _healthTopics = [];
  final Map<String, bool> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _loadMilestoneData();
  }

  Future<void> _loadMilestoneData() async {
    // In a real implementation, this would fetch data from the database
    // For now, we'll use mock data
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _milestoneName = 'Local Resource Consultation';
        _overview = 'Consulting local resources can provide valuable support and information for managing bed wounds and aiding in family member recovery. Engaging with nearby services can help you understand available options and connect with professionals who can offer guidance tailored to your needs.';
        _whyItMatters = 'Accessing local resources ensures you have the right support and information to care for your loved one effectively. It can also alleviate stress by connecting you with community services.';
        _keyConcepts = [
          'Identify local services that offer relevant support.',
          'Engage with professionals for tailored advice.',
          'Understand the range of available community resources.',
          'Learn about support services for family recovery.',
          'Explore options for ongoing assistance.',
        ];
        _stepBySteps = [
          _StepByStep(
            title: 'Identify Nearby Resources',
            description: 'Start by listing local services such as Castlewood State Park and World Bird Sanctuary that might offer relevant support or information.',
          ),
          _StepByStep(
            title: 'Reach Out for Information',
            description: 'Reach out to these services to discuss your specific needs and learn about what support they can offer.',
          ),
          _StepByStep(
            title: 'Connect with Professionals',
            description: 'Connect with professionals who have expertise in the areas you need help with.',
          ),
        ];
        _researchTopics = [
          'local support for bed wounds',
          'community health services near me',
          'family recovery support options',
          'engaging local healthcare providers',
          'bed wound management resources',
        ];
        _nearbyProviders = [
          _Provider(
            name: 'Concentra Urgent Care',
            type: 'Medical Clinic',
            distance: '4.7 mi away',
            address: '128 Matrix Commons Drive, Fenton',
            status: 'Open now',
            rating: 4.2,
            reviewCount: 961,
          ),
          _Provider(
            name: 'Steven Lee, MD',
            type: 'Doctor',
            distance: '5.2 mi away',
            address: '12990 Manchester Road Suite 201, Des Peres',
            status: 'Open now',
            rating: 4.9,
            reviewCount: 140,
          ),
          _Provider(
            name: 'Karen M. Seaton, PT',
            type: 'Physical Therapist',
            distance: '5.4 mi away',
            address: '1076 Old Des Peres Road, Des Peres',
            status: 'Open now',
            rating: null,
            reviewCount: null,
          ),
          _Provider(
            name: 'Washington University & Barnes-Jewish Orthopedic Center',
            type: 'Orthopedic Clinic',
            distance: '6.1 mi away',
            address: '14532 South Outer Forty Road, Chesterfield',
            status: 'Open now',
            rating: 4.1,
            reviewCount: 78,
          ),
        ];
        _products = [
          _Product(
            name: 'local support for bed wounds',
            description: 'Find local support options for bed wound care',
            amazonUrl: 'https://www.google.com/search?q=local+support+for+bed+wounds',
          ),
          _Product(
            name: 'community health services near me',
            description: 'Discover community health services in your area',
            amazonUrl: 'https://www.google.com/search?q=community+health+services+near+me',
          ),
          _Product(
            name: 'family recovery support options',
            description: 'Explore family recovery support resources',
            amazonUrl: 'https://www.google.com/search?q=family+recovery+support+options',
          ),
        ];
        _healthTopics = [
          _HealthTopic(title: 'Rehabilitation & Therapy', count: 7),
          _HealthTopic(title: 'Neurological Conditions', count: 9),
          _HealthTopic(title: 'Mobility & Movement', count: 6),
          _HealthTopic(title: 'Heart & Cardiovascular', count: 6),
          _HealthTopic(title: 'Pain Management', count: 5),
          _HealthTopic(title: 'Mental Health & Wellbeing', count: 6),
          _HealthTopic(title: 'Nutrition & Diet', count: 5),
          _HealthTopic(title: 'Medications & Safety', count: 4),
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F2E),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/b0380405-152d-4717-8856-bf48d924b809.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0A1F2E),
                      Color(0xFF0D2A3D),
                      Color(0xFF0A1F2E),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),
                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF1ED3CF)),
                          ),
                        )
                      : _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          Text(
            'Learn more',
            style: context.textStyles.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMilestoneCard(),
          const SizedBox(height: 24),
          _buildOverviewSection(),
          const SizedBox(height: 24),
          _buildWhyItMattersSection(),
          const SizedBox(height: 24),
          _buildKeyConceptsSection(),
          const SizedBox(height: 24),
          _buildStepByStepSection(),
          const SizedBox(height: 24),
          _buildResearchFurtherSection(),
          const SizedBox(height: 24),
          _buildNearbySupportSection(),
          const SizedBox(height: 24),
          _buildPharmaciesSection(),
          const SizedBox(height: 24),
          _buildHelpfulProductsSection(),
          const SizedBox(height: 24),
          _buildHealthLibrarySection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D3D3D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1ED3CF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school,
              color: Color(0xFF1ED3CF),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _milestoneName,
              style: context.textStyles.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: context.textStyles.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _overview,
          style: context.textStyles.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildWhyItMattersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.favorite, color: Color(0xFF1ED3CF), size: 20),
            const SizedBox(width: 8),
            Text(
              'Why this matters',
              style: context.textStyles.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _whyItMatters,
          style: context.textStyles.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyConceptsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb, color: Color(0xFF1ED3CF), size: 20),
            const SizedBox(width: 8),
            Text(
              'Key concepts',
              style: context.textStyles.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._keyConcepts.map((concept) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(Icons.circle, size: 6, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  concept,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildStepByStepSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.format_list_numbered, color: Color(0xFF1ED3CF), size: 20),
            const SizedBox(width: 8),
            Text(
              'Step-by-step',
              style: context.textStyles.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._stepBySteps.map((step) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2533),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: context.textStyles.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  step.description,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildResearchFurtherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.search, color: Color(0xFF1ED3CF), size: 20),
            const SizedBox(width: 8),
            Text(
              'Research further',
              style: context.textStyles.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._researchTopics.map((topic) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () async {
              final url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(topic)}');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0A2533),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.launch, color: Color(0xFF1ED3CF), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      topic,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildNearbySupportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF1ED3CF), size: 20),
            const SizedBox(width: 8),
            Text(
              'Nearby support',
              style: context.textStyles.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Within ~15 miles of Ballwin, MO 63021, USA',
          style: context.textStyles.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        _buildExpandableProviderSection(
          'Therapists & specialists',
          Icons.medical_services,
          _nearbyProviders,
        ),
      ],
    );
  }

  Widget _buildExpandableProviderSection(String title, IconData icon, List<_Provider> providers) {
    final isExpanded = _expandedSections[title] ?? true;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expandedSections[title] = !isExpanded),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2533),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF1ED3CF), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: context.textStyles.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[  
          const SizedBox(height: 12),
          ...providers.map((provider) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildProviderCard(provider),
          )),
        ],
      ],
    );
  }

  Widget _buildProviderCard(_Provider provider) {
    return InkWell(
      onTap: () async {
        final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(provider.name + ' ' + provider.address)}');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A2533),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1ED3CF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF1ED3CF),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    style: context.textStyles.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${provider.distance} · ${provider.address}',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.status,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (provider.rating != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFF1ED3CF), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        provider.rating!.toStringAsFixed(1),
                        style: context.textStyles.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (provider.reviewCount != null)
                    Text(
                      '${provider.reviewCount} reviews',
                      style: context.textStyles.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPharmaciesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExpandableSection(
          'Pharmacies',
          Icons.local_pharmacy,
          [
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=pharmacies+near+me');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A2533),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF1ED3CF).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.explore, color: Color(0xFF1ED3CF), size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Explore locations',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: Color(0xFF1ED3CF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHelpfulProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shopping_bag, color: Color(0xFF1ED3CF), size: 20),
            const SizedBox(width: 8),
            Text(
              'Helpful products',
              style: context.textStyles.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._products.map((product) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () async {
              final url = Uri.parse(product.amazonUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0A2533),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.launch, color: Color(0xFF1ED3CF), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      product.name,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildHealthLibrarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_library, color: Color(0xFF1ED3CF), size: 20),
            const SizedBox(width: 8),
            Text(
              'Trusted health library',
              style: context.textStyles.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Health Topics',
          style: context.textStyles.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._healthTopics.map((topic) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildExpandableHealthTopic(topic),
        )),
      ],
    );
  }

  Widget _buildExpandableHealthTopic(_HealthTopic topic) {
    final isExpanded = _expandedSections[topic.title] ?? false;

    return InkWell(
      onTap: () => setState(() => _expandedSections[topic.title] = !isExpanded),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                topic.title,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              topic.count.toString(),
              style: context.textStyles.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white.withValues(alpha: 0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSection(String title, IconData icon, List<Widget> children) {
    final isExpanded = _expandedSections[title] ?? false;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expandedSections[title] = !isExpanded),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2533),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF1ED3CF), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: context.textStyles.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[  
          const SizedBox(height: 12),
          ...children,
        ],
      ],
    );
  }
}

// Models
class _Product {
  final String name;
  final String description;
  final String amazonUrl;

  _Product({
    required this.name,
    required this.description,
    required this.amazonUrl,
  });
}

class _Provider {
  final String name;
  final String type;
  final String distance;
  final String address;
  final String status;
  final double? rating;
  final int? reviewCount;

  _Provider({
    required this.name,
    required this.type,
    required this.distance,
    required this.address,
    required this.status,
    this.rating,
    this.reviewCount,
  });
}

class _StepByStep {
  final String title;
  final String description;

  _StepByStep({
    required this.title,
    required this.description,
  });
}

class _HealthTopic {
  final String title;
  final int count;

  _HealthTopic({
    required this.title,
    required this.count,
  });
}
