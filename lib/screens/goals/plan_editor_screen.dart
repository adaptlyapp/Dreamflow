import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/condition_detail.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/models/post.dart';
import 'package:wellspring/models/plan_timeline.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/milestone_service.dart';
import 'package:wellspring/services/resource_service.dart';
import 'package:wellspring/services/group_service.dart';
import 'package:wellspring/services/resource_suggestion_service.dart';
import 'package:wellspring/services/post_service.dart';
import 'package:wellspring/services/plan_timeline_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/openai/openai_config.dart';
import 'package:wellspring/supabase/supabase_config.dart';
// import removed: milestone_education_sheet.dart (switched to full-page)
import 'package:wellspring/screens/goals/milestone_education_page.dart';
import 'package:wellspring/widgets/plan_share_sheet.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/widgets/glass_card.dart';
import 'package:wellspring/widgets/help_type_chip.dart';
import 'package:wellspring/widgets/goal_breakdown_card.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/screens/main_navigation.dart';

class PlanEditorScreen extends StatefulWidget {
final String conditionId;
final String conditionName;
final String? initialQuestion;
const PlanEditorScreen({super.key, required this.conditionId, required this.conditionName, this.initialQuestion});

@override
State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
final _service = MilestoneService();
final _postService = PostService();
final _groupService = GroupService();
final _timelineService = PlanTimelineService();
final _conditionService = ConditionService();
bool _loading = true;
bool _generating = false;
bool _sharing = false;
bool _timelineBusy = false;
List<Milestone> _items = [];
List<PlanTimeline> _timelines = [];
PlanTimeline? _currentTimeline;
List<Condition> _userConditions = [];
String? _selectedConditionId;
String _selectedConditionName = '';
// UI state: collapse future milestones by default for faster progress check
bool _collapseFuture = true;
// Track per-item expansions when future is collapsed
final Set<String> _expandedFuture = {};
String? _rerollingId;
// Track whether the user made changes and whether they were saved to cloud
bool _sessionChanged = false;
bool _sessionSavedToCloud = false;
bool _pendingSnapshotSync = false;
// AI-produced goal breakdown from the most recent Generate Plan call.
// Kept in-memory only (session scope) — not persisted to Supabase.
String _breakdownGoalSummary = '';
String _breakdownComplexity = '';
List<Map<String, String>> _breakdownCategories = const [];
// Initial question context from Ask ARIE
String _initialQuestionContext = '';
  bool _didAutoOpenGenerate = false;
  bool _isGenerateSheetOpen = false;

@override
void initState() {
  super.initState();
  _selectedConditionId = widget.conditionId;
  _selectedConditionName = widget.conditionName;
  _initialQuestionContext = widget.initialQuestion ?? '';
  debugPrint('[PlanEditor] initState: initialQuestion="${widget.initialQuestion}", _initialQuestionContext="$_initialQuestionContext"');
  _ensureUserThenLoad();
}

Future<void> _ensureUserThenLoad() async {
try {
final userProvider = context.read<UserProvider>();
if (userProvider.currentUser == null) {
debugPrint('[PlanEditor] Loading current user');
await userProvider.loadUser();
}
// Load user conditions
final userConditionIds = userProvider.currentUser?.conditions ?? [];
if (userConditionIds.isNotEmpty) {
final allConditions = await _conditionService.getAllConditions();
_userConditions = allConditions.where((c) => userConditionIds.contains(c.id)).toList();
}
} catch (e) {
debugPrint('[PlanEditor] Error loading user: $e');
} finally {
if (!mounted) return;
await _load();
}
}

Future<void> _load() async {
bool timelineError = false;
// Use auth user ID for plan_timelines (references auth.users), not patient profile ID
final authUserId = SupabaseConfig.auth.currentUser?.id;
final patientProfileId = context.read<UserProvider>().currentUser?.id;
if (authUserId == null || patientProfileId == null) {
debugPrint('[PlanEditor] No user available; skipping milestones load');
if (!mounted) return;
setState(() => _loading = false);
return;
}
final conditionId = _selectedConditionId ?? widget.conditionId;
List<Milestone> list = [];
try {
list = await _service.list(userId: authUserId, conditionId: conditionId);
} catch (e, st) {
debugPrint('[PlanEditor] Milestones load failed: $e');
debugPrintStack(stackTrace: st);
}

List<PlanTimeline> timelines = [];
try {
timelines = await _timelineService.list(userId: authUserId, conditionId: conditionId);
} catch (e, st) {
timelineError = true;
debugPrint('[PlanEditor] Timeline load failed: $e');
debugPrintStack(stackTrace: st);
}
PlanTimeline? current;
if (!timelineError) {
for (final t in timelines) {
if (t.isCurrent) {
current = t;
break;
}
}

if (timelines.isEmpty) {
try {
final created = await _timelineService.createFromMilestones(
userId: authUserId,
conditionId: conditionId,
conditionName: _selectedConditionName,
name: 'Current plan',
milestones: list,
setCurrent: true,
);
timelines = [created];
current = created;
} catch (e, st) {
timelineError = true;
debugPrint('[PlanEditor] Timeline create failed: $e');
debugPrintStack(stackTrace: st);
}
} else if (current == null) {
current = timelines.first;
try {
await _timelineService.setCurrentAndActivate(
timeline: current,
userId: authUserId,
conditionId: conditionId,
replaceActivePlan: false,
);
timelines = await _timelineService.list(userId: authUserId, conditionId: conditionId);
for (final t in timelines) {
if (t.isCurrent) {
current = t;
break;
}
}
} catch (e, st) {
timelineError = true;
debugPrint('[PlanEditor] Timeline activate failed: $e');
debugPrintStack(stackTrace: st);
}
}
}

if (!mounted) return;
setState(() {
_items = list;
_timelines = timelines;
_currentTimeline = current;
_loading = false;
});

if (_pendingSnapshotSync && current != null && !timelineError) {
try {
await _timelineService.updateSnapshot(
timelineId: current.id,
userId: authUserId,
conditionId: conditionId,
milestones: _items,
);
} catch (e) {
debugPrint('[PlanEditor] Snapshot sync failed: $e');
}
_pendingSnapshotSync = false;
}
if (timelineError && mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan timelines unavailable. Please apply the timeline migration or try again.')));
}

// Auto-open generate modal if coming from Ask ARIE with a question
  if (mounted && !_didAutoOpenGenerate && _initialQuestionContext.isNotEmpty) {
    _didAutoOpenGenerate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _generateWithAI();
    });
  }
}

Future<void> _addOrEdit({Milestone? existing}) async {
final titleCtrl = TextEditingController(text: existing?.title ?? '');
final descCtrl = TextEditingController(text: existing?.description ?? '');
DateTime? due = existing?.dueDate;
bool completed = existing?.completed ?? false;

await showModalBottomSheet(
context: context,
isScrollControlled: true,
showDragHandle: true,
backgroundColor: Theme.of(context).colorScheme.surface,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
),
builder: (ctx) {
return StatefulBuilder(builder: (ctx, setModalState) {
return SafeArea(
top: false,
child: SingleChildScrollView(
padding: EdgeInsets.fromLTRB(
AppSpacing.lg,
AppSpacing.md,
AppSpacing.lg,
MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(existing == null ? 'Add Milestone' : 'Edit Milestone', style: ctx.textStyles.titleMedium?.semiBold),
SizedBox(height: AppSpacing.md),
TextField(
controller: titleCtrl,
decoration: const InputDecoration(labelText: 'Title'),
),
SizedBox(height: AppSpacing.sm),
TextField(
controller: descCtrl,
decoration: const InputDecoration(labelText: 'Description'),
maxLines: 3,
),
SizedBox(height: AppSpacing.sm),
LayoutBuilder(
builder: (context, constraints) {
final isNarrow = constraints.maxWidth < 420;
if (isNarrow) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
OutlinedButton.icon(
onPressed: () async {
final now = DateTime.now();
final picked = await showDatePicker(
context: ctx,
firstDate: now.subtract(const Duration(days: 1)),
lastDate: now.add(const Duration(days: 365)),
initialDate: due ?? now.add(const Duration(days: 7)),
);
if (picked != null) {
setModalState(() => due = picked);
}
},
icon: Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
label: Text(due == null ? 'Pick due date' : 'Due ${MaterialLocalizations.of(ctx).formatMediumDate(due!)}'),
),
SizedBox(height: AppSpacing.sm),
Row(children: [
Checkbox(value: completed, onChanged: (v) => setModalState(() => completed = v ?? false)),
const Text('Completed'),
])
],
);
}
return Row(
children: [
Expanded(
child: OutlinedButton.icon(
onPressed: () async {
final now = DateTime.now();
final picked = await showDatePicker(
context: ctx,
firstDate: now.subtract(const Duration(days: 1)),
lastDate: now.add(const Duration(days: 365)),
initialDate: due ?? now.add(const Duration(days: 7)),
);
if (picked != null) {
setModalState(() => due = picked);
}
},
icon: Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
label: Text(due == null ? 'Pick due date' : 'Due ${MaterialLocalizations.of(ctx).formatMediumDate(due!)}'),
),
),
SizedBox(width: AppSpacing.sm),
Row(children: [
Checkbox(value: completed, onChanged: (v) => setModalState(() => completed = v ?? false)),
const Text('Completed'),
])
],
);
},
),
SizedBox(height: AppSpacing.md),
FilledButton(
onPressed: () async {
final authUserId = SupabaseConfig.auth.currentUser?.id;
if (authUserId == null) return;
final now = DateTime.now();
final m = existing == null
? Milestone(
id: const Uuid().v4(),
userId: authUserId,
conditionId: _selectedConditionId ?? widget.conditionId,
title: titleCtrl.text.trim(),
description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
dueDate: due,
completed: completed,
order: _items.isEmpty ? 0 : (_items.map((e) => e.order).reduce((a,b)=>a>b?a:b) + 1),
createdAt: now,
updatedAt: now,
)
: existing.copyWith(
title: titleCtrl.text.trim(),
description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
dueDate: due,
completed: completed,
);
await _service.upsert(m);
// Changes successfully persisted
_sessionChanged = true;
_sessionSavedToCloud = true;
_pendingSnapshotSync = true;
if (mounted) ctx.pop();
if (mounted) await _load();
},
child: Text(existing == null ? 'Add' : 'Save'),
)
],
),
),
);
});
},
);
}

