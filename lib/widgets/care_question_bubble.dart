import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/education_resource.dart';
import 'package:wellspring/services/education_service.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/openai/openai_config.dart';
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

    setState(() {
      _isSearching = true;
      _answer = null;
      _answerSteps = [];
      _products = [];
      _whenToContact = null;
      _encouragement = null;
      _relatedResources = [];
    });

    try {
      final question = _questionController.text.trim();
      final educationService = EducationService.instance;

      // Get patient conditions for better context
      List<String> patientConditions = [];
      String? conditionDetailsSummary;
      
      if (widget.isFamily && widget.patientId != null) {
        try {
          final patientData =
              await FamilyService().getJourneyData(widget.patientId!);
          final conditions = patientData['conditions'] as Map<String, String>?;
          if (conditions != null) {
            patientConditions = conditions.values.toList();
          }
          // Get detailed condition information if available
          final conditionDetails = patientData['conditionDetails'];
          if (conditionDetails != null) {
            conditionDetailsSummary = conditionDetails.toString();
          }
        } catch (e) {
          debugPrint(
              '[CareQuestionBubble] Error loading patient conditions: $e');
        }
      }

      // Use ChatGPT to generate personalized answer
      final openAiClient = OpenAIClient();
      final aiResponse = await openAiClient.generateCareAnswer(
        question: question,
        patientConditions: patientConditions,
        conditionDetailsSummary: conditionDetailsSummary,
      );

      // Find related educational resources
      final keywords = question.split(' ').where((w) => w.length > 3).toList();
      final searchHints = [...keywords, ...patientConditions];
      final resources = educationService.recommendedFor(
        searchHints,
        limit: 3,
      );

      if (mounted) {
        setState(() {
          _answer = aiResponse['answer'] as String?;
          _answerSteps = List<String>.from(aiResponse['steps'] as List? ?? []);
          _products = List<String>.from(aiResponse['products'] as List? ?? []);
          _whenToContact = aiResponse['whenToContact'] as String?;
          _encouragement = aiResponse['encouragement'] as String?;
          _relatedResources = resources;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('[CareQuestionBubble] Error: $e');
      if (mounted) {
        setState(() {
          _answer = 'I\'m having trouble generating a response right now. '
              'Please try again in a moment, or contact your care team with specific questions.';
          _answerSteps = [];
          _products = [];
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
                               // Create plan button
                               const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    debugPrint('[CreatePlan] Button clicked');
                                    final userProvider = context.read<UserProvider>();
                                    final conditions = userProvider.currentUser?.conditions ?? [];
                                    final questionText = bubble._questionController.text.trim();
                                    
                                    debugPrint('[CreatePlan] Conditions: $conditions, Question: "$questionText"');
                                    
                                    // Close modal first before navigating
                                    widget.onClose();
                                    
                                    if (conditions.isEmpty) {
                                      debugPrint('[CreatePlan] No conditions, navigating to /conditions');
                                      if (bubble.mounted) {
                                        await Future.delayed(const Duration(milliseconds: 300));
                                        bubble.context.go('/conditions');
                                      }
                                      return;
                                    }

                                    try {
                                      final conditionService = ConditionService();
                                      final condition = await conditionService.getConditionById(conditions.first);
                                      final conditionName = condition?.name ?? 'Plan';
                                      
                                      debugPrint('[CreatePlan] Got condition: $conditionName');
                                      
                                      if (widget.onCreatePlan != null) {
                                        await Future.delayed(const Duration(milliseconds: 300));
                                        debugPrint('[CreatePlan] Calling onCreatePlan with: conditionId=${ conditions.first}, conditionName=$conditionName, questionText="$questionText"');
                                        widget.onCreatePlan!(conditions.first, conditionName, questionText);
                                      } else {
                                        debugPrint('[CreatePlan] No onCreatePlan callback provided');
                                      }
                                    } catch (e) {
                                      debugPrint('[CreatePlan] Error: $e');
                                    }
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create a Plan'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
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
