import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/education_resource.dart';
import 'package:wellspring/services/education_service.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/openai/openai_config.dart';
import 'package:wellspring/services/arie_action_plan_service.dart';
import 'package:wellspring/services/arie_support_engine.dart';
import 'package:url_launcher/url_launcher.dart';

/// A floating bubble widget that expands to let users ask questions about
/// post-discharge and recovery caretaking. Provides quick AI-like explanations
/// using educational resources tailored to the connected patient's conditions.
class CareQuestionBubble extends StatefulWidget {
  final String userId;
  final String? patientId; // If family member, pass the connected patient ID
  final bool isFamily;

  const CareQuestionBubble({
    super.key,
    required this.userId,
    this.patientId,
    this.isFamily = false,
  });

  @override
  State<CareQuestionBubble> createState() => _CareQuestionBubbleState();
}

class _CareQuestionBubbleState extends State<CareQuestionBubble>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  final _questionController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSearching = false;
  String? _answer;
  List<String> _answerSteps = [];
  List<String> _products = [];
  List<ArieResourceRecommendation> _resourceRecs = const [];
  String? _whenToContact;
  String? _encouragement;
  List<EducationResource> _relatedResources = [];
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Offset? _position; // null means use default position

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _questionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    if (_expanded) {
      _animationController.reverse();
      setState(() => _expanded = false);
      _answer = null;
      _answerSteps = [];
      _products = [];
      _resourceRecs = const [];
      _whenToContact = null;
      _encouragement = null;
      _relatedResources = [];
      _questionController.clear();
    } else {
      _animationController.forward();
      setState(() => _expanded = true);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (modalContext) => _AskArieModal(
          bubbleState: this,
          onClose: () {
            if (mounted) {
              Navigator.pop(modalContext);
              _animationController.reverse();
              setState(() => _expanded = false);
              _answer = null;
              _answerSteps = [];
              _products = [];
              _resourceRecs = const [];
              _whenToContact = null;
              _encouragement = null;
              _relatedResources = [];
              _questionController.clear();
            }
          },
          onCreatePlan: (conditionId, conditionName, questionText) {
            // Navigate from the outer context, not the modal context
            if (mounted) {
              debugPrint('[CareQuestionBubble.onCreatePlan] Navigating to /plan/$conditionId with extra: conditionName=$conditionName, initialQuestion="$questionText"');
              context.go('/plan/$conditionId', extra: {
                'conditionName': conditionName,
                'initialQuestion': questionText,
              });
            }
          },
        ),
      ).then((_) {
        if (mounted) {
          _answer = null;
          _answerSteps = [];
          _products = [];
          _resourceRecs = const [];
          _whenToContact = null;
          _encouragement = null;
          _relatedResources = [];
          _questionController.clear();
        }
      });
    }
  }

  Future<void> _handleQuestion() async {
    if (_questionController.text.trim().isEmpty) return;
    // Prevent double-submits (send button + keyboard action) from firing two
    // large AI calls at once, which burns the per-minute token budget.
    if (_isSearching) return;

    setState(() {
      _isSearching = true;
      _answer = null;
      _answerSteps = [];
      _products = [];
      _resourceRecs = const [];
      _whenToContact = null;
      _encouragement = null;
      _relatedResources = [];
    });

    try {
      final question = _questionController.text.trim();
      final educationService = EducationService.instance;

      // Use ARIE contextual engine (patient context + longitudinal data + optional location)
      final engine = ArieSupportEngine();
      final ArieSupportResponse aiResponse = await engine.answer(
        question: question,
        requesterUserId: widget.userId,
        patientId: widget.isFamily ? widget.patientId : null,
      );

      // Find related educational resources
      final keywords = question.split(' ').where((w) => w.length > 3).toList();
      final searchHints = [...keywords];
      final resources = educationService.recommendedFor(
        searchHints,
        limit: 3,
      );

      if (mounted) {
        setState(() {
          _answer = aiResponse.answer;
          _answerSteps = aiResponse.steps;
          _resourceRecs = aiResponse.recommendations;
          // Back-compat: keep products slot for AI to suggest equipment, but this new
          // engine focuses on resources; product suggestions may be added later.
          _products = const [];
          _whenToContact = (aiResponse.safetyNotes.isEmpty) ? null : aiResponse.safetyNotes.first;
          _encouragement = null;
          _relatedResources = resources;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('[CareQuestionBubble] Error: $e');
      if (mounted) {
        final transient = OpenAIClient.isTransientAiError(e);
        setState(() {
          _answer = transient
              ? 'I\'m getting a lot of requests at once and hit a temporary limit. '
                  'Wait about 15 seconds and tap send again — your question is still in the box.'
              : 'I\'m having trouble generating a response right now. '
                  'Please try again in a moment, or contact your care team with specific questions.';
          _answerSteps = [];
          _products = [];
          _resourceRecs = const [];
          _whenToContact = null;
          _encouragement = null;
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _openResource(EducationResource resource) async {
    final uri = Uri.parse(resource.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  IconData _getResourceIcon(EducationResourceType type) {
    switch (type) {
      case EducationResourceType.video:
        return Icons.play_circle_outline;
      case EducationResourceType.article:
        return Icons.article_outlined;
      case EducationResourceType.guide:
        return Icons.menu_book_outlined;
      case EducationResourceType.anatomy:
        return Icons.biotech_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;

    final bottomNavHeight = 56.0;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final defaultBottomPosition = bottomNavHeight + bottomPadding + 16;
    final bubbleWidth = 150.0;

    final position = _position ??
        Offset(
            screenSize.width - bubbleWidth - 16, screenSize.height - defaultBottomPosition);

    if (_expanded) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Draggable(
        feedback: Opacity(
          opacity: 0.7,
          child: Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(30),
            elevation: 8,
            shadowColor: colorScheme.primary.withValues(alpha: 0.3),
            child: _buildCollapsedBubble(),
          ),
        ),
        onDragEnd: (details) {
          setState(() {
            final bubbleWidth = 150.0;
            final bubbleHeight = 52.0;

            final centerX = details.offset.dx + (bubbleWidth / 2);
            final snapToLeft = centerX < screenSize.width / 2;

            _position = Offset(
              snapToLeft ? 16 : screenSize.width - bubbleWidth - 16,
              details.offset.dy.clamp(0, screenSize.height - bubbleHeight),
            );
          });
        },
        child: Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          elevation: 8,
          shadowColor: colorScheme.primary.withValues(alpha: 0.3),
          child: _buildCollapsedBubble(),
        ),
      ),
    );
  }

  Widget _buildCollapsedBubble() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.5 : 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology,
              color: colorScheme.onPrimary,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Ask A.R.I.E',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AskArieModal extends StatefulWidget {
  final _CareQuestionBubbleState bubbleState;
  final VoidCallback onClose;
  final Function(String conditionId, String conditionName, String questionText)? onCreatePlan;

  const _AskArieModal({
    required this.bubbleState,
    required this.onClose,
    this.onCreatePlan,
  });

  @override
  State<_AskArieModal> createState() => _AskArieModalState();
}

class _AskArieModalState extends State<_AskArieModal> {
  String _prettyDetailKey(String raw) {
    if (raw.trim().isEmpty) return raw;
    // Convert camelCase-ish / snake-ish keys to a human label.
    final spaced = raw
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .trim();
    if (spaced.isEmpty) return raw;
    return spaced.substring(0, 1).toUpperCase() + spaced.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bubble = widget.bubbleState;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeTopPadding = MediaQuery.of(context).padding.top;

    // Calculate height accounting for keyboard
    final minHeight = keyboardHeight > 0 
        ? screenHeight - safeTopPadding - 50  // Leave small gap at top when keyboard is up
        : screenHeight * 0.7;  // Take up 70% of screen when keyboard is hidden
    
    final maxHeight = keyboardHeight > 0 
        ? screenHeight - safeTopPadding - 50
        : screenHeight * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        constraints: BoxConstraints(
          minHeight: minHeight,
          maxHeight: maxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header (fixed at top)
            Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology, color: colorScheme.onPrimary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask ARIE',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (bubble.widget.isFamily && bubble.widget.patientId != null)
                        Text(
                          'Personalized care advice',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimary.withValues(alpha: 0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onPrimary, size: 20),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: keyboardHeight > 0 ? 16 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                    Builder(
                      builder: (context) {
                        // Location permission is prompted during onboarding (iOS system prompt).
                        // We keep ARIE permission-aware, but we no longer prompt from inside this sheet.
                        return const SizedBox.shrink();
                      },
                    ),
                    // Question input
                    TextField(
                      controller: bubble._questionController,
                      focusNode: bubble._focusNode,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText:
                            'Ask about medications, mobility, care routines...',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.send,
                            color: colorScheme.primary,
                          ),
                          onPressed: bubble._isSearching
                              ? null
                              : () {
                                  bubble._handleQuestion().then((_) {
                                    if (mounted) setState(() {});
                                  });
                                },
                        ),
                      ),
                      onSubmitted: (_) {
                        bubble._handleQuestion().then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                    ),

                    if (bubble._isSearching) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: CircularProgressIndicator(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],

                    if (bubble._answer != null) ...[
                       const SizedBox(height: 16),
                       Container(
                         padding: const EdgeInsets.all(16),
                         decoration: BoxDecoration(
                           color: colorScheme.primaryContainer,
                           borderRadius: BorderRadius.circular(12),
                         ),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Row(
                               children: [
                                 Icon(
                                   Icons.lightbulb_outline,
                                   color: colorScheme.onPrimaryContainer,
                                   size: 20,
                                 ),
                                 const SizedBox(width: 8),
                                 Text(
                                   'A.R.I.E\'s Guidance',
                                   style: theme.textTheme.titleSmall?.copyWith(
                                     color: colorScheme.onPrimaryContainer,
                                     fontWeight: FontWeight.bold,
                                   ),
                                 ),
                               ],
                             ),
                             const SizedBox(height: 12),
                             Text(
                               bubble._answer!,
                               style: theme.textTheme.bodyMedium?.copyWith(
                                 color: colorScheme.onPrimaryContainer,
                                 height: 1.5,
                               ),
                             ),
                             if (bubble._answerSteps.isNotEmpty) ...[
                               const SizedBox(height: 12),
                               Text(
                                 'Action Steps:',
                                 style: theme.textTheme.labelMedium?.copyWith(
                                   color: colorScheme.onPrimaryContainer,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                               const SizedBox(height: 8),
                               ...bubble._answerSteps.map((step) => Padding(
                                 padding: const EdgeInsets.only(bottom: 8),
                                 child: Row(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(
                                       '•',
                                       style: theme.textTheme.bodyMedium?.copyWith(
                                         color: colorScheme.onPrimaryContainer,
                                       ),
                                     ),
                                     const SizedBox(width: 8),
                                     Expanded(
                                       child: Text(
                                         step,
                                         style: theme.textTheme.bodySmall?.copyWith(
                                           color: colorScheme.onPrimaryContainer,
                                           height: 1.4,
                                         ),
                                       ),
                                     ),
                                   ],
                                 ),
                               )),
                             ],
                             if (bubble._products.isNotEmpty) ...[
                               const SizedBox(height: 12),
                               Text(
                                 'Helpful Products:',
                                 style: theme.textTheme.labelMedium?.copyWith(
                                   color: colorScheme.onPrimaryContainer,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                               const SizedBox(height: 8),
                               ...bubble._products.map((product) => Padding(
                                 padding: const EdgeInsets.only(bottom: 8),
                                 child: Row(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Icon(
                                       Icons.medical_services_outlined,
                                       size: 16,
                                       color: colorScheme.onPrimaryContainer,
                                     ),
                                     const SizedBox(width: 8),
                                     Expanded(
                                       child: Text(
                                         product,
                                         style: theme.textTheme.bodySmall?.copyWith(
                                           color: colorScheme.onPrimaryContainer,
                                           height: 1.4,
                                         ),
                                       ),
                                     ),
                                   ],
                                 ),
                               )),
                             ],

                              if (bubble._resourceRecs.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Recommended Support Near You:',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...bubble._resourceRecs.map((rec) {
                                  final distance = rec.distanceMiles;
                                  final rating = rec.rating;
                                  final metaParts = <String>[];
                                  if (distance != null && distance > 0) metaParts.add('${distance.toStringAsFixed(1)} mi');
                                  if (rating != null && rating > 0) metaParts.add('⭐ ${rating.toStringAsFixed(1)}');
                                  if (rec.reviewCount != null && rec.reviewCount! > 0) metaParts.add('${rec.reviewCount} reviews');
                                  final meta = metaParts.join(' • ');

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ArieRecommendationCard(
                                      recommendation: rec,
                                      meta: meta,
                                      prettyDetailKey: _prettyDetailKey,
                                      questionText: bubble._questionController.text.trim(),
                                      userId: bubble.widget.userId,
                                      isFamily: bubble.widget.isFamily,
                                      onPlanCreated: () {
                                        widget.onClose();
                                        // Give the sheet a moment to close before navigating.
                                        Future.delayed(const Duration(milliseconds: 250), () {
                                          if (bubble.mounted) bubble.context.go('/plans');
                                        });
                                      },
                                    ),
                                  );
                                }),
                              ],

                              if (bubble._whenToContact != null && bubble._whenToContact!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 16,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          bubble._whenToContact!,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: colorScheme.onPrimaryContainer,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (bubble._encouragement != null && bubble._encouragement!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  bubble._encouragement!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                    if (bubble._relatedResources.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Learn More',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...bubble._relatedResources.map((resource) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => bubble._openResource(resource),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colorScheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      bubble._getResourceIcon(resource.type),
                                      color: colorScheme.onSecondaryContainer,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          resource.title,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${resource.sourceName} • ${resource.estimatedMinutes} min',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.open_in_new,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],

                    // Suggested questions
                    if (bubble._answer == null && !bubble._isSearching) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Try asking:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSuggestionChip(
                              'How do I manage medications?', bubble),
                          _buildSuggestionChip('When should I call 911?', bubble),
                          _buildSuggestionChip(
                              'Safe wheelchair transfers', bubble),
                          _buildSuggestionChip(
                              'Preventing pressure sores', bubble),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(
      String text, _CareQuestionBubbleState bubble) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () {
        bubble._questionController.text = text;
        bubble._handleQuestion().then((_) {
          if (mounted) setState(() {});
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ArieRecommendationCard extends StatelessWidget {
  final ArieResourceRecommendation recommendation;
  final String meta;
  final String Function(String raw) prettyDetailKey;
  final String questionText;
  final String userId;
  final bool isFamily;
  final VoidCallback onPlanCreated;

  const _ArieRecommendationCard({
    required this.recommendation,
    required this.meta,
    required this.prettyDetailKey,
    required this.questionText,
    required this.userId,
    required this.isFamily,
    required this.onPlanCreated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.onPrimaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_outlined, size: 16, color: cs.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (recommendation.reason != null && recommendation.reason!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              recommendation.reason!.trim(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onPrimaryContainer.withValues(alpha: 0.92),
                height: 1.35,
              ),
            ),
          ],
          if (recommendation.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...recommendation.details.entries
                .where((e) => (e.value ?? '').trim().isNotEmpty)
                .take(4)
                .map((e) {
              final k = prettyDetailKey(e.key);
              final v = (e.value ?? '').trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$k: $v',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.88),
                    height: 1.25,
                  ),
                ),
              );
            }),
          ],
          if (recommendation.questionsToAsk.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Questions to ask:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onPrimaryContainer.withValues(alpha: 0.92),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            ...recommendation.questionsToAsk.take(3).map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${q.trim()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.88),
                      height: 1.25,
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openInMaps(context, recommendation),
                  icon: Icon(Icons.map_outlined, color: cs.onPrimaryContainer),
                  label: Text('Open', style: TextStyle(color: cs.onPrimaryContainer)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.onPrimaryContainer.withValues(alpha: 0.35)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openCreatePlanSheet(context),
                  icon: Icon(Icons.auto_awesome, color: cs.onPrimary),
                  label: Text('Create plan', style: TextStyle(color: cs.onPrimary)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openInMaps(BuildContext context, ArieResourceRecommendation rec) async {
    final loc = (rec.universalRecord['location'] ?? rec.details['locationOrServiceArea'] ?? rec.details['location'] ?? rec.details['address'])?.toString();
    final q = [rec.name, if (loc != null && loc.trim().isNotEmpty) loc.trim()].join(' ');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open maps.')));
      }
    }
  }

  Future<void> _openCreatePlanSheet(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    final conditions = userProvider.currentUser?.conditions ?? const <String>[];
    final conditionId = conditions.isEmpty ? null : conditions.first;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateActionPlanSheet(
        userId: userId,
        conditionId: conditionId,
        questionText: questionText,
        recommendation: recommendation,
        onPlanCreated: onPlanCreated,
      ),
    );
  }
}

class _CreateActionPlanSheet extends StatefulWidget {
  final String userId;
  final String? conditionId;
  final String questionText;
  final ArieResourceRecommendation recommendation;
  final VoidCallback onPlanCreated;

  const _CreateActionPlanSheet({
    required this.userId,
    required this.conditionId,
    required this.questionText,
    required this.recommendation,
    required this.onPlanCreated,
  });

  @override
  State<_CreateActionPlanSheet> createState() => _CreateActionPlanSheetState();
}

class _CreateActionPlanSheetState extends State<_CreateActionPlanSheet> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 12, right: 12, bottom: 12 + bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Create action plan',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close))
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Based on: ${widget.recommendation.name}',
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _create,
                  icon: _loading
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: cs.onPrimary, strokeWidth: 2))
                      : Icon(Icons.check_circle, color: cs.onPrimary),
                  label: Text(_loading ? 'Building plan…' : 'Create & save', style: TextStyle(color: cs.onPrimary)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We’ll add the steps to your Plans so you can track progress.',
                style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      final service = ArieActionPlanService();
      final plan = await service.createPlanFromRecommendation(
        userId: widget.userId,
        conditionId: widget.conditionId,
        question: widget.questionText,
        recommendation: widget.recommendation,
      );
      await service.persistPlan(
        userId: widget.userId,
        conditionId: widget.conditionId,
        recommendation: widget.recommendation,
        plan: plan,
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action plan created.')));
        widget.onPlanCreated();
      }
    } catch (e) {
      debugPrint('_CreateActionPlanSheet._create error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create plan: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