Future<void> _showEducationFor(Milestone m) async {
String? conditionDetailsSummary;
try {
final user = context.read<UserProvider>().currentUser;
final conditionDetails = (user?.preferences['conditionDetails'] as Map<String, dynamic>?) ?? {};
final detailJson = conditionDetails[_selectedConditionId ?? widget.conditionId];
if (detailJson != null) {
final detail = ConditionDetail.fromJson(Map<String, dynamic>.from(detailJson));
if (detail.hasDetails) {
conditionDetailsSummary = detail.toAiSummary(widget.conditionName);
}
}
} catch (e) {
debugPrint('[PlanEditor] Learn more: failed to load condition details (ignored): $e');
}
// Use go_router (Dreamflow routing rule) and pass data via state.extra.
if (!mounted) return;
context.push(
'/milestones/learn-more',
extra: MilestoneEducationArgs(
stepTitle: m.title,
stepDescription: m.description,
conditionName: widget.conditionName,
conditionDetailsSummary: conditionDetailsSummary,
),
);
}

Future<void> _reroll(Milestone m) async {
final uid = context.read<UserProvider>().currentUser?.id;
if (uid == null) return;
setState(() => _rerollingId = m.id);
try {
final idx = _items.indexWhere((e) => e.id == m.id);
final prevTitle = (idx > 0) ? _items[idx - 1].title : null;
final nextTitle = (idx >= 0 && idx + 1 < _items.length) ? _items[idx + 1].title : null;

final ai = OpenAIClient();
Map<String, String> suggestion;
try {
suggestion = await ai.rerollMilestone(
currentTitle: m.title,
currentDescription: m.description,
conditionName: widget.conditionName,
previousTitle: prevTitle,
nextTitle: nextTitle,
);
} catch (e) {
debugPrint('[PlanEditor] Reroll AI failed; falling back to local option: $e');
final options = <Map<String, String?>>[
{
'title': 'Do the 2-minute version of "${m.title}"',
'description': (m.description ?? '').trim().isEmpty
? 'Make it tiny and repeatable. If you have extra energy, you can add one more minute.'
: 'Do the smallest safe version today. ${m.description}',
},
{
'title': 'Prepare for "${m.title}"',
'description': 'Set up anything you need (supplies, reminders, space) so tomorrow is easier.',
},
{
'title': 'Track your progress for "${m.title}"',
'description': 'Log one quick note: easy/medium/hard, and any pain or fatigue change.',
},
];
final pick = options[(DateTime.now().millisecondsSinceEpoch % options.length)];
suggestion = {
'title': (pick['title'] ?? m.title).toString(),
'description': (pick['description'] ?? (m.description ?? '')).toString(),
};
}

final fields = <String, dynamic>{
'title': suggestion['title'] ?? m.title,
'description': (suggestion['description'] ?? '').toString().trim().isEmpty ? null : suggestion['description'],
};
await _service.updateFields(uid, m.id, fields);
_pendingSnapshotSync = true;
if (mounted) await _load();
_sessionChanged = true;
_sessionSavedToCloud = true;
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Step updated')));
}
} catch (e) {
debugPrint('[PlanEditor] Reroll error: $e');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not reroll this step: $e')));
}
} finally {
if (mounted) setState(() => _rerollingId = null);
}
}

Future<void> _reorder(int oldIndex, int newIndex) async {
final list = [..._items];
if (newIndex > oldIndex) newIndex -= 1;
final item = list.removeAt(oldIndex);
list.insert(newIndex, item);
setState(() => _items = list);
// persist new order
final authUserId = SupabaseConfig.auth.currentUser?.id;
if (authUserId == null) {
debugPrint('[PlanEditor] reorder: missing authUserId');
return;
}
for (int i = 0; i < list.length; i++) {
if (list[i].order != i) {
await _service.updateFields(authUserId, list[i].id, {'order': i});
}
}
_pendingSnapshotSync = true;
if (mounted) await _load();
_sessionChanged = true;
_sessionSavedToCloud = true;
}

Future<void> _generateWithAI() async {
  if (_isGenerateSheetOpen) {
    debugPrint('[PlanEditor] _generateWithAI ignored: generate sheet already open');
    return;
  }

  _isGenerateSheetOpen = true;
  debugPrint('🟢🟢🟢 _generateWithAI() called - opening bottom sheet 🟢🟢🟢');
  debugPrint('[PlanEditor] _generateWithAI: _initialQuestionContext="$_initialQuestionContext"');
  final descCtrl = TextEditingController(text: _initialQuestionContext);
  int count = 5;
  String durationUnit = 'weeks'; // 'weeks' | 'days'
  final durationCtrl = TextEditingController(text: '8');
  try {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
return StatefulBuilder(builder: (sheetCtx, setLocal) {
int durationValue() {
final v = int.tryParse(durationCtrl.text.trim());
if (v == null) return durationUnit == 'days' ? 30 : 8;
if (durationUnit == 'days') return v.clamp(1, 365);
return v.clamp(1, 104);
}

int durationDays() {
final value = durationValue();
return durationUnit == 'days' ? value : (value * 7);
}

return GestureDetector(
onTap: () {
// Dismiss keyboard when tapping outside text fields
FocusScope.of(ctx).unfocus();
},
child: SafeArea(
top: false,
child: SingleChildScrollView(
padding: EdgeInsets.fromLTRB(
AppSpacing.lg,
AppSpacing.md,
AppSpacing.lg,
MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text('Generate a plan', style: ctx.textStyles.titleMedium?.semiBold),
IconButton(
onPressed: () => Navigator.of(ctx).pop(),
icon: Icon(Icons.close, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
padding: EdgeInsets.zero,
constraints: const BoxConstraints(),
),
],
),
SizedBox(height: AppSpacing.md),
Container(
padding: const EdgeInsets.all(AppSpacing.md),
decoration: BoxDecoration(
color: Colors.blue.withValues(alpha: 0.1),
borderRadius: BorderRadius.circular(8),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'How to build a plan:',
style: ctx.textStyles.labelMedium?.semiBold,
),
SizedBox(height: AppSpacing.sm),
Text(
'1. Describe your goal or specific constraints (e.g., "improve arm strength for daily activities" or "manage fatigue and pain")',
style: sheetCtx.textStyles.bodySmall,
),
SizedBox(height: AppSpacing.xs),
Text(
'2. Set a realistic timeframe (weeks or days) for your recovery goal',
style: sheetCtx.textStyles.bodySmall,
),
SizedBox(height: AppSpacing.xs),
Text(
'3. Choose the number of steps/milestones to break down your goal (3–8 recommended)',
style: sheetCtx.textStyles.bodySmall,
),
SizedBox(height: AppSpacing.xs),
Text(
'4. A.R.I.E will generate a customized timeline with specific, achievable milestones',
style: sheetCtx.textStyles.bodySmall,
),
],
),
),
SizedBox(height: AppSpacing.md),
TextField(
controller: descCtrl,
decoration: InputDecoration(
labelText: 'Describe your goal or constraints',
hintText: 'e.g., Improve sleep quality with gentle routines, limited energy',
),
maxLines: 3,
),
SizedBox(height: AppSpacing.sm),
LayoutBuilder(
builder: (context, constraints) {
final isNarrow = constraints.maxWidth < 420;
if (isNarrow) {
return Column(children: [
Row(children: [
Expanded(
flex: 1,
child: DropdownButtonFormField<String>(
value: durationUnit,
items: const [
DropdownMenuItem(value: 'weeks', child: Text('Weeks')),
DropdownMenuItem(value: 'days', child: Text('Days')),
],
onChanged: (v) {
final next = v ?? 'weeks';
setLocal(() {
durationUnit = next;
durationCtrl.text = next == 'days' ? '30' : '8';
});
},
decoration: const InputDecoration(labelText: 'Duration unit'),
),
),
SizedBox(width: AppSpacing.sm),
Expanded(
flex: 2,
child: TextFormField(
controller: durationCtrl,
keyboardType: TextInputType.number,
inputFormatters: [FilteringTextInputFormatter.digitsOnly],
decoration: InputDecoration(
labelText: durationUnit == 'days' ? 'Duration (days)' : 'Duration (weeks)',
helperText: durationUnit == 'days' ? '1–365' : '1–104',
),
onChanged: (_) => setLocal(() {}),
),
),
]),
SizedBox(height: AppSpacing.sm),
DropdownButtonFormField<int>(
value: count,
items: [3, 4, 5, 6, 7, 8]
.map((c) => DropdownMenuItem(value: c, child: Text('$c milestones')))
.toList(),
onChanged: (v) => setLocal(() => count = v ?? 5),
decoration: const InputDecoration(labelText: 'Steps'),
),
]);
}
return Row(children: [
Expanded(
flex: 1,
child: DropdownButtonFormField<String>(
value: durationUnit,
items: const [
DropdownMenuItem(value: 'weeks', child: Text('Weeks')),
DropdownMenuItem(value: 'days', child: Text('Days')),
],
onChanged: (v) {
final next = v ?? 'weeks';
setLocal(() {
durationUnit = next;
durationCtrl.text = next == 'days' ? '30' : '8';
});
},
decoration: const InputDecoration(labelText: 'Duration unit'),
),
),
SizedBox(width: AppSpacing.sm),
Expanded(
flex: 1,
child: TextFormField(
controller: durationCtrl,
keyboardType: TextInputType.number,
inputFormatters: [FilteringTextInputFormatter.digitsOnly],
decoration: InputDecoration(
labelText: durationUnit == 'days' ? 'Duration (days)' : 'Duration (weeks)',
helperText: durationUnit == 'days' ? '1–365' : '1–104',
),
onChanged: (_) => setLocal(() {}),
),
),
SizedBox(width: AppSpacing.sm),
Expanded(
flex: 1,
child: DropdownButtonFormField<int>(
value: count,
items: [3, 4, 5, 6, 7, 8]
.map((c) => DropdownMenuItem(value: c, child: Text('$c milestones')))
.toList(),
onChanged: (v) => setLocal(() => count = v ?? 5),
decoration: const InputDecoration(labelText: 'Steps'),
),
),
]);
},
),
SizedBox(height: AppSpacing.md),
FilledButton.icon(
onPressed: _generating
? null
: () async {
debugPrint('🔴🔴🔴 GENERATE BUTTON PRESSED! 🔴🔴🔴');
// Validate that something was entered
if (descCtrl.text.trim().isEmpty) {
debugPrint('⚠️ Description is empty - showing validation error');
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please describe your goal or constraints before generating a plan.')),
);
return;
}
// Use the bottom sheet's local state to reflect UI immediately
try {
setLocal(() => _generating = true);
} catch (_) {
// Fallback in case sheet state isn't available
if (mounted) setState(() => _generating = true);
}
try {
debugPrint('[PlanEditor] Generate plan tapped (offline)');
final description = descCtrl.text.trim();
final dDays = durationDays();
List<Map<String, dynamic>> plan;
try {
String? conditionDetailsSummary;
try {
final user = context.read<UserProvider>().currentUser;
final conditionDetails = (user?.preferences['conditionDetails'] as Map<String, dynamic>?) ?? {};
final detailJson = conditionDetails[_selectedConditionId ?? widget.conditionId];
if (detailJson != null) {
final detail = ConditionDetail.fromJson(Map<String, dynamic>.from(detailJson));
if (detail.hasDetails) conditionDetailsSummary = detail.toAiSummary(widget.conditionName);
}
} catch (e) {
debugPrint('[PlanEditor] Generate plan: condition details parse failed (ignored): $e');
}

final ai = OpenAIClient();
debugPrint('🚀🚀🚀 [PlanEditor] ABOUT TO CALL AI! description="$description", count=$count, durationDays=$dDays, conditionName="${widget.conditionName}"');
final breakdown = await ai.generatePlanBreakdown(
description: description,
milestones: count,
durationDays: dDays,
conditionName: widget.conditionName,
conditionDetailsSummary: conditionDetailsSummary,
);
plan = List<Map<String, dynamic>>.from(breakdown['milestones'] as List? ?? const []);
// Cache the goal-breakdown reasoning so we can surface it in the UI.
final cats = ((breakdown['needCategories'] as List?) ?? const [])
.whereType<Map>()
.map<Map<String, String>>((m) => {
'type': (m['type'] ?? '').toString(),
'reason': (m['reason'] ?? '').toString(),
})
.where((m) => (m['type'] ?? '').isNotEmpty)
.toList();
if (mounted) {
setState(() {
_breakdownGoalSummary = (breakdown['goalSummary'] ?? '').toString();
_breakdownComplexity = (breakdown['complexityLevel'] ?? '').toString();
_breakdownCategories = cats;
});
}
debugPrint('✅✅✅ [PlanEditor] AI plan generated: ${plan.length} items · summary="${_breakdownGoalSummary}" · complexity=${_breakdownComplexity} · categories=${cats.map((c) => c['type']).toList()}');
for (final item in plan) {
debugPrint(' - ${item['title']} (helpType: ${item['helpType']})');
}
} catch (e) {
debugPrint('[PlanEditor] AI generate failed; using offline plan: $e');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('AI is unavailable right now — using offline plan instead.')),
);
}
plan = _quickPlan(description: description, milestones: count, durationDays: dDays);
}
debugPrint('[PlanEditor] Saving generated plan of ${plan.length} items');
final saved = await _saveGeneratedPlan(plan, durationDays: dDays).timeout(const Duration(seconds: 15));
if (saved && mounted) {
await _load();
if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan saved')));
}
} catch (e) {
debugPrint('[PlanEditor] Generate plan error: $e');
if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not generate plan.')));
} finally {
try {
setLocal(() => _generating = false);
} catch (_) {
if (mounted) {
setState(() => _generating = false);
}
}
}
},
icon: _generating
? SizedBox(
width: 16,
height: 16,
child: const InlineLoadingDot(),
)
: Icon(Icons.auto_awesome, color: Theme.of(sheetCtx).colorScheme.onPrimary),
label: Text(_generating ? 'Please wait…' : 'Generate Plan'),
),
],
),
),
),
);
  });
  },
  );
  } finally {
    // Clear the Ask ARIE prefill after the first open so repeated _load() calls
    // don't attempt to re-open or re-prefill.
    _initialQuestionContext = '';
    _isGenerateSheetOpen = false;
    descCtrl.dispose();
    durationCtrl.dispose();
  }
}

List<Map<String, dynamic>> _quickPlan({
required String description,
required int milestones,
required int durationDays,
}) {
final totalDays = durationDays.clamp(1, 730);
final days = _distributeDays(total: totalDays, count: milestones);
final timesByDay = _assignTimesForSameDays(days);

// Rotate through help types so the offline fallback also demonstrates the
// Goal Breakdown Engine categories.
const rotation = <String>[
'learning', 'expert', 'action', 'tracking', 'community', 'environment', 'product',
];
return List.generate(milestones, (i) {
final day = days[i];
final dueTime = timesByDay[i];
final helpType = rotation[i % rotation.length];
return {
'title': 'Step ${i + 1}',
'description': i == 0
? (description.isEmpty
? 'Kickoff: Begin gently and set a baseline toward your stated goal.'
: 'Kickoff toward "$description": set a gentle baseline you can repeat.')
: (description.isEmpty
? 'Continue with the routine. Adjust based on how you feel each day.'
: 'Continue working on "$description". Adjust based on how you feel each day.'),
'dueInDays': day,
'helpType': helpType,
if (dueTime != null) 'dueTime': dueTime,
};
});
}

List<int> _distributeDays({required int total, required int count}) {
if (count <= 0) return const [];
if (total <= 1) return List<int>.filled(count, 1);
if (count == 1) return [total];
return List<int>.generate(count, (i) {
final v = ((i) * total / (count - 1)).round();
return (v + 1).clamp(1, total);
});
}

List<String> _suggestTimes(int count) {
const base = <String>['09:00', '12:30', '15:30', '18:30', '20:30'];
if (count <= base.length) return base.take(count).toList();
final out = <String>[...base];
int hour = 8;
while (out.length < count) {
final h = (hour % 24).toString().padLeft(2, '0');
out.add('$h:00');
hour += 1;
}
return out;
}

/// Returns per-milestone dueTime strings (or null) aligned with the [days] list.
/// Only milestones sharing a day get times.
List<String?> _assignTimesForSameDays(List<int> days) {
final idxsByDay = <int, List<int>>{};
for (int i = 0; i < days.length; i++) {
(idxsByDay[days[i]] ??= []).add(i);
}
final out = List<String?>.filled(days.length, null);
for (final entry in idxsByDay.entries) {
final idxs = entry.value;
if (idxs.length <= 1) continue;
final times = _suggestTimes(idxs.length);
for (int j = 0; j < idxs.length; j++) {
out[idxs[j]] = times[j];
}
}
return out;
}

DateTime _applyDueTime(DateTime date, String? dueTimeRaw) {
final raw = (dueTimeRaw ?? '').trim();
if (raw.isEmpty) return date;

// Support "HH:mm" first.
final hm = RegExp(r'^(\\d{1,2}):(\\d{2})$').firstMatch(raw);
if (hm != null) {
final h = int.tryParse(hm.group(1)!) ?? 0;
final m = int.tryParse(hm.group(2)!) ?? 0;
return DateTime(date.year, date.month, date.day, h.clamp(0, 23), m.clamp(0, 59));
}

// Support "h:mm AM/PM" or "h AM/PM".
final ampm = RegExp(r'^(\\d{1,2})(?::(\\d{2}))?\\s*(AM|PM)$', caseSensitive: false).firstMatch(raw);
if (ampm != null) {
var h = int.tryParse(ampm.group(1)!) ?? 0;
final m = int.tryParse(ampm.group(2) ?? '0') ?? 0;
final mer = (ampm.group(3) ?? '').toUpperCase();
h = h.clamp(1, 12);
int hour24 = h % 12;
if (mer == 'PM') hour24 += 12;
return DateTime(date.year, date.month, date.day, hour24, m.clamp(0, 59));
}

return date;
}

/// Attempts to persist the generated plan. On web or when Firestore rules
/// deny writes, we gracefully fall back to an in-memory draft so the
/// experience still "works on first click" and the user can see their plan.
///
/// Returns true if the plan was saved to Firestore, false if shown as a
/// local draft (session-only).
Future<bool> _saveGeneratedPlan(List<Map<String, dynamic>> plan, {required int durationDays}) async {
// Use auth user ID for milestones and timelines (both reference auth.users)
String? authUserId = SupabaseConfig.auth.currentUser?.id;
if (authUserId == null) {
debugPrint('[PlanEditor] Aborting save: no auth user');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to save your plan.')));
}
// Fall back to local-only draft so generation still appears usable
final now = DateTime.now();
final baseDate = DateTime(now.year, now.month, now.day);
final newItems = <Milestone>[];
// Ensure schedule is sane and time-assigned for same-day milestones.
final normalized = _normalizePlanSchedule(plan, durationDays: durationDays);
for (int i = 0; i < normalized.length; i++) {
final p = normalized[i];
final dueIn = (p['dueInDays'] is int)
? p['dueInDays'] as int
: (int.tryParse('${p['dueInDays']}') ?? ((i + 1) * 7));
final dueTime = (p['dueTime'] ?? '').toString().trim();
final dueDate = _applyDueTime(baseDate.add(Duration(days: dueIn)), dueTime.isEmpty ? null : dueTime);
newItems.add(
Milestone(
id: 'draft_${const Uuid().v4()}',
userId: 'local',
conditionId: _selectedConditionId ?? widget.conditionId,
title: (p['title'] ?? 'Milestone ${i + 1}').toString(),
description: (p['description'] ?? '').toString().isEmpty ? null : (p['description'] ?? '').toString(),
dueDate: dueDate,
order: i,
helpType: (p['helpType'] ?? p['help_type'])?.toString().trim().isEmpty == false
? (p['helpType'] ?? p['help_type']).toString()
: null,
createdAt: now,
updatedAt: now,
),
);
}
setState(() => _items = newItems);
_sessionChanged = true;
_sessionSavedToCloud = false;
return false;
}
final now = DateTime.now();
final baseDate = DateTime(now.year, now.month, now.day);
// Build new milestones list
final newItems = <Milestone>[];
debugPrint('📋 [PlanEditor] plan.length BEFORE normalize: ${plan.length}');
final normalized = _normalizePlanSchedule(plan, durationDays: durationDays);
debugPrint('📋 [PlanEditor] normalized.length AFTER normalize: ${normalized.length}');
for (int i = 0; i < normalized.length; i++) {
final p = normalized[i];
final dueIn = (p['dueInDays'] is int)
? p['dueInDays'] as int
: (int.tryParse('${p['dueInDays']}') ?? ((i + 1) * 7));
final dueTime = (p['dueTime'] ?? '').toString().trim();
final dueDate = _applyDueTime(baseDate.add(Duration(days: dueIn)), dueTime.isEmpty ? null : dueTime);
final helpTypeValue = (p['helpType'] ?? p['help_type'])?.toString().trim().isEmpty == false
? (p['helpType'] ?? p['help_type']).toString()
: null;
debugPrint('🔶 [PlanEditor] RAW MAP DATA for milestone ${i+1}: $p');
debugPrint('🔶 [PlanEditor] Creating milestone ${i+1}/${normalized.length}: "${(p['title'] ?? 'Milestone ${i + 1}').toString()}" with helpType: "$helpTypeValue"');
newItems.add(
Milestone(
id: const Uuid().v4(),
userId: authUserId,
conditionId: _selectedConditionId ?? widget.conditionId,
title: (p['title'] ?? 'Milestone ${i + 1}').toString(),
description: (p['description'] ?? '').toString().isEmpty ? null : (p['description'] ?? '').toString(),
dueDate: dueDate,
order: i,
helpType: helpTypeValue,
createdAt: now,
updatedAt: now,
),
);
debugPrint('[PlanEditor] ✓ Milestone ${i+1} added to newItems (total so far: ${newItems.length})');
}
debugPrint('🎉 [PlanEditor] Loop complete! Created ${newItems.length} milestones total');
// Create a new timeline for the generated plan
try {
final timelineName = _generatePlanName(
milestoneCount: newItems.length,
durationDays: durationDays,
goalSummary: _breakdownGoalSummary.isNotEmpty ? _breakdownGoalSummary : null,
createdAt: now,
);
final timeline = await _timelineService.createFromMilestones(
userId: authUserId,
conditionId: _selectedConditionId ?? widget.conditionId,
conditionName: _selectedConditionName,
name: timelineName,
milestones: newItems,
setCurrent: false,
);
debugPrint('[PlanEditor] Created new timeline "$timelineName" with ${newItems.length} items');

// Activate the timeline and replace the active plan
await _timelineService.setCurrentAndActivate(
timeline: timeline,
userId: authUserId,
conditionId: _selectedConditionId ?? widget.conditionId,
replaceActivePlan: true,
);
debugPrint('[PlanEditor] Activated timeline "$timelineName"');

_sessionChanged = true;
_sessionSavedToCloud = true;
_pendingSnapshotSync = false;
return true;
} catch (e) {
final msg = e.toString();
debugPrint('[PlanEditor] Persist failed, falling back to local draft: $e');
if (mounted) {
String friendly = 'Showing plan locally';
if (msg.contains('permission-denied')) {
friendly = 'Showing plan locally due to permissions. It will sync after access is fixed.';
}
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendly)));
}
// Show locally so the first click feels responsive
setState(() => _items = newItems);
_sessionChanged = true;
_sessionSavedToCloud = false;
_pendingSnapshotSync = true;
return false;
}
}

List<Map<String, dynamic>> _normalizePlanSchedule(List<Map<String, dynamic>> plan, {required int durationDays}) {
if (plan.isEmpty) return plan;

// Parse dueInDays, fallback distribute.
final out = <Map<String, dynamic>>[];
bool allHaveDay = true;
for (final m in plan) {
final raw = m['dueInDays'];
int? d;
if (raw is int) {
d = raw;
} else {
d = int.tryParse(raw?.toString() ?? '');
}
if (d == null) allHaveDay = false;
out.add({...m, 'dueInDays': d});
}

// Ensure schedule fits the chosen durationDays.
final total = durationDays.clamp(1, 730);
if (!allHaveDay) {
final days = _distributeDays(total: total, count: out.length);
for (int i = 0; i < out.length; i++) {
out[i]['dueInDays'] = days[i];
}
}
int prev = 1;
for (int i = 0; i < out.length; i++) {
final d = (out[i]['dueInDays'] as int).clamp(1, total);
final next = d < prev ? prev : d;
out[i]['dueInDays'] = next;
prev = next;
}

final days = out.map((e) => e['dueInDays'] as int).toList();
final assignedTimes = _assignTimesForSameDays(days);
for (int i = 0; i < out.length; i++) {
final has = (out[i]['dueTime'] ?? '').toString().trim();
final t = assignedTimes[i];
if (has.isEmpty && t != null) out[i]['dueTime'] = t;
}
return out;
}

Future<void> _sharePlan() async {
if (_items.isEmpty) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add milestones before sharing your plan.')));
return;
}
final userProv = context.read<UserProvider>();
if (userProv.currentUser == null) {
try {
await userProv.loadUser();
} catch (_) {}
}
final user = userProv.currentUser;
if (user == null) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to share your plan.')));
return;
}

const initialNote = 'Copy to your plan and check off each milestone as you go.';
final result = await showModalBottomSheet<PlanShareResult>(
context: context,
isScrollControlled: true,
showDragHandle: true,
backgroundColor: Theme.of(context).colorScheme.surface,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
builder: (ctx) => PlanShareSheet(
conditionName: widget.conditionName,
milestones: _items,
initialNote: initialNote,
loadCommunities: _groupService.getJoinedGroups,
),
);

if (result == null) return;
final content = result.content.trim();
if (content.isEmpty) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template cannot be empty.')));
return;
}

setState(() => _sharing = true);
try {
final now = DateTime.now();
final related = <String>{_selectedConditionId ?? widget.conditionId, ...user.conditions};
final post = Post(
id: const Uuid().v4(),
authorId: user.id,
authorName: user.name,
authorImageUrl: user.profileImageUrl,
content: content,
communityId: result.community?.id,
type: 'plan_template',
relatedConditions: related.toList(),
likesCount: 0,
commentsCount: 0,
createdAt: now,
updatedAt: now,
);
await _postService.addPost(post);
if (!mounted) return;
final destination = result.community?.name ?? 'feed';
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Shared to $destination')));
} catch (e) {
debugPrint('[PlanEditor] Share error: $e');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share plan: $e')));
}
} finally {
if (mounted) setState(() => _sharing = false);
}
}

Future<void> _openTimelineSwitcher() async {
if (_timelines.isEmpty || _timelineBusy) return;
final result = await showModalBottomSheet<Map<String, String>>(
context: context,
isScrollControlled: true,
showDragHandle: true,
backgroundColor: Theme.of(context).colorScheme.surface,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
builder: (ctx) {
return SafeArea(
top: false,
child: SingleChildScrollView(
padding: AppSpacing.paddingLg,
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Switch timeline', style: ctx.textStyles.titleMedium?.semiBold),
SizedBox(height: AppSpacing.sm),
..._timelines.map((t) {
final subtitle = '${t.milestones.length} steps · Updated ${MaterialLocalizations.of(ctx).formatShortDate(t.updatedAt)}';
return ListTile(
contentPadding: EdgeInsets.zero,
leading: Icon(t.isCurrent ? Icons.check_circle : Icons.radio_button_unchecked,
color: t.isCurrent ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).colorScheme.onSurfaceVariant),
title: Text(t.name, style: ctx.textStyles.titleSmall?.semiBold),
subtitle: Text(subtitle, style: ctx.textStyles.bodySmall?.withColor(Theme.of(ctx).colorScheme.onSurfaceVariant)),
trailing: Row(
mainAxisSize: MainAxisSize.min,
children: [
t.isCurrent
? Chip(label: const Text('Current'))
: TextButton(onPressed: () => Navigator.of(ctx).pop({'switch': t.id}), child: const Text('Set current')),
if (!t.isCurrent)
IconButton(
icon: const Icon(Icons.delete_outline),
tooltip: 'Delete',
onPressed: () => Navigator.of(ctx).pop({'delete': t.id}),
),
],
),
onTap: () => Navigator.of(ctx).pop({'switch': t.id}),
);
}).toList(),
],
),
),
);
},
);

if (result == null) return;
if (!mounted) return;
if (result['delete'] != null) {
final toDelete = _timelines.firstWhere((t) => t.id == result['delete'], orElse: () => _timelines.first);
await _deleteTimeline(toDelete);
return;
}

final selectedId = result['switch'];
if (selectedId == null) return;
PlanTimeline? selected;
for (final t in _timelines) {
if (t.id == selectedId) {
selected = t;
break;
}
}
selected ??= _currentTimeline;
selected ??= _timelines.isNotEmpty ? _timelines.first : null;
if (selected == null || selected.isCurrent) return;
await _activateTimeline(selected);
}

Future<void> _saveTimelineFromCurrent() async {
final authUserId = SupabaseConfig.auth.currentUser?.id;
if (authUserId == null) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to save timelines.')));
return;
}

final nameCtrl = TextEditingController(text: _suggestTimelineName());
bool setCurrent = true;
final result = await showModalBottomSheet<Map<String, dynamic>>(
context: context,
isScrollControlled: true,
showDragHandle: true,
backgroundColor: Theme.of(context).colorScheme.surface,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
builder: (ctx) {
return StatefulBuilder(builder: (ctx, setLocal) {
return SafeArea(
top: false,
child: SingleChildScrollView(
padding: EdgeInsets.fromLTRB(
AppSpacing.lg,
AppSpacing.md,
AppSpacing.lg,
MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Save timeline', style: ctx.textStyles.titleMedium?.semiBold),
SizedBox(height: AppSpacing.sm),
TextField(
controller: nameCtrl,
decoration: const InputDecoration(labelText: 'Name'),
),
CheckboxListTile(
contentPadding: EdgeInsets.zero,
value: setCurrent,
onChanged: (v) => setLocal(() => setCurrent = v ?? true),
title: const Text('Set as current'),
subtitle: const Text('Replace the active plan with this version'),
controlAffinity: ListTileControlAffinity.leading,
),
SizedBox(height: AppSpacing.md),
FilledButton(
onPressed: () {
Navigator.of(ctx).pop({
'name': nameCtrl.text.trim(),
'setCurrent': setCurrent,
});
},
child: const Text('Save'),
)
],
),
),
);
});
},
);

if (result == null) return;
final name = (result['name'] as String?)?.trim() ?? '';
final setCurrentChoice = result['setCurrent'] == true;
if (name.isEmpty) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please name your timeline.')));
return;
}

setState(() => _timelineBusy = true);
try {
await _timelineService.createFromMilestones(
userId: authUserId,
conditionId: _selectedConditionId ?? widget.conditionId,
conditionName: _selectedConditionName,
name: name,
milestones: _items,
setCurrent: setCurrentChoice,
);
await _load();
if (mounted) {
final suffix = setCurrentChoice ? ' and set as current' : '';
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved "$name"$suffix')));
}
} catch (e) {
debugPrint('[PlanEditor] Save timeline error: $e');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save timeline: $e')));
}
} finally {
if (mounted) setState(() => _timelineBusy = false);
}
}

Future<void> _activateTimeline(PlanTimeline timeline) async {
final authUserId = SupabaseConfig.auth.currentUser?.id;
if (authUserId == null) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to switch timelines.')));
return;
}
setState(() => _timelineBusy = true);
try {
await _timelineService.setCurrentAndActivate(
timeline: timeline,
userId: authUserId,
conditionId: _selectedConditionId ?? widget.conditionId,
);
_pendingSnapshotSync = false;
await _load();
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Switched to ${timeline.name}')));
}
} catch (e) {
debugPrint('[PlanEditor] Activate timeline error: $e');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not switch timeline: $e')));
}
} finally {
if (mounted) setState(() => _timelineBusy = false);
}
}

Future<void> _deleteTimeline(PlanTimeline timeline) async {
if (_timelineBusy) return;
if (timeline.isCurrent) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Switch to another version before deleting this one.')));
return;
}

if (_timelines.length <= 1) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keep at least one timeline.')));
return;
}

final authUserId = SupabaseConfig.auth.currentUser?.id;
if (authUserId == null) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to manage timelines.')));
return;
}

final confirmed = await showDialog<bool>(
context: context,
builder: (ctx) {
return AlertDialog(
title: const Text('Delete timeline?'),
content: Text('This removes "${timeline.name}" but keeps your active plan.'),
actions: [
TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
],
);
},
);

if (confirmed != true || !mounted) return;

setState(() => _timelineBusy = true);
try {
await _timelineService.deleteTimeline(
timelineId: timeline.id,
userId: authUserId,
conditionId: _selectedConditionId ?? widget.conditionId,
);
await _load();
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted ${timeline.name}')));
}
} catch (e) {
debugPrint('[PlanEditor] Delete timeline error: $e');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
}
} finally {
if (mounted) setState(() => _timelineBusy = false);
}
}

String _suggestTimelineName() {
final base = widget.conditionName.isNotEmpty ? widget.conditionName : 'Plan';
return '$base timeline ${_timelines.length + 1}';
}

String _generatePlanName({
required int milestoneCount,
required int durationDays,
required String? goalSummary,
required DateTime createdAt,
}) {
final formatter = DateFormat('MMM d, yyyy');
final date = formatter.format(createdAt);

// Determine phase name based on duration
final weeks = (durationDays / 7).round();
String phase = 'Recovery';
if (weeks <= 2) {
phase = 'Kickoff';
} else if (weeks <= 4) {
phase = 'Early Recovery';
} else if (weeks <= 8) {
phase = 'Core Recovery';
} else if (weeks <= 12) {
phase = 'Extended Recovery';
} else {
phase = 'Long-term Recovery';
}

// Build the name with goal summary if available
if (goalSummary != null && goalSummary.trim().isNotEmpty) {
final summary = goalSummary.trim();
// Limit summary to first 30 chars to avoid overly long names
final truncated = summary.length > 30 ? '${summary.substring(0, 30)}...' : summary;
return '$phase Plan • $truncated • $date';
}

// Fallback: use condition name and step count
final condition = _selectedConditionName.isNotEmpty ? _selectedConditionName : 'Recovery';
return '$phase Plan • $condition ($milestoneCount steps) • $date';
}


@override
Widget build(BuildContext context) {
// Determine the current (first incomplete) milestone index
final currentIndex = _items.indexWhere((m) => !m.completed);
return Scaffold(
backgroundColor: Colors.transparent,
    // Keeping body below the AppBar avoids iOS notch/status-bar clipping.
    extendBodyBehindAppBar: false,
appBar: AppBar(
centerTitle: true,
automaticallyImplyLeading: false,
title: GestureDetector(
onTap: _userConditions.length > 1 ? _showConditionSelector : null,
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Flexible(
child: Text(
'Plan • ${_selectedConditionName}',
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
),
if (_userConditions.length > 1) ...[
const SizedBox(width: 4),
Icon(
Icons.arrow_drop_down,
color: Theme.of(context).colorScheme.primary,
),
],
],
),
),
actions: [
IconButton(
onPressed: _sharing ? null : _sharePlan,
icon: _sharing
? const SizedBox(width: 18, height: 18, child: InlineLoadingDot())
: Icon(Icons.ios_share, color: Theme.of(context).colorScheme.primary),
tooltip: 'Share plan',
),
IconButton(
onPressed: _generateWithAI,
icon: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
tooltip: 'Generate plan',
),
IconButton(
onPressed: () => _addOrEdit(),
icon: Icon(Icons.add_task, color: Theme.of(context).colorScheme.primary),
tooltip: 'Add milestone',
),
],
),
body: Stack(
fit: StackFit.expand,
children: [
const ThemedBackgroundImage(),
SafeArea(
            // Let SafeArea handle the notch/status bar inset.
child: _loading
? const Center(child: CenteredLoadingSkeleton())
: _items.isEmpty
? _EmptyState(
onGenerate: _generateWithAI,
onAdd: () => _addOrEdit(),
current: _currentTimeline,
timelines: _timelines,
busy: _timelineBusy,
onSwitch: _openTimelineSwitcher,
onSave: _saveTimelineFromCurrent,
)
: CustomScrollView(
slivers: [
SliverToBoxAdapter(
child: Padding(
padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
child: _TimelineSelector(
current: _currentTimeline,
timelines: _timelines,
busy: _timelineBusy,
onSwitch: _openTimelineSwitcher,
onSave: _saveTimelineFromCurrent,
),
),
),
if (_breakdownCategories.isNotEmpty || _breakdownGoalSummary.trim().isNotEmpty)
SliverToBoxAdapter(
child: Padding(
padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
child: GoalBreakdownCard(
goalSummary: _breakdownGoalSummary,
complexityLevel: _breakdownComplexity,
needCategories: _breakdownCategories,
onDismiss: () => setState(() {
_breakdownGoalSummary = '';
_breakdownComplexity = '';
_breakdownCategories = const [];
}),
),
),
),
SliverToBoxAdapter(
child: Padding(
padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
child: Row(
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Your plan',
style: context.textStyles.titleLarge?.copyWith(
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 2),
Text(
_collapseFuture ? 'Future steps are collapsed' : 'All steps visible',
style: context.textStyles.bodySmall?.withColor(Theme.of(context).colorScheme.onSurfaceVariant),
),
],
),
),
_PlanToggleChip(
isCollapsed: _collapseFuture,
onPressed: () => setState(() => _collapseFuture = !_collapseFuture),
),
],
),
),
),
SliverReorderableList(
itemCount: _items.length,
onReorder: _reorder,
itemBuilder: (context, index) {
final m = _items[index];
final isCurrent = (currentIndex != -1 && index == currentIndex && !m.completed);
final isFuture = (currentIndex != -1 && index > currentIndex && !m.completed);
final collapsed = _collapseFuture && isFuture && !_expandedFuture.contains(m.id);
return Padding(
key: ValueKey(m.id),
padding: index == 0
? AppSpacing.paddingLg.copyWith(top: AppSpacing.md)
: AppSpacing.paddingLg.copyWith(top: 0),
child: _MilestoneTile(
key: ValueKey('${m.id}_tile'),
milestone: m,
index: index,
isCurrent: isCurrent,
collapsed: collapsed,
isRerolling: _rerollingId == m.id,
onToggleExpand: collapsed ? () => setState(() => _expandedFuture.add(m.id)) : null,
onToggle: () async {
final authUserId = SupabaseConfig.auth.currentUser?.id;
if (authUserId == null) return;
await _service.updateFields(authUserId, m.id, {'completed': !m.completed});
_pendingSnapshotSync = true;
if (mounted) await _load();
},
onEdit: () => _addOrEdit(existing: m),
onDelete: () async {
final authUserId = SupabaseConfig.auth.currentUser?.id;
if (authUserId == null) return;
await _service.delete(authUserId, m.id);
_pendingSnapshotSync = true;
if (mounted) await _load();

// Auto-delete timeline if it has 0 milestones
if (mounted && _currentTimeline != null) {
if (_items.isEmpty) {
try {
debugPrint('[PlanEditor] Auto-deleting empty timeline: \\${_currentTimeline!.name}');
await _timelineService.deleteTimeline(
timelineId: _currentTimeline!.id,
userId: authUserId,
conditionId: _selectedConditionId ?? widget.conditionId,
);
if (mounted) {
await _load();
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Deleted "\\${_currentTimeline?.name}" (no steps left)')),
);
}
} catch (e) {
debugPrint('[PlanEditor] Auto-delete timeline failed: $e');
}
}
}
},
onLearnMore: () => _showEducationFor(m),
onReroll: () => _reroll(m),
),
);
},
),
],
),
),
],
),
);
}

Future<void> _showConditionSelector() async {
if (_userConditions.isEmpty) return;

final selected = await showModalBottomSheet<Condition>(
context: context,
isScrollControlled: true,
showDragHandle: true,
backgroundColor: Theme.of(context).colorScheme.surface,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
),
builder: (ctx) {
return SafeArea(
top: false,
child: SingleChildScrollView(
padding: AppSpacing.paddingLg,
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Select condition', style: ctx.textStyles.titleMedium?.semiBold),
SizedBox(height: AppSpacing.md),
..._userConditions.map((condition) {
final isSelected = condition.id == _selectedConditionId;
return ListTile(
contentPadding: EdgeInsets.zero,
leading: Icon(
isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
color: isSelected
? Theme.of(ctx).colorScheme.primary
: Theme.of(ctx).colorScheme.onSurfaceVariant,
),
title: Text(
condition.name,
style: ctx.textStyles.titleSmall?.copyWith(
fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
),
),
onTap: () => Navigator.of(ctx).pop(condition),
);
}).toList(),
],
),
),
);
},
);

if (selected == null || selected.id == _selectedConditionId) return;

setState(() {
_selectedConditionId = selected.id;
_selectedConditionName = selected.name;
_loading = true;
});

await _load();
}
}

class _PlanToggleChip extends StatelessWidget {
final bool isCollapsed;
final VoidCallback onPressed;
const _PlanToggleChip({required this.isCollapsed, required this.onPressed});

@override
Widget build(BuildContext context) {
final cs = Theme.of(context).colorScheme;
final isDark = Theme.of(context).brightness == Brightness.dark;

return Material(
color: Colors.transparent,
child: InkWell(
onTap: onPressed,
borderRadius: BorderRadius.circular(12),
child: AnimatedContainer(
duration: const Duration(milliseconds: 200),
curve: Curves.easeOut,
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
decoration: BoxDecoration(
color: isCollapsed
? cs.primary.withValues(alpha: isDark ? 0.2 : 0.15)
: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.3),
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: isCollapsed
? cs.primary.withValues(alpha: isDark ? 0.5 : 0.4)
: cs.outline.withValues(alpha: isDark ? 0.3 : 0.2),
width: 1.5,
),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
isCollapsed ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
size: 18,
color: isCollapsed ? cs.primary : cs.onSurface,
),
const SizedBox(width: 6),
Text(
isCollapsed ? 'Show all' : 'Hide future',
style: context.textStyles.labelLarge?.copyWith(
color: isCollapsed ? cs.primary : cs.onSurface,
fontWeight: FontWeight.w600,
),
),
],
),
),
),
);
}
}

class _MilestoneTile extends StatelessWidget {
final Milestone milestone;
final int index;
final VoidCallback onToggle;
final VoidCallback onEdit;
final VoidCallback onDelete;
final VoidCallback onLearnMore;
final VoidCallback onReroll;
final bool isCurrent;
final bool collapsed;
final VoidCallback? onToggleExpand;
final bool isRerolling;

const _MilestoneTile({super.key, required this.milestone, required this.index, required this.onToggle, required this.onEdit, required this.onDelete, required this.onLearnMore, required this.onReroll, this.isCurrent = false, this.collapsed = false, this.onToggleExpand, this.isRerolling = false});

@override
Widget build(BuildContext context) {
final cs = Theme.of(context).colorScheme;
final now = DateTime.now();
final isOverdue = (milestone.dueDate != null && (milestone.dueDate!.isBefore(DateTime(now.year, now.month, now.day))) && !milestone.completed);
final isDark = Theme.of(context).brightness == Brightness.dark;

return AnimatedContainer(
duration: const Duration(milliseconds: 200),
curve: Curves.easeOut,
margin: EdgeInsets.only(bottom: AppSpacing.md),
child: Container(
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(20),
gradient: isCurrent && !milestone.completed
? LinearGradient(
colors: isDark
? [
cs.primaryContainer.withValues(alpha: 0.15),
cs.primaryContainer.withValues(alpha: 0.08),
]
: [
cs.primaryContainer.withValues(alpha: 0.4),
cs.primaryContainer.withValues(alpha: 0.2),
],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
)
: null,
color: isCurrent && !milestone.completed
? null
: (milestone.completed
? cs.surfaceContainerHighest.withValues(alpha: 0.5)
: cs.surface),
border: Border.all(
color: isCurrent && !milestone.completed
? cs.primary.withValues(alpha: isDark ? 0.6 : 0.4)
: isOverdue
? cs.error.withValues(alpha: 0.4)
: cs.outline.withValues(alpha: isDark ? 0.2 : 0.15),
width: isCurrent && !milestone.completed ? 2 : 1,
),
boxShadow: isCurrent && !milestone.completed
? [
BoxShadow(
color: cs.primary.withValues(alpha: isDark ? 0.2 : 0.1),
blurRadius: 12,
offset: const Offset(0, 4),
),
]
: [
BoxShadow(
color: cs.shadow.withValues(alpha: isDark ? 0.3 : 0.05),
blurRadius: 8,
offset: const Offset(0, 2),
),
],
),
child: Padding(
padding: const EdgeInsets.all(18),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_MilestoneCheck(checked: milestone.completed, isCurrent: isCurrent, onPressed: onToggle),
SizedBox(width: AppSpacing.md),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
if (isCurrent && !milestone.completed)
Container(
margin: EdgeInsets.only(bottom: AppSpacing.xs),
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
decoration: BoxDecoration(
color: cs.primary,
borderRadius: BorderRadius.circular(8),
),
child: Text(
'NEXT STEP',
style: context.textStyles.labelSmall?.copyWith(
color: cs.onPrimary,
fontWeight: FontWeight.w700,
letterSpacing: 0.5,
),
),
),
if ((milestone.helpType ?? '').isNotEmpty)
Padding(
padding: EdgeInsets.only(bottom: AppSpacing.xs),
child: HelpTypeChip(helpType: milestone.helpType!),
),
Text(
milestone.title,
style: context.textStyles.titleMedium?.copyWith(
decoration: TextDecoration.none,
color: milestone.completed
? cs.onSurfaceVariant.withValues(alpha: 0.7)
: cs.onSurface,
fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
height: 1.3,
),
),
],
),
),
if (collapsed && onToggleExpand != null)
IconButton(
onPressed: onToggleExpand,
icon: Icon(Icons.unfold_more, color: cs.onSurfaceVariant, size: 20),
tooltip: 'Expand',
padding: const EdgeInsets.all(8),
),
ReorderableDragStartListener(
index: index,
child: Padding(
padding: const EdgeInsets.all(4),
child: Icon(
Icons.drag_indicator,
color: cs.onSurfaceVariant.withValues(alpha: 0.5),
size: 20,
),
),
),
],
),
AnimatedSwitcher(
duration: const Duration(milliseconds: 200),
switchInCurve: Curves.easeOut,
switchOutCurve: Curves.easeIn,
child: (!collapsed && milestone.description != null && milestone.description!.isNotEmpty)
? Padding(
key: const ValueKey('desc'),
padding: EdgeInsets.only(top: AppSpacing.sm),
child: Text(
milestone.description!,
style: context.textStyles.bodyMedium?.copyWith(
color: cs.onSurfaceVariant,
height: 1.5,
),
),
)
: const SizedBox.shrink(key: ValueKey('no_desc')),
),
if (milestone.dueDate != null) ...[
SizedBox(height: AppSpacing.md),
_MilestoneMetaRow(isOverdue: isOverdue, dueDate: milestone.dueDate!),
],
if (!collapsed) ...[
SizedBox(height: AppSpacing.md),
if (isCurrent && !milestone.completed) ...[
FilledButton.icon(
onPressed: onToggle,
icon: const Icon(Icons.check_circle),
label: const Text('Mark complete'),
style: FilledButton.styleFrom(
minimumSize: const Size(double.infinity, 48),
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
),
),
if ((milestone.helpType ?? '').isNotEmpty) ...[
SizedBox(height: AppSpacing.sm),
SizedBox(
width: double.infinity,
child: HelpTypeActionButton(
helpType: milestone.helpType,
milestoneTitle: milestone.title,
milestoneDescription: milestone.description,
onLearn: onLearnMore,
outlined: false,
),
),
],
SizedBox(height: AppSpacing.sm),
Row(
children: [
Expanded(
child: OutlinedButton.icon(
onPressed: onLearnMore,
icon: Icon(Icons.school, size: 18),
label: const Text('Learn'),
style: OutlinedButton.styleFrom(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
),
),
),
SizedBox(width: AppSpacing.sm),
Expanded(
child: OutlinedButton.icon(
onPressed: isRerolling ? null : onReroll,
icon: isRerolling
? const SizedBox(width: 18, height: 18, child: InlineLoadingDot())
: const Icon(Icons.shuffle, size: 18),
label: const Text('Reroll'),
style: OutlinedButton.styleFrom(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
),
),
),
],
),
SizedBox(height: AppSpacing.xs),
Row(
children: [
TextButton.icon(
onPressed: onEdit,
icon: const Icon(Icons.edit, size: 16),
label: const Text('Edit'),
style: TextButton.styleFrom(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
),
),
TextButton.icon(
onPressed: onDelete,
icon: const Icon(Icons.delete_outline, size: 16),
label: const Text('Delete'),
style: TextButton.styleFrom(
foregroundColor: cs.error,
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
),
),
],
),
] else ...[
Wrap(
spacing: 8,
runSpacing: 8,
children: [
_CompactAction(onPressed: onLearnMore, icon: Icons.school, label: 'Learn'),
_CompactAction(onPressed: isRerolling ? null : onReroll, icon: Icons.shuffle, label: 'Reroll', busy: isRerolling),
_CompactAction(onPressed: onEdit, icon: Icons.edit, label: 'Edit'),
_CompactAction(onPressed: onDelete, icon: Icons.delete_outline, label: 'Delete', isDestructive: true),
],
),
],
],
],
),
),
],
),
),
),
);
}
}

class _MilestoneCheck extends StatelessWidget {
final bool checked;
final bool isCurrent;
final VoidCallback onPressed;
const _MilestoneCheck({required this.checked, required this.isCurrent, required this.onPressed});

@override
Widget build(BuildContext context) {
final cs = Theme.of(context).colorScheme;
final isDark = Theme.of(context).brightness == Brightness.dark;

return InkWell(
onTap: onPressed,
borderRadius: BorderRadius.circular(12),
child: AnimatedContainer(
duration: const Duration(milliseconds: 200),
curve: Curves.easeOut,
width: 44,
height: 44,
decoration: BoxDecoration(
color: checked
? cs.primary
: (isDark ? cs.surfaceContainerHighest : cs.surfaceVariant.withValues(alpha: 0.5)),
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: checked
? cs.primary
: cs.outline.withValues(alpha: isDark ? 0.3 : 0.2),
width: checked ? 2.5 : 2,
),
boxShadow: checked
? [
BoxShadow(
color: cs.primary.withValues(alpha: 0.3),
blurRadius: 8,
offset: const Offset(0, 2),
),
]
: null,
),
child: Icon(
checked ? Icons.check_rounded : Icons.circle_outlined,
color: checked ? cs.onPrimary : cs.onSurfaceVariant,
size: 22,
),
),
);
}
}

class _MilestoneMetaRow extends StatelessWidget {
final bool isOverdue;
final DateTime dueDate;
const _MilestoneMetaRow({required this.isOverdue, required this.dueDate});

@override
Widget build(BuildContext context) {
final cs = Theme.of(context).colorScheme;
final isDark = Theme.of(context).brightness == Brightness.dark;

return Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
decoration: BoxDecoration(
color: isOverdue
? cs.errorContainer.withValues(alpha: isDark ? 0.3 : 0.15)
: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.3),
borderRadius: BorderRadius.circular(10),
border: Border.all(
color: isOverdue
? cs.error.withValues(alpha: isDark ? 0.4 : 0.3)
: cs.outline.withValues(alpha: isDark ? 0.2 : 0.1),
),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
isOverdue ? Icons.warning_amber_rounded : Icons.event_rounded,
size: 16,
color: isOverdue ? cs.error : cs.primary,
),
const SizedBox(width: 6),
Text(
MaterialLocalizations.of(context).formatMediumDate(dueDate),
style: context.textStyles.labelMedium?.copyWith(
color: isOverdue ? cs.error : cs.onSurface,
fontWeight: FontWeight.w600,
),
),
if (isOverdue) ...[
const SizedBox(width: 8),
Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(
color: cs.error,
borderRadius: BorderRadius.circular(6),
),
child: Text(
'OVERDUE',
style: context.textStyles.labelSmall?.copyWith(
color: cs.onError,
fontWeight: FontWeight.w700,
letterSpacing: 0.3,
),
),
),
],
],
),
);
}
}

class _IconPillButton extends StatelessWidget {
final String tooltip;
final IconData icon;
final VoidCallback? onPressed;
final bool busy;
const _IconPillButton({required this.tooltip, required this.icon, required this.onPressed, this.busy = false});

@override
Widget build(BuildContext context) {
final cs = Theme.of(context).colorScheme;
return Tooltip(
message: tooltip,
child: InkWell(
onTap: onPressed,
borderRadius: BorderRadius.circular(999),
child: Container(
width: 44,
height: 44,
decoration: BoxDecoration(
color: cs.surfaceVariant.withValues(alpha: 0.25),
borderRadius: BorderRadius.circular(999),
border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
),
child: Center(child: busy ? const SizedBox(width: 16, height: 16, child: InlineLoadingDot()) : Icon(icon, color: cs.primary)),
),
),
);
}
}

class _CompactAction extends StatelessWidget {
final VoidCallback? onPressed;
final IconData icon;
final String label;
final bool busy;
final bool isDestructive;

const _CompactAction({required this.onPressed, required this.icon, required this.label, this.busy = false, this.isDestructive = false});

@override
Widget build(BuildContext context) {
final cs = Theme.of(context).colorScheme;
final color = isDestructive ? cs.error : cs.primary;
return OutlinedButton.icon(
onPressed: onPressed,
style: OutlinedButton.styleFrom(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
minimumSize: const Size(0, 40),
side: BorderSide(color: (isDestructive ? cs.error : cs.outlineVariant).withValues(alpha: 0.5)),
),
icon: busy ? const SizedBox(width: 16, height: 16, child: InlineLoadingDot()) : Icon(icon, color: color),
label: Text(label, style: context.textStyles.labelLarge?.withColor(color)),
);
}
}

class _EmptyState extends StatelessWidget {
final VoidCallback onGenerate;
final VoidCallback onAdd;
final PlanTimeline? current;
final List<PlanTimeline> timelines;
final bool busy;
final VoidCallback onSwitch;
final VoidCallback onSave;

const _EmptyState({
required this.onGenerate,
required this.onAdd,
required this.current,
required this.timelines,
required this.busy,
required this.onSwitch,
required this.onSave,
});

@override
Widget build(BuildContext context) {
final cs = Theme.of(context).colorScheme;
return SingleChildScrollView(
child: Padding(
padding: AppSpacing.paddingLg,
child: Column(
children: [
// Show timeline selector only if there are manually saved timelines (exclude auto-created "Current plan")
if (timelines.where((t) => t.name != 'Current plan').isNotEmpty)
Padding(
padding: EdgeInsets.only(bottom: AppSpacing.lg),
child: _TimelineSelector(
current: current,
timelines: timelines.where((t) => t.name != 'Current plan').toList(),
busy: busy,
onSwitch: onSwitch,
onSave: onSave,
),
),
SizedBox(height: AppSpacing.xl),
Icon(Icons.timeline, size: 56, color: cs.onSurfaceVariant),
SizedBox(height: AppSpacing.md),
Text('No milestones yet', style: context.textStyles.titleLarge?.semiBold),
SizedBox(height: AppSpacing.xs),
Text(
timelines.where((t) => t.name != 'Current plan').isNotEmpty
? 'Switch to a saved timeline or create a new plan.'
: 'Describe your goal and generate a quick plan, or add steps manually.',
textAlign: TextAlign.center,
style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
),
SizedBox(height: AppSpacing.lg),
FilledButton.icon(
onPressed: onGenerate,
icon: Icon(Icons.auto_awesome, color: cs.onPrimary),
label: const Text('Generate plan'),
),
SizedBox(height: AppSpacing.sm),
OutlinedButton.icon(
onPressed: onAdd,
icon: Icon(Icons.add_task, color: cs.primary),
label: const Text('Add milestone'),
)
],
mainAxisAlignment: MainAxisAlignment.center,
),
),
);
}
}

class _TimelineSelector extends StatelessWidget {
final PlanTimeline? current;
final List<PlanTimeline> timelines;
final VoidCallback onSwitch;
final VoidCallback onSave;
final bool busy;

const _TimelineSelector({required this.current, required this.timelines, required this.onSwitch, required this.onSave, this.busy = false});

@override
Widget build(BuildContext context) {
final cs = Theme.of(context).colorScheme;
final isDark = Theme.of(context).brightness == Brightness.dark;
final now = DateTime.now();
final subtitle = current == null
? 'Save this plan as a template or snapshot.'
: '${current!.milestones.length} steps · Updated ${MaterialLocalizations.of(context).formatShortDate(current!.updatedAt)}';
final savedCount = timelines.length;

return LayoutBuilder(builder: (context, constraints) {
final isNarrow = constraints.maxWidth < 420;
final actions = _TimelineActions(busy: busy, onSwitch: onSwitch, onSave: onSave);

return Container(
decoration: BoxDecoration(
gradient: LinearGradient(
colors: isDark
? [
cs.primaryContainer.withValues(alpha: 0.12),
cs.primaryContainer.withValues(alpha: 0.06),
]
: [
cs.primaryContainer.withValues(alpha: 0.3),
cs.primaryContainer.withValues(alpha: 0.15),
],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: cs.primary.withValues(alpha: isDark ? 0.3 : 0.25),
width: 1.5,
),
boxShadow: [
BoxShadow(
color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.08),
blurRadius: 12,
offset: const Offset(0, 4),
),
],
),
child: Padding(
padding: const EdgeInsets.all(18),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
width: 48,
height: 48,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(14),
color: cs.primary,
boxShadow: [
BoxShadow(
color: cs.primary.withValues(alpha: 0.3),
blurRadius: 8,
offset: const Offset(0, 2),
),
],
),
child: Icon(Icons.layers_rounded, color: cs.onPrimary, size: 24),
),
SizedBox(width: AppSpacing.md),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'From Adaptly',
style: context.textStyles.labelMedium?.copyWith(
color: cs.primary,
fontWeight: FontWeight.w700,
letterSpacing: 0.5,
),
),
const SizedBox(height: 2),
Text(
current?.name ?? 'Current timeline',
style: context.textStyles.titleMedium?.copyWith(
fontWeight: FontWeight.w700,
),
overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 4),
Text(subtitle, style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
const SizedBox(height: 6),
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
decoration: BoxDecoration(
color: cs.primaryContainer.withValues(alpha: isDark ? 0.4 : 0.5),
borderRadius: BorderRadius.circular(8),
border: Border.all(
color: cs.primary.withValues(alpha: 0.3),
),
),
child: Text(
' $savedCount saved timeline${savedCount == 1 ? '' : 's'}',
style: context.textStyles.labelSmall?.copyWith(
color: cs.primary,
fontWeight: FontWeight.w600,
),
),
),
],
),
),
if (!isNarrow) actions
],
),
if (isNarrow)
Padding(
padding: EdgeInsets.only(top: AppSpacing.md),
child: actions,
),
],
),
),
);
});
}
}

class _TimelineActions extends StatelessWidget {
final bool busy;
final VoidCallback onSwitch;
final VoidCallback onSave;

const _TimelineActions({required this.busy, required this.onSwitch, required this.onSave});

@override
Widget build(BuildContext context) {
final cs = Theme.of(context).colorScheme;
return Wrap(
spacing: 8,
runSpacing: 8,
alignment: WrapAlignment.end,
children: [
OutlinedButton.icon(
onPressed: busy ? null : onSwitch,
icon: Icon(Icons.swap_horiz, color: cs.primary),
label: const Text('Switch'),
),
FilledButton.icon(onPressed: busy ? null : onSave, icon: Icon(Icons.save_alt, color: cs.onPrimary), label: const Text('Save')),
],
);
}
}
