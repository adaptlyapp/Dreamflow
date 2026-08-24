import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:wellspring/supabase/supabase_config.dart';

/// Centralized AI usage policy for consent, de-identification, and throttling.
class AiSafetyPolicy {
  // Whether outbound AI calls are allowed for this user/session.
  static bool enabled = true;
  // If true, we will de-identify user-provided text before sending to OpenAI.
  static bool deidentify = true;
  // Basic client-side throttle to reduce accidental bursts (best-effort only).
  static int maxRequestsPerMinute = 24;

  // Simple token bucket timestamp list
  static final List<DateTime> _callTimestamps = [];

  static void configure({bool? enabled_, bool? deidentify_, int? maxPerMinute}) {
    if (enabled_ != null) enabled = enabled_;
    if (deidentify_ != null) deidentify = deidentify_;
    if (maxPerMinute != null && maxPerMinute > 0) maxRequestsPerMinute = maxPerMinute;
  }

  static bool allowAnotherCallNow() {
    final now = DateTime.now();
    _callTimestamps.removeWhere((t) => now.difference(t).inMinutes >= 1);
    return _callTimestamps.length < maxRequestsPerMinute;
  }

  static void recordCall() {
    _callTimestamps.add(DateTime.now());
  }

  /// Waits up to [maxWait] for a rate-limit slot to become available.
  /// Returns immediately if calls are disabled or a slot is open now.
  static Future<void> waitForSlot({Duration maxWait = const Duration(seconds: 8)}) async {
    if (!enabled) return;
    if (allowAnotherCallNow()) return;
    final start = DateTime.now();
    while (!allowAnotherCallNow()) {
      // Sleep in short bursts to quickly free up the UI thread
      await Future.delayed(const Duration(milliseconds: 250));
      if (DateTime.now().difference(start) >= maxWait) break;
    }
  }
}

extension OpenAIClientMilestoneReroll on OpenAIClient {
  /// Generate an alternate version of a single milestone step.
  /// Returns a map with keys: { title: string, description: string }.
  Future<Map<String, String>> rerollMilestone({
    required String currentTitle,
    String? currentDescription,
    String? conditionName,
    String? previousTitle,
    String? nextTitle,
  }) async {
    if (!AiSafetyPolicy.enabled) throw Exception('AI suggestions are disabled in Settings');
    if (!AiSafetyPolicy.allowAnotherCallNow()) {
      await AiSafetyPolicy.waitForSlot();
      if (!AiSafetyPolicy.allowAnotherCallNow()) {
        throw Exception('Too many AI requests — please wait a moment and try again');
      }
    }

    String prompt() {
      final safeTitle = AiSafetyPolicy.deidentify ? PHIRedactor.redact(currentTitle) : currentTitle;
      final safeDesc = (currentDescription == null || currentDescription.trim().isEmpty)
          ? ''
          : (AiSafetyPolicy.deidentify ? PHIRedactor.redact(currentDescription.trim()) : currentDescription.trim());
      final safeCond = (conditionName == null || conditionName.trim().isEmpty)
          ? ''
          : (AiSafetyPolicy.deidentify ? PHIRedactor.redact(conditionName.trim()) : conditionName.trim());
      final prev = (previousTitle == null || previousTitle.trim().isEmpty)
          ? ''
          : (AiSafetyPolicy.deidentify ? PHIRedactor.redact(previousTitle.trim()) : previousTitle.trim());
      final next = (nextTitle == null || nextTitle.trim().isEmpty)
          ? ''
          : (AiSafetyPolicy.deidentify ? PHIRedactor.redact(nextTitle.trim()) : nextTitle.trim());
      final condBlock = safeCond.isEmpty
          ? ''
          : '\nContext: This plan is for someone managing "$safeCond". Keep language supportive and non-clinical.';
      final neighbors = [
        if (prev.isNotEmpty) '- Previous step: "$prev"',
        if (next.isNotEmpty) '- Next step: "$next"',
      ].join('\n');
      final neighborBlock = neighbors.isEmpty ? '' : '\nNearby steps for coherence:\n$neighbors\n';
      final descBlock = safeDesc.isEmpty ? '' : '\nCurrent step details to improve upon: "$safeDesc"\n';
      return '''
You are an assistant that outputs ONLY a valid JSON object.

Task: Propose ONE alternate version of this plan step title "$safeTitle" that stays coherent with surrounding steps. Keep the same timing and difficulty; just produce a clearer, more motivating alternative.
$descBlock
$neighborBlock
$condBlock

Constraints:
- Avoid generic wellness platitudes (e.g., "eat healthy", "manage stress") unless they appear verbatim in the current details.
- Keep the title concise and the description 1–2 sentences, non-clinical.
- Do NOT include dates or ordering; timing stays the same as the original.
- No URLs.

Return JSON with EXACTLY this shape:
{
  "title": "",
  "description": ""
}
''';
    }

    Map<String, dynamic> body() => {
          'model': 'gpt-4o-mini',
          'temperature': 0.5,
          'response_format': {'type': 'json_object'},
          'messages': [
            {
              'role': 'system',
              'content': 'You are an assistant that outputs ONLY valid JSON objects matching the requested schema. No extra text. Output must be a single JSON object.'
            },
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt()},
              ]
            }
          ]
        };

    int attempt = 0;
    while (true) {
      try {
        final data = await OpenAIClient._invokeOpenAiProxy(body(), timeout: const Duration(seconds: 20));
        AiSafetyPolicy.recordCall();
        final content = data['choices']?[0]?['message']?['content'];
        String? jsonText;
        if (content is String) {
          jsonText = content;
        } else if (content is List) {
          try {
            final buf = StringBuffer();
            for (final part in content) {
              final type = part['type'];
              if (type == 'output_text' || type == 'text') {
                final t = part['text'];
                if (t is String) buf.write(t);
              }
            }
            jsonText = buf.isEmpty ? null : buf.toString();
          } catch (e) {
            debugPrint('OpenAI content parts parse error (reroll): $e');
          }
        }
        if (jsonText != null && jsonText.trim().isNotEmpty) {
          try {
            final parsed = Map<String, dynamic>.from(jsonDecode(jsonText) as Map);
            final title = (parsed['title'] ?? '').toString().trim();
            final desc = (parsed['description'] ?? '').toString().trim();
            if (title.isEmpty && desc.isEmpty) throw Exception('Empty reroll');
            return {
              'title': title.isEmpty ? currentTitle : title,
              'description': desc.isEmpty ? (currentDescription ?? '') : desc,
            };
          } catch (e) {
            debugPrint('OpenAI JSON parse error (reroll): $e');
            throw Exception('Malformed JSON from AI');
          }
        }
        throw Exception('Unexpected response shape');
      } catch (e) {
        attempt += 1;
        if (attempt >= 2) rethrow;
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }
}

/// Very lightweight PHI/PII redaction. Best-effort client-side only.
/// This does not replace a proper DLP service but reduces accidental leakage.
class PHIRedactor {
  static final _email = RegExp(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}");
  static final _phone = RegExp(r"(?:(?:\\+?1[-.\\s]?)?(?:\\(\\d{3}\\)|\\d{3})[-.\\s]?\\d{3}[-.\\s]?\\d{4})");
  static final _ssn = RegExp(r"\\b\\d{3}-\\d{2}-\\d{4}\\b");
  static final _creditCard = RegExp(r"\\b(?:\\d[ -]*?){13,19}\\b");
  static final _street = RegExp(r"\\b\\d{1,5}\\s+[A-Za-z0-9'\\.-]+\\s+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Way)\\b", caseSensitive: false);

  static String redact(String input, {String? userName}) {
    String s = input;
    try {
      s = s.replaceAll(_email, '[EMAIL]');
      s = s.replaceAll(_phone, '[PHONE]');
      s = s.replaceAll(_ssn, '[SSN]');
      s = s.replaceAll(_creditCard, '[CARD]');
      s = s.replaceAll(_street, '[ADDRESS]');
      if (userName != null && userName.trim().isNotEmpty) {
        // Replace case-insensitively occurrences of user name tokens
        final tokens = userName.split(' ').where((t) => t.trim().length >= 2).toList();
        for (final t in tokens) {
          final re = RegExp(RegExp.escape(t), caseSensitive: false);
          s = s.replaceAll(re, '[NAME]');
        }
      }
    } catch (e) {
      debugPrint('PHIRedactor error: $e');
    }
    return s;
  }
}

class OpenAIClient {
  OpenAIClient();

  static const String _functionName = 'openai_chat_proxy';

  static Future<Map<String, dynamic>> _invokeOpenAiProxy(
    Map<String, dynamic> openAiBody, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final session = SupabaseConfig.client.auth.currentSession;
    // We still require sign-in for AI features (product decision), even though the
    // Edge Function itself is configured with verify_jwt=false.
    if (session == null) throw Exception('Sign in required to use AI features');

    try {
      // This log line is intentional: it lets us prove in Dreamflow logs that we
      // actually invoked the Supabase Edge Function (vs. using offline fallback).
      debugPrint('[OpenAIClient] Invoking Supabase Edge Function "$_functionName" (user=${session.user.id}, hasSession=${session.accessToken.isNotEmpty})');
      // Use a direct HTTP call to avoid ambiguity around which headers
      // supabase_flutter attaches for `verify_jwt` true/false functions.
      //
       // Supabase Edge Functions require:
       // - `apikey: <anon key>` always
       // - `Authorization: Bearer <access token>` when verify_jwt=true
       //
       // Even if the function is configured with verify_jwt=false, sending the
       // user's access token is still valid and avoids ambiguity across
       // deployments/config drift.
      //
      // IMPORTANT: `GoRouter` does not persist `state.extra` across auth refresh events.
      // If we attempt to refresh tokens on 401, the router refresh can drop Learn-more
      // args. So we configure this proxy as verify_jwt=false and authenticate with anon.
       final uri = Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/$_functionName');
      final res = await http
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              'apikey': SupabaseConfig.anonKey,
               // Works for both verify_jwt=true and verify_jwt=false.
               'Authorization': 'Bearer ${session.accessToken}',
            },
            body: jsonEncode(openAiBody),
          )
          .timeout(timeout);

      debugPrint('[OpenAIClient] HTTP function call status=${res.statusCode} bytes=${res.bodyBytes.length}');
      final text = utf8.decode(res.bodyBytes);
       if (res.statusCode == 401) {
         // Non-sensitive, but very useful: Supabase often returns a short reason.
         debugPrint('[OpenAIClient] 401 body: $text');
       }
      Map<String, dynamic> payload;
      try {
        payload = Map<String, dynamic>.from(jsonDecode(text) as Map);
      } catch (e) {
        debugPrint('[OpenAIClient] Failed to parse function JSON: $e');
        throw Exception('AI proxy returned non-JSON (status=${res.statusCode})');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final msg = (payload['error']?['message'] ?? payload['message'] ?? 'AI request failed').toString();
        throw Exception(msg);
      }
      return payload;
    } catch (e) {
      debugPrint('Supabase function $_functionName invoke error: $e');
      rethrow;
    }
  }

  // Lightweight in-memory caches to speed up repeat opens in a session.
  // We purposely keep these in-memory only (no PHI/Pii and short TTL).
  static final _eduCache = _TimedMemoryCache<Map<String, dynamic>>(ttl: const Duration(hours: 2), maxEntries: 128);
  static final _productCache = _TimedMemoryCache<List<Map<String, dynamic>>>(ttl: const Duration(hours: 2), maxEntries: 128);

  String _eduKey({
    required String title,
    String? desc,
    String? cond,
    String? conditionDetailsSummary,
  }) {
    // Keep keys short-ish; we only need to bust cache when details meaningfully change.
    final details = (conditionDetailsSummary ?? '').trim().toLowerCase();
    final detailsTag = details.isEmpty ? '' : '|cd=${details.hashCode}';
    return 'edu|t=${title.trim().toLowerCase()}|d=${(desc ?? '').trim().toLowerCase()}|c=${(cond ?? '').trim().toLowerCase()}$detailsTag';
  }

  String _productKey({required String title, String? desc, String? cond}) =>
      'prod|t=${title.trim().toLowerCase()}|d=${(desc ?? '').trim().toLowerCase()}|c=${(cond ?? '').trim().toLowerCase()}';

  /// Backwards-compatible wrapper: returns only the milestone list.
  /// Prefer [generatePlanBreakdown] to also get the AI's goal summary,
  /// complexity level and category-of-help reasoning.
  Future<List<Map<String, dynamic>>> generateMilestones({
    required String description,
    int milestones = 5,
    int durationWeeks = 8,
    int? durationDays,
    String? conditionName,
    String? conditionDetailsSummary,
    List<Map<String, dynamic>>? nearbyResources,
    List<Map<String, dynamic>>? relatedCommunities,
    List<Map<String, String>>? userSuggestions,
  }) async {
    final breakdown = await generatePlanBreakdown(
      description: description,
      milestones: milestones,
      durationWeeks: durationWeeks,
      durationDays: durationDays,
      conditionName: conditionName,
      conditionDetailsSummary: conditionDetailsSummary,
      nearbyResources: nearbyResources,
      relatedCommunities: relatedCommunities,
      userSuggestions: userSuggestions,
    );
    return List<Map<String, dynamic>>.from(breakdown['milestones'] as List? ?? const []);
  }

  /// Goal Breakdown Engine: asks the AI to first reason about what kinds of
  /// help are needed to accomplish the user's goal, then translate that
  /// reasoning into concrete milestones tagged with helpType.
  ///
  /// Returns a map with:
  /// - "goalSummary" (String): a one-sentence restatement of the goal
  /// - "complexityLevel" (String): one of "low" | "medium" | "high"
  /// - "needCategories" (List<Map>): [{ "type": <helpType>, "reason": "..." }, ...]
  /// - "milestones" (List<Map>): concrete milestones (same shape as before,
  ///   each with title, description, dueInDays, dueTime, helpType).
  Future<Map<String, dynamic>> generatePlanBreakdown({
    required String description,
    int milestones = 5,
    int durationWeeks = 8,
    int? durationDays,
    String? conditionName,
    String? conditionDetailsSummary,
    List<Map<String, dynamic>>? nearbyResources,
    List<Map<String, dynamic>>? relatedCommunities,
    List<Map<String, String>>? userSuggestions,
  }) async {
    debugPrint('🎯🎯🎯 [OpenAI] generateMilestones called! description="$description", milestones=$milestones, condition="$conditionName"');
    if (!AiSafetyPolicy.enabled) {
      debugPrint('❌ [OpenAI] AI safety policy is DISABLED');
      throw Exception('AI suggestions are disabled in Settings');
    }
    if (!AiSafetyPolicy.allowAnotherCallNow()) {
      await AiSafetyPolicy.waitForSlot();
      if (!AiSafetyPolicy.allowAnotherCallNow()) {
        throw Exception('Too many AI requests — please wait a moment and try again');
      }
    }

    final totalDays = (durationDays ?? (durationWeeks * 7)).clamp(7, 730);
    final totalWeeks = (durationWeeks <= 0) ? (totalDays / 7).ceil().clamp(1, 104) : durationWeeks;

    Map<String, dynamic> _makeBody({required bool strict}) => {
          'model': 'gpt-4o',
          // Keep creativity low to avoid fluffy generic advice
          'temperature': 0.2,
          'response_format': {'type': 'json_object'},
          'messages': [
            {
              'role': 'system',
              'content': 'You are an assistant that outputs ONLY valid JSON objects matching the requested schema. No extra text. Output must be a single JSON object.'
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': _prompt(
                    AiSafetyPolicy.deidentify ? PHIRedactor.redact(description) : description,
                    milestones,
                    durationWeeks: totalWeeks,
                    durationDays: totalDays,
                    conditionName: AiSafetyPolicy.deidentify ? PHIRedactor.redact((conditionName ?? '')) : conditionName,
                    conditionDetailsSummary: AiSafetyPolicy.deidentify 
                        ? PHIRedactor.redact((conditionDetailsSummary ?? '')) 
                        : conditionDetailsSummary,
                    strict: strict,
                    nearbyResources: nearbyResources,
                    relatedCommunities: relatedCommunities,
                    userSuggestions: userSuggestions
                        ?.map((e) => {
                              'name': (e['name'] ?? '').toString(),
                              'note': AiSafetyPolicy.deidentify ? PHIRedactor.redact((e['note'] ?? '').toString()) : (e['note'] ?? '').toString(),
                              'type': (e['type'] ?? '').toString(),
                            })
                        .toList(),
                  ),
                }
              ]
            }
          ]
        };

    bool strictTried = false;
    int attempt = 0;
    while (true) {
      try {
        debugPrint('📡 [OpenAI] Calling Supabase Edge Function (attempt ${attempt + 1}, strict=$strictTried)...');
        final data = await OpenAIClient._invokeOpenAiProxy(_makeBody(strict: strictTried), timeout: const Duration(seconds: 35));
        debugPrint('📡 [OpenAI] Edge Function returned successfully!');
        AiSafetyPolicy.recordCall();
        final content = data['choices']?[0]?['message']?['content'];
        debugPrint('📡 [OpenAI] Parsing response content (type: ${content.runtimeType})...');
          // Content can be a String (chat.completions) or a List of parts (Responses API/proxy).
          String? jsonText;
          if (content is String) {
            jsonText = content;
          } else if (content is List) {
            try {
              // Concatenate any text-like items
              final buf = StringBuffer();
              for (final part in content) {
                final type = part['type'];
                if (type == 'output_text' || type == 'text') {
                  final t = part['text'];
                  if (t is String) buf.write(t);
                }
              }
              jsonText = buf.isEmpty ? null : buf.toString();
            } catch (e) {
              debugPrint('OpenAI content parts parse error: $e');
            }
          }
          if (jsonText != null && jsonText.trim().isNotEmpty) {
            try {
              final parsed = jsonDecode(jsonText);
              final raw = (parsed['milestones'] as List?) ?? const [];
              debugPrint('🔍🔍🔍 [OpenAI] RAW AI RESPONSE: ${raw.length} milestones received');
              // Sanitize to Map<String, dynamic>
               final list = raw
                  .where((e) => e != null)
                  .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
                  .map((m) {
                        final rawHelpType = (m['helpType'] ?? m['help_type'] ?? m['type'] ?? '').toString();
                        final normalized = _normalizeHelpType(rawHelpType);
                        debugPrint('🎯 [OpenAI] "${(m['title'] ?? '').toString()}" → RAW: "$rawHelpType" → NORMALIZED: "$normalized"');
                        final result = {
                          'title': (m['title'] ?? '').toString(),
                          'description': (m['description'] ?? '').toString(),
                          'dueInDays': m['dueInDays'],
                           // Optional: only required when multiple milestones share a day.
                           'dueTime': (m['dueTime'] ?? '').toString(),
                           // Goal Breakdown Engine: type of help this step represents.
                           // One of: expert | product | community | learning | action | tracking | environment
                           'helpType': normalized,
                        };
                        debugPrint('✅ [OpenAI] Final map has helpType: "${result['helpType']}"');
                        return result;
                      })
                  .toList();
              debugPrint('📦 [OpenAI] After mapping, list has ${list.length} items');

               // Normalize schedule so it always fits the selected duration and can support
               // multiple milestones per day with suggested times.
               final normalized = _normalizeSchedule(list, totalDays: totalDays);

               // Extract goal breakdown reasoning fields.
               final goalSummary = (parsed['goalSummary'] ?? '').toString().trim();
               final complexityLevel = _normalizeComplexity((parsed['complexityLevel'] ?? '').toString());
               final rawCategories = (parsed['needCategories'] as List?) ?? const [];
               final needCategories = rawCategories
                   .whereType<Map>()
                   .map<Map<String, String>>((m) => {
                         'type': _normalizeHelpType((m['type'] ?? '').toString()),
                         'reason': (m['reason'] ?? '').toString().trim(),
                       })
                   .where((m) => (m['type'] ?? '').isNotEmpty)
                   .toList();
               debugPrint('🧠 [OpenAI] goalSummary="$goalSummary" complexity=$complexityLevel categories=${needCategories.map((c) => c['type']).toList()}');

               Map<String, dynamic> buildBreakdown(List<Map<String, dynamic>> ms) => {
                     'goalSummary': goalSummary,
                     'complexityLevel': complexityLevel,
                     'needCategories': needCategories,
                     'milestones': ms,
                   };

              // Validate tailoring: avoid generic advice; ensure goal text appears in each description
               if (_needsRefinement(
                 normalized,
                 description,
                 conditionName: conditionName,
                 conditionDetailsSummary: conditionDetailsSummary,
               )) {
                 if (!strictTried) {
                   debugPrint('OpenAI result too generic; retrying with strict constraints');
                   strictTried = true;
                   // fall through to retry loop by continuing
                 } else {
                   debugPrint('OpenAI result still generic after strict prompt; accepting but flagged');
                   return buildBreakdown(normalized);
                 }
               } else {
                 return buildBreakdown(normalized);
               }
            } catch (e) {
              debugPrint('OpenAI JSON parse error: $e');
              throw Exception('Malformed JSON from AI');
            }
          }
          throw Exception('Unexpected response shape');
      } catch (e) {
        attempt += 1;
        // If we requested a strict retry, allow one extra attempt for the strict pass
        final maxAttempts = strictTried ? 3 : 2;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  String _prompt(
    String description,
    int milestones,
    {
    required int durationWeeks,
    required int durationDays,
    String? conditionName,
    String? conditionDetailsSummary,
    bool strict = false,
    List<Map<String, dynamic>>? nearbyResources,
    List<Map<String, dynamic>>? relatedCommunities,
    List<Map<String, String>>? userSuggestions,
  }) {
    final hasCondition = (conditionName != null && conditionName.trim().isNotEmpty);
    final hasConditionDetails = (conditionDetailsSummary != null && conditionDetailsSummary.trim().isNotEmpty);
    final ctx = hasCondition
        ? '- Context: The plan is for someone managing "$conditionName"; keep language supportive and accessible.'
        : '';
    final conditionCtx = hasConditionDetails
        ? '\n\nUser-specific condition information (CRITICAL - tailor all milestones to this):\n$conditionDetailsSummary\n'
        : '';

    final conditionAnchors = hasConditionDetails ? _extractConditionAnchors(conditionDetailsSummary) : const <String>[];
    final anchorsBlock = conditionAnchors.isNotEmpty
        ? 'When writing milestone descriptions, consider weaving in these meaningful condition details naturally when relevant:\n- ${conditionAnchors.take(10).join('\n- ')}\n'
        : '';

    final strictness = strict
        ? '''
Strict mode (do not violate):
- FORBIDDEN unless explicitly present in the user's goal text: "balanced diet", "eat healthy", "stay hydrated", "drink more water", "exercise regularly", "work out more", "manage stress", "reduce stress", "self‑care", "healthy lifestyle", "consult a professional".
- Use concrete, domain-specific actions that obviously operationalize "$description". No generic wellness tips.
- Keep milestones clearly relevant to the user's goal and condition. Make the connection to their goal and context obvious in each step.
'''
        : '';

    // Compose local context snippets succinctly to fit token budget
    String resourcesBlock = '';
    if (nearbyResources != null && nearbyResources.isNotEmpty) {
      final items = nearbyResources.take(6).map((r) {
        final name = (r['name'] ?? '').toString();
        final type = (r['type'] ?? '').toString();
        final dist = (r['distanceMi'] ?? r['distance'] ?? '').toString();
        final availability = (r['availability'] ?? '').toString();
        final address = (r['address'] ?? '').toString();
        return '- $name (${type.isNotEmpty ? type : 'service'}) · ${dist.isNotEmpty ? '$dist mi' : 'nearby'}${availability.isNotEmpty ? ' · $availability' : ''}${address.isNotEmpty ? ' · $address' : ''}';
      }).join('\n');
      resourcesBlock = '\nLocal resources near the user (use when it makes sense):\n$items\n';
    }
    String communitiesBlock = '';
    if (relatedCommunities != null && relatedCommunities.isNotEmpty) {
      final items = relatedCommunities.take(6).map((c) {
        final name = (c['name'] ?? '').toString();
        final members = (c['memberCount'] ?? '').toString();
        return '- $name${members.isNotEmpty ? ' · ~$members members' : ''}';
      }).join('\n');
      communitiesBlock = '\nRelevant communities (prefer as social support):\n$items\n';
    }
    String userNotesBlock = '';
    if (userSuggestions != null && userSuggestions.isNotEmpty) {
      final items = userSuggestions.take(6).map((s) {
        final name = (s['name'] ?? '').toString();
        final note = (s['note'] ?? '').toString();
        final type = (s['type'] ?? '').toString();
        return '- ${name.isNotEmpty ? name : 'User suggestion'}${type.isNotEmpty ? ' (${type})' : ''}: ${note}';
      }).join('\n');
      userNotesBlock = '\nUser-suggested leads (consider when relevant; use if they clearly help):\n$items\n';
    }

    final resourceExampleName = nearbyResources != null && nearbyResources.isNotEmpty
        ? (nearbyResources.first['name'] ?? '').toString().trim()
        : '';
    final anchorExample = resourceExampleName.isNotEmpty
        ? 'Call $resourceExampleName to schedule an evaluation for "$description" by day 7'
        : 'Call one of the listed local resources to schedule an evaluation for "$description" by day 7';

    return '''
You are the "Goal Breakdown Engine" for Adaptly. Do NOT just list actions.
First, silently reason about what kinds of help the user needs to reach the goal, then output the plan as JSON only.

Reasoning framework (do this internally, do NOT output it):
1) UNDERSTAND the goal: what is the user actually trying to accomplish, and what does success look like?
2) IDENTIFY the categories of help needed to achieve it. Use these canonical categories:
   - "expert"       → a professional, doctor, therapist, coach, specialist, tutor
   - "product"      → a physical item, tool, device, supply, or piece of equipment
   - "community"    → peer support, a group, a mentor, or someone who has done this before
   - "learning"     → knowledge, research, understanding a concept, reading, watching
   - "action"       → a concrete practice, habit, or repeatable behavior the user does
   - "tracking"     → measuring / logging progress to know if it's working
   - "environment"  → adjusting their physical space, schedule, or setup so the goal becomes easier
3) DECIDE which categories are actually needed for THIS goal (not every goal needs all of them). A good plan usually mixes 3–6 categories.
4) TRANSLATE each needed category into 1+ concrete milestones. Every milestone is tagged with its helpType.

Output constraints:
- Total duration: $durationDays days (about $durationWeeks weeks).
- Number of milestones: EXACTLY $milestones.
- Each milestone MUST include:
    - "title" (short, action-oriented)
    - "description" (1–2 sentences, concrete, non-clinical)
    - "dueInDays" (int, from plan start; NON-DECREASING; within $durationDays)
    - "helpType" (one of: expert | product | community | learning | action | tracking | environment)
- If multiple milestones share a dueInDays, include "dueTime" (e.g. "09:00" or "2:00 PM").
- Prefer variety of helpTypes across the plan; do NOT make every step "action".
- Ordering guidance: usually put "learning" and "expert" earlier, "action"/"tracking" during the plan, and "community"/"environment" wherever they naturally fit.
- Start very gentle in week 1, then progress gradually.
- Keep advice non-clinical; do not give medical or diagnostic guidance.
$ctx
$conditionCtx
  ${anchorsBlock.isEmpty ? '' : anchorsBlock}
Tailoring requirements (critical):
- Keep milestones clearly aligned to "$description". Each step should obviously contribute to achieving this goal.
- When the goal mentions specific activities, tools, locations, quantities, times, or constraints, weave those naturally into relevant milestones.
- Keep titles concise and action-oriented.
- Prefer verbs and specifics (who/what/when/where) over generalities.
${hasCondition ? ' - Reference "$conditionName" naturally throughout the plan when it meaningfully guides the action.\n - Let "$conditionName" lead the plan sequencing and constraints (e.g., gentler ramp-up, rest days, or pacing if appropriate for accessibility).\n - Avoid clinical or diagnostic instructions; keep it educational and practical.' : ''}
  ${hasConditionDetails ? ' - Incorporate the user\'s condition details (injury level/type, mobility status, function, devices, abilities, challenges) when they guide how a step should be done. Treat them as hard constraints for accessibility, pacing, equipment, and environment — not optional context.' : ''}
$strictness

Use of local help (important):
- When applicable, anchor steps to the local resources and communities listed below. If you reference one, include its NAME in the description (for example: $anchorExample).
- If hours/availability are provided, schedule earlier milestones on days/times that align (e.g., weekdays).
- Only include a local item if it obviously helps accomplish "$description"; otherwise use at-home or self-guided steps.
 $resourcesBlock$communitiesBlock$userNotesBlock

IMPORTANT: Return a JSON object with EXACTLY this shape (all keys required):
{
  "goalSummary": "one short sentence restating what the user is trying to accomplish",
  "complexityLevel": "low | medium | high",
  "needCategories": [
    {"type": "expert|product|community|learning|action|tracking|environment",
     "reason": "1 short sentence explaining why this kind of help is needed for THIS goal"}
  ],
  "milestones": [
    {"title": "", "description": "", "dueInDays": 7, "dueTime": "09:00", "helpType": "learning"}
  ]
}

Rules for the reasoning fields:
- "needCategories" must ONLY include categories that are actually needed for this goal (usually 3–6). Do NOT list every possible category.
- Each helpType used in "milestones" MUST also appear in "needCategories".
- Keep "goalSummary" ≤ 20 words and non-clinical.
 

Primary goal (from user):
"""
$description
"""
''';
  }

  /// Normalize a free-form complexity string to low|medium|high.
  static String _normalizeComplexity(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return '';
    if (s.contains('low') || s.contains('simple') || s.contains('easy')) return 'low';
    if (s.contains('high') || s.contains('complex') || s.contains('hard') || s.contains('difficult')) return 'high';
    if (s.contains('med') || s.contains('moderate')) return 'medium';
    return '';
  }

  /// Normalize a free-form help type string to one of the canonical values.
  /// Canonical values: expert | product | community | learning | action | tracking | environment
  /// Returns empty string if it can't confidently be mapped.
  static String _normalizeHelpType(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return '';
    const canonical = {
      'expert', 'product', 'community', 'learning', 'action', 'tracking', 'environment',
    };
    if (canonical.contains(s)) return s;
    // Common synonyms
    if (s.contains('expert') || s.contains('professional') || s.contains('doctor') || s.contains('therapist') || s.contains('clinician') || s.contains('specialist')) return 'expert';
    if (s.contains('product') || s.contains('tool') || s.contains('equipment') || s.contains('device') || s.contains('gear') || s.contains('supply')) return 'product';
    if (s.contains('community') || s.contains('support') || s.contains('peer') || s.contains('group') || s.contains('social')) return 'community';
    if (s.contains('learn') || s.contains('education') || s.contains('research') || s.contains('read') || s.contains('study')) return 'learning';
    if (s.contains('track') || s.contains('log') || s.contains('measure') || s.contains('monitor') || s.contains('journal')) return 'tracking';
    if (s.contains('environment') || s.contains('setup') || s.contains('space') || s.contains('home')) return 'environment';
    if (s.contains('action') || s.contains('practice') || s.contains('habit') || s.contains('routine') || s.contains('do')) return 'action';
    return '';
  }

  List<Map<String, dynamic>> _normalizeSchedule(List<Map<String, dynamic>> input, {required int totalDays}) {
    if (input.isEmpty) return input;

    // Parse dueInDays best-effort.
    final parsed = <Map<String, dynamic>>[];
    for (int i = 0; i < input.length; i++) {
      final m = input[i];
      final raw = m['dueInDays'];
      int? day;
      if (raw is int) {
        day = raw;
      } else {
        day = int.tryParse(raw?.toString() ?? '');
      }
      parsed.add({
        'title': (m['title'] ?? '').toString(),
        'description': (m['description'] ?? '').toString(),
        'dueInDays': day,
        'dueTime': (m['dueTime'] ?? '').toString(),
        'helpType': (m['helpType'] ?? '').toString(),
      });
    }

    // If the model didn't give usable dueInDays, distribute deterministically.
    final total = totalDays.clamp(1, 730);
    final haveAllDays = parsed.every((m) => (m['dueInDays'] is int));
    if (!haveAllDays) {
      final distributed = _distributeDays(total: total, count: parsed.length);
      for (int i = 0; i < parsed.length; i++) {
        parsed[i]['dueInDays'] = distributed[i];
      }
    }

    // Clamp and enforce non-decreasing.
    int prev = 1;
    for (int i = 0; i < parsed.length; i++) {
      final d = (parsed[i]['dueInDays'] as int).clamp(1, total);
      final next = d < prev ? prev : d;
      parsed[i]['dueInDays'] = next;
      prev = next;
    }

    // Assign times if multiple milestones share the same day.
    final dayToIdxs = <int, List<int>>{};
    for (int i = 0; i < parsed.length; i++) {
      final d = parsed[i]['dueInDays'] as int;
      (dayToIdxs[d] ??= []).add(i);
    }

    for (final entry in dayToIdxs.entries) {
      final idxs = entry.value;
      if (idxs.length <= 1) continue;
      final times = _suggestTimes(idxs.length);
      for (int j = 0; j < idxs.length; j++) {
        final idx = idxs[j];
        final existing = (parsed[idx]['dueTime'] ?? '').toString().trim();
        if (existing.isEmpty) parsed[idx]['dueTime'] = times[j];
      }
    }

    return parsed;
  }

  List<int> _distributeDays({required int total, required int count}) {
    // Returns a non-decreasing list in [1, total] with good coverage.
    // Works for count > total by producing duplicates.
    if (count <= 0) return const [];
    if (total <= 1) return List<int>.filled(count, 1);
    if (count == 1) return [total];
    return List<int>.generate(count, (i) {
      final v = ((i) * total / (count - 1)).round();
      // v in [0,total]; shift to [1,total]
      return (v + 1).clamp(1, total);
    });
  }

  List<String> _suggestTimes(int count) {
    // Simple human-friendly times. Expand if needed.
    const base = <String>['09:00', '12:30', '15:30', '18:30', '20:30'];
    if (count <= base.length) return base.take(count).toList();
    final out = <String>[...base];
    // After 5, fill hourly slots from 08:00 upwards.
    int hour = 8;
    while (out.length < count) {
      final h = (hour % 24).toString().padLeft(2, '0');
      out.add('$h:00');
      hour += 1;
    }
    return out;
  }

  List<String> _extractConditionAnchors(String summary) {
    // Example format from ConditionDetail.toAiSummary:
    // "User's X details: Type: Type 1; Level: C4-C5; Mobility: Power wheelchair; Uses: ...; Challenges: ...; Requires daily assistance."
    final s = summary.trim();
    if (s.isEmpty) return const <String>[];

    final lower = s.toLowerCase();
    final start = lower.indexOf('details:');
    final body = start >= 0 ? s.substring(start + 'details:'.length) : s;

    final pieces = body
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final anchors = <String>{};
    for (final p in pieces) {
      final idx = p.indexOf(':');
      if (idx >= 0 && idx < p.length - 1) {
        final value = p.substring(idx + 1).trim();
        if (value.isNotEmpty) anchors.add(value);
      }
      if (p.length <= 60) anchors.add(p);
    }

    final list = anchors.toList();
    // Prefer shorter, more "droppable" anchors first.
    list.sort((a, b) => a.length.compareTo(b.length));
    return list.take(12).toList();
  }

  bool _needsRefinement(
    List<Map<String, dynamic>> list,
    String goal, {
    String? conditionName,
    String? conditionDetailsSummary,
  }) {
    try {
      if (list.isEmpty) return false;
      final g = goal.trim().toLowerCase();
      final cond = (conditionName ?? '').trim().toLowerCase();
      final anchors = (conditionDetailsSummary != null && conditionDetailsSummary.trim().isNotEmpty)
          ? _extractConditionAnchors(conditionDetailsSummary)
          : const <String>[];
      final banned = <String>{
        'balanced diet',
        'eat healthy',
        'stay hydrated',
        'drink more water',
        'exercise regularly',
        'work out more',
        'manage stress',
        'reduce stress',
        'self-care',
        'self‑care',
        'healthy lifestyle',
        'consult a professional',
        'consult your doctor',
      };
      bool containsGeneric = false;
      bool allReferenceGoal = true;
      bool allReferenceCondition = cond.isEmpty; // if no condition, treat as satisfied
      bool allReferenceConditionDetails = anchors.isEmpty;
      for (final m in list) {
        final text = ((m['title'] ?? '').toString() + ' ' + (m['description'] ?? '').toString()).toLowerCase();
        for (final b in banned) {
          if (text.contains(b) && !g.contains(b)) {
            containsGeneric = true;
            break;
          }
        }
        if (!text.contains(g) && g.length >= 8) {
          allReferenceGoal = false;
        }
        if (cond.isNotEmpty && !text.contains(cond)) {
          allReferenceCondition = false;
        }

        if (anchors.isNotEmpty) {
          final mentionsAnchor = anchors.any((a) {
            final needle = a.toLowerCase().trim();
            if (needle.isEmpty) return false;
            // Avoid requiring super-short tokens which can create false positives/negatives.
            if (needle.length < 3) return false;
            return text.contains(needle);
          });
          if (!mentionsAnchor) allReferenceConditionDetails = false;
        }
      }
      // refine if any generic terms found or not all steps reference the goal text
      return containsGeneric || !allReferenceGoal || !allReferenceCondition || !allReferenceConditionDetails;
    } catch (_) {
      return false;
    }
  }

  /// Generate rich educational content for a given milestone/step.
  /// Returns a structured JSON-like map with multiple helpful sections.
  Future<Map<String, dynamic>> generateMilestoneEducation({
    required String stepTitle,
    String? stepDescription,
    String? conditionName,
    String? conditionDetailsSummary,
    List<Map<String, dynamic>>? nearbyResources,
  }) async {
    // Cache-first fast path
    final baseCacheKey = _eduKey(
      title: stepTitle,
      desc: stepDescription,
      cond: conditionName,
      conditionDetailsSummary: conditionDetailsSummary,
    );
    final resourceCacheKey = () {
      if (nearbyResources == null || nearbyResources.isEmpty) return 'none';
      try {
        return nearbyResources
            .take(4)
            .map((r) => (r['name'] ?? '').toString().trim().toLowerCase())
            .where((name) => name.isNotEmpty)
            .join('|');
      } catch (_) {
        return 'some';
      }
    }();
    final cacheKey = '$baseCacheKey|res=$resourceCacheKey';
    final cached = OpenAIClient._eduCache.get(cacheKey);
    if (cached != null) {
      debugPrint('OpenAIClient: edu cache hit for "$stepTitle"');
      return cached;
    }
    if (!AiSafetyPolicy.enabled) {
      throw Exception('AI suggestions are disabled in Settings');
    }
    if (!AiSafetyPolicy.allowAnotherCallNow()) {
      await AiSafetyPolicy.waitForSlot();
      if (!AiSafetyPolicy.allowAnotherCallNow()) {
        throw Exception('Too many AI requests — please wait a moment and try again');
      }
    }

    String _educationPrompt({required bool strict}) {
      final safeCond = AiSafetyPolicy.deidentify ? PHIRedactor.redact((conditionName ?? '')) : (conditionName ?? '');
      final safeDetails = AiSafetyPolicy.deidentify
          ? PHIRedactor.redact((conditionDetailsSummary ?? ''))
          : (conditionDetailsSummary ?? '');
      final ctx = (safeCond.trim().isNotEmpty)
          ? 'Context: This plan is for someone managing "$safeCond". Use supportive, accessible language. Do NOT provide medical advice.'
          : 'Use supportive, accessible language. Do NOT provide medical advice.';
      final hasDetails = safeDetails.trim().isNotEmpty;
      final anchors = hasDetails ? _extractConditionAnchors(safeDetails) : const <String>[];
      final detailsBlock = hasDetails
          ? '\nUser\'s condition details (CRITICAL — treat as constraints):\n$safeDetails\n'
          : '';
      final anchorsBlock = anchors.isNotEmpty
          ? 'Use these exact condition-detail anchor phrases frequently (include at least ONE in EVERY section you write):\n- ${anchors.take(10).join('\n- ')}\n'
          : '';
      final rawDesc = (stepDescription == null || stepDescription.trim().isEmpty)
          ? 'No extra description provided.'
          : 'Extra context from plan: "${(AiSafetyPolicy.deidentify ? PHIRedactor.redact(stepDescription.trim()) : stepDescription.trim())}".';
      final strictness = strict
          ? 'Strict mode: keep content concrete and actionable; avoid generic wellness platitudes. No placeholders. '
              'No URLs; instead, give searchQueries the exact keywords someone should use. '
              '${anchors.isNotEmpty ? 'Every top-level section must include at least ONE anchor phrase verbatim (summary, whyItMatters, keyConcepts, stepByStep, examples, pitfalls, trackingIdeas, motivationTips, searchQueries). ' : ''}'
          : '';
      String resourcesBlock = '';
      if (nearbyResources != null && nearbyResources.isNotEmpty) {
        try {
          final resources = nearbyResources;
          final entries = resources
              .take(6)
              .map((item) {
                final name = (item['name'] ?? '').toString();
                final type = (item['type'] ?? '').toString();
                final distance = (item['distanceMi'] ?? item['distance'] ?? '').toString();
                final availability = (item['availability'] ?? '').toString();
                final address = (item['address'] ?? '').toString();
                final pieces = <String>[];
                if (type.isNotEmpty) pieces.add(type);
                if (distance.isNotEmpty) pieces.add('${distance} mi');
                if (availability.isNotEmpty) pieces.add(availability);
                if (address.isNotEmpty) pieces.add(address);
                final summary = pieces.isEmpty ? '' : ' · ${pieces.join(' · ')}';
                return '- $name$summary';
              })
              .join('\n');
          if (entries.isNotEmpty) {
            resourcesBlock = '\nLocal support options near the user (prefer when they naturally help):\n$entries\n';
          }
        } catch (e) {
          debugPrint('OpenAI education prompt resource formatting failed: $e');
        }
      }
      return '''
You are an assistant that outputs ONLY valid JSON objects.

$ctx
$strictness
${detailsBlock.isEmpty ? '' : detailsBlock}
${anchorsBlock.isEmpty ? '' : anchorsBlock}
${resourcesBlock.isEmpty ? '' : resourcesBlock}

Task: Create thorough educational content for the plan step titled "$stepTitle".
 $rawDesc

Return a JSON object with EXACTLY these keys:
{
  "summary": "one short paragraph",
  "whyItMatters": "1-2 sentences",
  "keyConcepts": ["3-6 concise bullets"],
  "stepByStep": [
    {"title": "", "detail": ""},
    {"title": "", "detail": ""}
  ],
  "examples": ["at least 2 practical examples"],
  "pitfalls": ["common mistakes to avoid"],
  "trackingIdeas": ["how to track or measure progress for this step"],
  "motivationTips": ["gentle encouragement"],
  "searchQueries": ["3-6 keyword phrases to research this step further"],
  "disclaimer": "Short friendly disclaimer that this is educational, not medical advice"
}

Constraints:
- Keep tone supportive, specific, and non-clinical.
- Avoid giving medical or diagnostic instructions.
- Do NOT include URLs. Provide searchQueries instead.
- When referencing a local resource, include its name exactly as provided above.
- Personalization requirement (critical): If condition details are provided, you MUST make the content obviously tailored to them (mobility, function, assistive devices, abilities, challenges, injury level/sub-type). Treat them as hard constraints.
- Use UTF-8, no markdown code fences.
''';
    }

    Map<String, dynamic> _makeBody({required bool strict}) => {
          'model': 'gpt-4o',
          'temperature': 0.2,
          'response_format': {'type': 'json_object'},
          'messages': [
            {
              'role': 'system',
              'content': 'You are an assistant that outputs ONLY valid JSON objects matching the requested schema. No extra text. Output must be a single JSON object.'
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': _educationPrompt(strict: strict),
                }
              ]
            }
          ]
        };

    bool strictTried = false;
    int attempt = 0;
    while (true) {
      try {
        final data = await OpenAIClient._invokeOpenAiProxy(_makeBody(strict: strictTried), timeout: const Duration(seconds: 30));
        AiSafetyPolicy.recordCall();
        final content = data['choices']?[0]?['message']?['content'];
          String? jsonText;
          if (content is String) {
            jsonText = content;
          } else if (content is List) {
            try {
              final buf = StringBuffer();
              for (final part in content) {
                final type = part['type'];
                if (type == 'output_text' || type == 'text') {
                  final t = part['text'];
                  if (t is String) buf.write(t);
                }
              }
              jsonText = buf.isEmpty ? null : buf.toString();
            } catch (e) {
              debugPrint('OpenAI content parts parse error: $e');
            }
          }
          if (jsonText != null && jsonText.trim().isNotEmpty) {
            try {
              final parsed = Map<String, dynamic>.from(jsonDecode(jsonText) as Map);
              // Ensure all expected keys exist
              final sanitized = <String, dynamic>{
                'summary': (parsed['summary'] ?? '').toString(),
                'whyItMatters': (parsed['whyItMatters'] ?? '').toString(),
                'keyConcepts': List<String>.from(((parsed['keyConcepts'] as List?) ?? const []).map((e) => e.toString())),
                'stepByStep': List<Map<String, dynamic>>.from(((parsed['stepByStep'] as List?) ?? const []).map((e) => {
                  'title': (e['title'] ?? '').toString(),
                  'detail': (e['detail'] ?? '').toString(),
                })),
                'examples': List<String>.from(((parsed['examples'] as List?) ?? const []).map((e) => e.toString())),
                'pitfalls': List<String>.from(((parsed['pitfalls'] as List?) ?? const []).map((e) => e.toString())),
                'trackingIdeas': List<String>.from(((parsed['trackingIdeas'] as List?) ?? const []).map((e) => e.toString())),
                'motivationTips': List<String>.from(((parsed['motivationTips'] as List?) ?? const []).map((e) => e.toString())),
                'searchQueries': List<String>.from(((parsed['searchQueries'] as List?) ?? const []).map((e) => e.toString())),
                'disclaimer': (parsed['disclaimer'] ?? '').toString(),
              };
              // Basic validation: ensure some content; otherwise retry strict once
              final hasContent = sanitized['summary'].toString().trim().isNotEmpty && (sanitized['stepByStep'] as List).isNotEmpty;
              if (!hasContent && !strictTried) {
                debugPrint('Education content sparse; retrying with strict constraints');
                strictTried = true;
              } else {
                // Store in memory cache for fast repeat loads
                 OpenAIClient._eduCache.set(cacheKey, sanitized);
                return sanitized;
              }
            } catch (e) {
              debugPrint('OpenAI JSON parse error (education): $e');
              throw Exception('Malformed JSON from AI');
            }
          }
          throw Exception('Unexpected response shape');
      } catch (e) {
        attempt += 1;
        final maxAttempts = strictTried ? 3 : 2;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  /// Analyze recent health snapshot metrics and return structured insights.
  ///
  /// Provide the latest 7-day snapshot metrics, previous 7-day metrics,
  /// and short time series for key trackers. The model returns a JSON object
  /// with a concise summary, highlights, risks, suggested actions, per-metric
  /// trends, and a friendly disclaimer. This is educational only.
  Future<Map<String, dynamic>> getHealthInsights({
    required Map<String, dynamic> snapshot, // {avgPain, avgSleep, avgEnergy, avgSteps, avgHeartRate, avgSys, avgDia}
    required Map<String, dynamic> previous, // same keys as snapshot (when available)
    required Map<String, List<double>> series, // {'pain': [...], 'sleep': [...], 'energy': [...], 'steps': [...], 'heartRate': [...]} last-up-to-7
  }) async {
    if (!AiSafetyPolicy.enabled) {
      throw Exception('AI suggestions are disabled in Settings');
    }
    if (!AiSafetyPolicy.allowAnotherCallNow()) {
      await AiSafetyPolicy.waitForSlot();
      if (!AiSafetyPolicy.allowAnotherCallNow()) {
        throw Exception('Too many AI requests — please wait a moment and try again');
      }
    }

    String _insightsPrompt() {
      // Keep the prompt compact and structured to minimize token usage.
      final safeSnapshot = jsonEncode(snapshot);
      final safePrevious = jsonEncode(previous);
      final safeSeries = jsonEncode(series);
      return '''
You are an assistant that outputs ONLY a valid JSON object.

Task: Interpret a user's recent health tracking in plain, encouraging language. Focus on patterns and practical, non-clinical guidance.

Input data (JSON):
- current7d: $safeSnapshot
- previous7d: $safePrevious
- seriesLast7: $safeSeries

Important interpretations:
- Pain and Heart Rate: lower is generally better.
- Sleep, Energy, and Steps: higher is generally better.
- Blood pressure (avgSys/avgDia) is informational; do NOT provide medical advice.

Return a JSON object with EXACTLY these keys and types:
{
  "summary": "string, 2-3 sentences maximum",
  "highlights": ["bullet point strings focusing on positive or improving areas"],
  "risks": ["bullet point strings about declines or watch-outs (keep gentle, non-clinical)"],
  "suggestedActions": ["3-6 specific, simple actions grounded in the tracked metrics"],
  "trendByMetric": {"pain": "up|down|flat",
                     "sleep": "up|down|flat",
                     "energy": "up|down|flat",
                     "steps": "up|down|flat",
                     "heartRate": "up|down|flat"},
  "disclaimer": "short friendly reminder that this is educational, not medical advice"
}

Constraints:
- Use supportive, accessible tone. No medical or diagnostic advice.
- Do not mention that you were given JSON; just use it implicitly.
- Keep the output concise.
''';
    }

    Map<String, dynamic> _makeBody() => {
          'model': 'gpt-4o',
          'temperature': 0.2,
          'response_format': {'type': 'json_object'},
          'messages': [
            {
              'role': 'system',
              'content': 'You are an assistant that outputs ONLY valid JSON objects matching the requested schema. No extra text. Output must be a single JSON object.'
            },
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': _insightsPrompt()},
              ]
            }
          ]
        };

    int attempt = 0;
    while (true) {
      try {
        final data = await OpenAIClient._invokeOpenAiProxy(_makeBody(), timeout: const Duration(seconds: 45));
        AiSafetyPolicy.recordCall();
        final content = data['choices']?[0]?['message']?['content'];
          String? jsonText;
          if (content is String) {
            jsonText = content;
          } else if (content is List) {
            try {
              final buf = StringBuffer();
              for (final part in content) {
                final type = part['type'];
                if (type == 'output_text' || type == 'text') {
                  final t = part['text'];
                  if (t is String) buf.write(t);
                }
              }
              jsonText = buf.isEmpty ? null : buf.toString();
            } catch (e) {
              debugPrint('OpenAI content parts parse error (insights): $e');
            }
          }
          if (jsonText != null && jsonText.trim().isNotEmpty) {
            try {
              final parsed = Map<String, dynamic>.from(jsonDecode(jsonText) as Map);
              // Sanitize expected keys and types
              Map<String, dynamic> trend = {};
              try {
                trend = Map<String, dynamic>.from(parsed['trendByMetric'] as Map? ?? {});
              } catch (_) {}
              final result = <String, dynamic>{
                'summary': (parsed['summary'] ?? '').toString(),
                'highlights': List<String>.from(((parsed['highlights'] as List?) ?? const []).map((e) => e.toString())),
                'risks': List<String>.from(((parsed['risks'] as List?) ?? const []).map((e) => e.toString())),
                'suggestedActions': List<String>.from(((parsed['suggestedActions'] as List?) ?? const []).map((e) => e.toString())),
                'trendByMetric': <String, String>{
                  'pain': (trend['pain'] ?? '').toString(),
                  'sleep': (trend['sleep'] ?? '').toString(),
                  'energy': (trend['energy'] ?? '').toString(),
                  'steps': (trend['steps'] ?? '').toString(),
                  'heartRate': (trend['heartRate'] ?? '').toString(),
                },
                'disclaimer': (parsed['disclaimer'] ?? '').toString(),
              };
              // Minimal validation
              if (result['summary'].toString().trim().isEmpty) {
                throw Exception('Empty summary');
              }
              return result;
            } catch (e) {
              debugPrint('OpenAI JSON parse error (insights): $e');
              throw Exception('Malformed JSON from AI');
            }
          }
          throw Exception('Unexpected response shape');
      } catch (e) {
        attempt += 1;
        if (attempt >= 2) rethrow;
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }
}

extension OpenAIClientGoalTips on OpenAIClient {
  /// Generate concise, actionable tips for a goal based on its title, description,
  /// and linked tracker method. Returns a JSON-like map with keys:
  /// { oneLiner: string, tips: string[], exampleLogs: string[], disclaimer: string }
  Future<Map<String, dynamic>> generateGoalTips({
    required String title,
    String? description,
    String? trackerKey,
  }) async {
    if (!AiSafetyPolicy.enabled) {
      throw Exception('AI suggestions are disabled in Settings');
    }
    if (!AiSafetyPolicy.allowAnotherCallNow()) {
      throw Exception('Too many AI requests — please wait a moment and try again');
    }

    String trackerHint(String? key) {
      final k = (key ?? '').trim().toLowerCase();
      switch (k) {
        case 'sleep':
          return 'The user tracks sleep quality on a 0–10 scale. Use concrete, short sleep-hygiene actions that can be logged daily.';
        case 'pain':
          return 'The user tracks pain on a 0–10 scale. Suggest gentle, non-clinical tactics and pacing ideas; avoid medical advice.';
        case 'energy':
          return 'The user tracks energy on a 0–10 scale. Suggest pacing, small wins, and restorative breaks.';
        case 'steps':
          return 'The user tracks steps via a counter. Suggest incremental, location-based walks and realistic ramp-ups.';
        case 'bowel':
          return 'The user tracks bowel routine adherence. Suggest routine-building and preparation steps. Avoid medical claims.';
        case 'bladder':
          return 'The user tracks bladder routine adherence. Suggest prep, timing, and reminders. Avoid medical claims.';
        default:
          return 'Use simple, concrete tips that the user can log once per action. Avoid medical or diagnostic guidance.';
      }
    }

    String prompt() {
      final desc = (description == null || description.trim().isEmpty)
          ? 'No extra description provided.'
          : 'Extra context: "${(AiSafetyPolicy.deidentify ? PHIRedactor.redact(description.trim()) : description.trim())}"';
      final tracker = trackerHint(trackerKey);
      return '''
You are an assistant that outputs ONLY a valid JSON object.

Task: Create concise, highly actionable tips to help someone progress on this goal:
 - Title: "${AiSafetyPolicy.deidentify ? PHIRedactor.redact(title) : title}"
- $desc

Tracker method context: $tracker

Return a JSON object with EXACTLY these keys:
{
  "oneLiner": "Single sentence that reframes the goal into a small next step",
  "tips": [
    "5-8 short, concrete, non-clinical tips that directly advance '$title'",
    "Each tip should be small enough to complete in ≤15 minutes",
    "Avoid generic phrases like 'eat healthy' or 'reduce stress' unless present in user's text"
  ],
  "exampleLogs": [
    "3-5 examples of how a user would log this action with the given tracker method"
  ],
  "disclaimer": "Short friendly reminder that this is educational, not medical advice"
}

Constraints:
- Keep tips specific to "$title"; where relevant, echo exact wording.
- Keep tone supportive and practical. No medical or diagnostic guidance.
- Do NOT include URLs.
''';
    }

    Map<String, dynamic> body() => {
          'model': 'gpt-4o-mini',
          'temperature': 0.2,
          'response_format': {'type': 'json_object'},
          'messages': [
            {
              'role': 'system',
              'content': 'You are an assistant that outputs ONLY valid JSON objects matching the requested schema. No extra text. Output must be a single JSON object.'
            },
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt()},
              ]
            }
          ]
        };

    int attempt = 0;
    while (true) {
      try {
        final data = await OpenAIClient._invokeOpenAiProxy(body(), timeout: const Duration(seconds: 20));
        AiSafetyPolicy.recordCall();
        final content = data['choices']?[0]?['message']?['content'];
          String? jsonText;
          if (content is String) {
            jsonText = content;
          } else if (content is List) {
            try {
              final buf = StringBuffer();
              for (final part in content) {
                final type = part['type'];
                if (type == 'output_text' || type == 'text') {
                  final t = part['text'];
                  if (t is String) buf.write(t);
                }
              }
              jsonText = buf.isEmpty ? null : buf.toString();
            } catch (e) {
              debugPrint('OpenAI content parts parse error (goal tips): $e');
            }
          }
          if (jsonText != null && jsonText.trim().isNotEmpty) {
            try {
              final parsed = Map<String, dynamic>.from(jsonDecode(jsonText) as Map);
              final result = <String, dynamic>{
                'oneLiner': (parsed['oneLiner'] ?? '').toString(),
                'tips': List<String>.from(((parsed['tips'] as List?) ?? const []).map((e) => e.toString())),
                'exampleLogs': List<String>.from(((parsed['exampleLogs'] as List?) ?? const []).map((e) => e.toString())),
                'disclaimer': (parsed['disclaimer'] ?? '').toString(),
              };
              if (result['oneLiner'].toString().trim().isEmpty && (result['tips'] as List).isEmpty) {
                throw Exception('Empty tips');
              }
              return result;
            } catch (e) {
              debugPrint('OpenAI JSON parse error (goal tips): $e');
              throw Exception('Malformed JSON from AI');
            }
          }
          throw Exception('Unexpected response shape');
      } catch (e) {
        attempt += 1;
        if (attempt >= 2) rethrow;
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }
}

extension OpenAIClientProductIdeas on OpenAIClient {
  /// Suggest non-medical, consumer products or tools that can help accomplish a goal/milestone.
  /// Returns a list of items with fields: { name, category, whyHelpful, queries[] }.
  /// The queries are meant to be used to construct search URLs (e.g., Amazon search).
  Future<List<Map<String, dynamic>>> generateProductIdeas({
    required String goalOrStepTitle,
    String? goalOrStepDescription,
    String? conditionName,
  }) async {
    // Cache-first fast path
    final cacheKey = _productKey(title: goalOrStepTitle, desc: goalOrStepDescription, cond: conditionName);
    final cached = OpenAIClient._productCache.get(cacheKey);
    if (cached != null) {
      debugPrint('OpenAIClient: product cache hit for "$goalOrStepTitle"');
      return cached;
    }
    if (!AiSafetyPolicy.enabled) throw Exception('AI suggestions are disabled in Settings');
    if (!AiSafetyPolicy.allowAnotherCallNow()) {
      await AiSafetyPolicy.waitForSlot();
      if (!AiSafetyPolicy.allowAnotherCallNow()) {
        throw Exception('Too many AI requests — please wait a moment and try again');
      }
    }

    String prompt() {
      final safeTitle = AiSafetyPolicy.deidentify ? PHIRedactor.redact(goalOrStepTitle) : goalOrStepTitle;
      final safeDesc = (goalOrStepDescription == null || goalOrStepDescription.trim().isEmpty)
          ? ''
          : (AiSafetyPolicy.deidentify ? PHIRedactor.redact(goalOrStepDescription.trim()) : goalOrStepDescription.trim());
      final safeCond = (conditionName == null || conditionName.trim().isEmpty)
          ? ''
          : (AiSafetyPolicy.deidentify ? PHIRedactor.redact(conditionName.trim()) : conditionName.trim());
      final condBlock = safeCond.isEmpty
          ? ''
          : '\nContext: The user is managing "$safeCond". Prefer accessible products; avoid clinical devices or medical claims.';
      return '''
You are an assistant that outputs ONLY a valid JSON object.

Task: Suggest up to 6 consumer products or tools that could help someone accomplish this goal/milestone: "$safeTitle".
${safeDesc.isEmpty ? '' : 'Extra context: "$safeDesc".'}
$condBlock

Constraints:
- Avoid medical advice and clinical or prescription-only devices.
- Prefer simple, widely available consumer items (e.g., organizers, timers, pillows, resistance bands, ice packs, white noise machines, light therapy lamps) when relevant.
- For each item, provide: name, category, whyHelpful (1 sentence), and 2-4 search queries (strings) a person would use to find this item online.
- Do NOT include URLs or brand endorsements; generic item names only.
- The output must be a JSON object with an array "items".

Return JSON with EXACTLY this shape:
{
  "items": [
    {"name": "", "category": "", "whyHelpful": "", "queries": ["", ""]}
  ]
}
''';
    }

    Map<String, dynamic> body() => {
          'model': 'gpt-4o',
          'temperature': 0.2,
          'response_format': {'type': 'json_object'},
          'messages': [
            {
              'role': 'system',
              'content': 'You are an assistant that outputs ONLY valid JSON objects matching the requested schema. No extra text. Output must be a single JSON object.'
            },
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt()},
              ]
            }
          ]
        };

    int attempt = 0;
    while (true) {
      try {
        final data = await OpenAIClient._invokeOpenAiProxy(body(), timeout: const Duration(seconds: 30));
        AiSafetyPolicy.recordCall();
        final content = data['choices']?[0]?['message']?['content'];
          String? jsonText;
          if (content is String) {
            jsonText = content;
          } else if (content is List) {
            try {
              final buf = StringBuffer();
              for (final part in content) {
                final type = part['type'];
                if (type == 'output_text' || type == 'text') {
                  final t = part['text'];
                  if (t is String) buf.write(t);
                }
              }
              jsonText = buf.isEmpty ? null : buf.toString();
            } catch (e) {
              debugPrint('OpenAI content parts parse error (product ideas): $e');
            }
          }
          if (jsonText != null && jsonText.trim().isNotEmpty) {
            try {
              final parsed = Map<String, dynamic>.from(jsonDecode(jsonText) as Map);
              final raw = (parsed['items'] as List?) ?? const [];
              final items = raw
                  .where((e) => e != null)
                  .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
                  .map((m) => {
                        'name': (m['name'] ?? '').toString(),
                        'category': (m['category'] ?? '').toString(),
                        'whyHelpful': (m['whyHelpful'] ?? '').toString(),
                        'queries': List<String>.from(((m['queries'] as List?) ?? const []).map((e) => e.toString())),
                      })
                  .where((m) => (m['name'] as String).trim().isNotEmpty)
                  .take(6)
                  .toList();
              OpenAIClient._productCache.set(cacheKey, items);
              return items;
            } catch (e) {
              debugPrint('OpenAI JSON parse error (product ideas): $e');
              throw Exception('Malformed JSON from AI');
            }
          }
          throw Exception('Unexpected response shape');
      } catch (e) {
        attempt += 1;
        if (attempt >= 2) rethrow;
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }
}

// Simple timed memory cache with LRU eviction for this session
class _TimedMemoryCache<T> {
  final Duration ttl;
  final int maxEntries;
  final Map<String, _TimedEntry<T>> _store = {};
  final List<String> _lru = [];

  _TimedMemoryCache({required this.ttl, required this.maxEntries});

  T? get(String key) {
    final e = _store[key];
    if (e == null) return null;
    if (DateTime.now().isAfter(e.expiresAt)) {
      _store.remove(key);
      _lru.remove(key);
      return null;
    }
    _lru.remove(key);
    _lru.add(key);
    return e.value;
  }

  void set(String key, T value) {
    _store[key] = _TimedEntry(value: value, expiresAt: DateTime.now().add(ttl));
    _lru.remove(key);
    _lru.add(key);
    _prune();
  }

  void _prune() {
    final now = DateTime.now();
    final expired = _store.entries.where((e) => now.isAfter(e.value.expiresAt)).map((e) => e.key).toList();
    for (final k in expired) {
      _store.remove(k);
      _lru.remove(k);
    }
    while (_lru.length > maxEntries) {
      final oldest = _lru.first;
      _lru.removeAt(0);
      _store.remove(oldest);
    }
  }
}

class _TimedEntry<T> {
  final T value;
  final DateTime expiresAt;
  _TimedEntry({required this.value, required this.expiresAt});
}

extension OpenAIClientCareQuestion on OpenAIClient {
  /// Generate personalized care advice based on user's question and condition information.
  /// Returns a map with keys: { answer: string, resources: List<{title, url}> }
  Future<Map<String, dynamic>> generateCareAnswer({
    required String question,
    List<String> patientConditions = const [],
    String? conditionDetailsSummary,
  }) async {
    if (!AiSafetyPolicy.enabled) {
      throw Exception('AI suggestions are disabled in Settings');
    }
    if (!AiSafetyPolicy.allowAnotherCallNow()) {
      await AiSafetyPolicy.waitForSlot();
      if (!AiSafetyPolicy.allowAnotherCallNow()) {
        throw Exception('Too many AI requests — please wait a moment and try again');
      }
    }

    String _prompt() {
      final safeQuestion = AiSafetyPolicy.deidentify 
          ? PHIRedactor.redact(question) 
          : question;
      final safeConditions = patientConditions
          .map((c) => AiSafetyPolicy.deidentify ? PHIRedactor.redact(c) : c)
          .toList();
      final safeDetails = AiSafetyPolicy.deidentify
          ? PHIRedactor.redact(conditionDetailsSummary ?? '')
          : (conditionDetailsSummary ?? '');

      final conditionContext = safeConditions.isNotEmpty
          ? 'Patient conditions: ${safeConditions.join(", ")}'
          : 'No specific conditions listed';

      final detailsBlock = safeDetails.trim().isNotEmpty
          ? '\nCondition details:\n$safeDetails'
          : '';

      return '''
You are a supportive post-discharge care assistant. Your role is to provide practical, empathetic guidance for recovery care. You must NOT provide medical diagnosis, prescribe treatment, or substitute for professional medical advice.

User question: "$safeQuestion"

Context:
- $conditionContext$detailsBlock

Task: Provide a warm, practical answer that:
1. Directly addresses the user's question
2. Incorporates their specific condition(s) when relevant
3. Offers concrete, actionable steps they can take
4. Includes when to contact their care team
5. Is supportive in tone, not clinical
6. Does NOT give medical advice or diagnosis

Return JSON with EXACTLY this structure (output as a JSON object only):
{
  "answer": "Your comprehensive, personalized answer (2-4 sentences, warm and practical)",
  "steps": ["3-5 concrete actionable steps specific to their situation"],
  "whenToContact": "Simple guidance on when to call their care team",
  "encouragement": "A brief, genuine message of encouragement"
}

Important:
- Personalize every response to their specific condition(s)
- Avoid generic wellness platitudes
- Keep language accessible and non-clinical
- Focus on practical home care and daily living
- Always prioritize safety and recommend professional contact when uncertain
''';
    }

    Map<String, dynamic> _makeBody() => {
      'model': 'gpt-4o',
      'temperature': 0.6,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': 'You are a compassionate post-discharge care assistant. Output ONLY valid JSON matching the requested schema. No extra text.'
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': _prompt(),
            }
          ]
        }
      ]
    };

    int attempt = 0;
    while (true) {
      try {
        final data = await OpenAIClient._invokeOpenAiProxy(_makeBody(), timeout: const Duration(seconds: 20));
        AiSafetyPolicy.recordCall();
        final content = data['choices']?[0]?['message']?['content'];
        String? jsonText;
        if (content is String) {
          jsonText = content;
        } else if (content is List) {
          try {
            final buf = StringBuffer();
            for (final part in content) {
              final type = part['type'];
              if (type == 'output_text' || type == 'text') {
                final t = part['text'];
                if (t is String) buf.write(t);
              }
            }
            jsonText = buf.isEmpty ? null : buf.toString();
          } catch (e) {
            debugPrint('OpenAI content parts parse error (care answer): $e');
          }
        }

        if (jsonText != null && jsonText.trim().isNotEmpty) {
          try {
            final parsed = Map<String, dynamic>.from(jsonDecode(jsonText) as Map);
            final result = <String, dynamic>{
              'answer': (parsed['answer'] ?? '').toString(),
              'steps': List<String>.from(((parsed['steps'] as List?) ?? const []).map((e) => e.toString())),
              'whenToContact': (parsed['whenToContact'] ?? '').toString(),
              'encouragement': (parsed['encouragement'] ?? '').toString(),
            };
            if (result['answer'].toString().trim().isEmpty) {
              throw Exception('Empty answer');
            }
            return result;
          } catch (e) {
            debugPrint('OpenAI JSON parse error (care answer): $e');
            throw Exception('Malformed JSON from AI');
          }
        }
        throw Exception('Unexpected response shape');
      } catch (e) {
        attempt += 1;
        if (attempt >= 2) rethrow;
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }
}

extension OpenAIClientDietPlan on OpenAIClient {
   /// Generates a safe, general 7-day meal plan.
   ///
   /// IMPORTANT: The assistant must not diagnose/treat/cure. It should always
   /// include the medical safety disclaimer.
   Future<Map<String, dynamic>> generateDietPlan({required Map<String, dynamic> input}) async {
    if (!AiSafetyPolicy.enabled) throw Exception('AI suggestions are disabled in Settings');
    if (!AiSafetyPolicy.allowAnotherCallNow()) {
      await AiSafetyPolicy.waitForSlot();
      if (!AiSafetyPolicy.allowAnotherCallNow()) {
        throw Exception('Too many AI requests — please wait a moment and try again');
      }
    }

    String safeText(String s) => AiSafetyPolicy.deidentify ? PHIRedactor.redact(s) : s;

    final primaryGoal = safeText((input['primaryGoal'] ?? '').toString());
    final diagnosis = safeText((input['diagnosisOrNeed'] ?? '').toString());
    final allergies = (input['allergies'] is List)
        ? (input['allergies'] as List).map((e) => safeText(e.toString())).toList()
        : const <String>[];
    final restrictions = (input['restrictions'] is List)
        ? (input['restrictions'] as List).map((e) => safeText(e.toString())).toList()
        : const <String>[];
    final budget = safeText((input['budget'] ?? '').toString());
    final cookingAbility = safeText((input['cookingAbility'] ?? '').toString());
    final preferredFoods = (input['preferredFoods'] is List)
        ? (input['preferredFoods'] as List).map((e) => safeText(e.toString())).toList()
        : const <String>[];
    final foodsToAvoid = (input['foodsToAvoid'] is List)
        ? (input['foodsToAvoid'] as List).map((e) => safeText(e.toString())).toList()
        : const <String>[];
    final mealsPerDay = (input['mealsPerDay'] as num?)?.toInt() ?? 3;
    final currentConditions = (input['currentConditions'] is List)
        ? (input['currentConditions'] as List).map((e) => safeText(e.toString())).where((s) => s.trim().isNotEmpty).toList()
        : const <String>[];

    String prompt() {
      final targets = <String>[];
      void addTarget(String key, String label) {
        final v = input[key];
        if (v == null) return;
        final n = (v as num?)?.toInt();
        if (n == null || n <= 0) return;
        targets.add('$label: $n');
      }

      addTarget('targetCalories', 'Calories/day');
      addTarget('targetProteinG', 'Protein g/day');
      addTarget('targetCarbsG', 'Carbs g/day');
      addTarget('targetFatsG', 'Fats g/day');

      final targetsBlock = targets.isEmpty ? '' : "\nKnown targets:\n- ${targets.join('\n- ')}\n";
      final allergyBlock = allergies.isEmpty ? '' : "\nAllergies (avoid completely):\n- ${allergies.join('\n- ')}\n";
      final restrictionBlock = restrictions.isEmpty ? '' : "\nRestrictions/preferences:\n- ${restrictions.join('\n- ')}\n";
      final preferBlock = preferredFoods.isEmpty ? '' : "\nPreferred foods:\n- ${preferredFoods.join('\n- ')}\n";
      final avoidBlock = foodsToAvoid.isEmpty ? '' : "\nFoods to avoid:\n- ${foodsToAvoid.join('\n- ')}\n";
      final diagnosisBlock = diagnosis.trim().isEmpty
          ? ''
          : '\nDiagnosis/condition-related need (do NOT diagnose; treat as context only):\n- "$diagnosis"\n';
      final conditionsBlock = currentConditions.isEmpty
          ? ''
          : '\nCurrent conditions (from user profile; treat as context only, do NOT diagnose):\n- ${currentConditions.join('\n- ')}\n';
      final budgetBlock = budget.trim().isEmpty ? '' : '\nBudget:\n- "$budget"\n';
      final cookingBlock = cookingAbility.trim().isEmpty ? '' : '\nCooking ability:\n- "$cookingAbility"\n';

      return '''
You are an assistant that outputs ONLY a valid JSON object.

You are generating a 7-day meal plan for educational/planning purposes.

User goal: "$primaryGoal"
Meals per day: $mealsPerDay
$conditionsBlock$diagnosisBlock$allergyBlock$restrictionBlock$budgetBlock$cookingBlock$preferBlock$avoidBlock$targetsBlock

Safety rules (must follow):
- Do NOT claim to diagnose, treat, cure, or prevent any disease.
- Provide safe, general nutrition guidance only.
- If the context includes serious medical conditions, pregnancy, eating disorders, kidney disease, or diabetes medication, explicitly recommend consulting a licensed clinician/registered dietitian before major changes.
- Avoid extreme calorie restriction and avoid unsafe supplement advice.

Output requirements:
- Create a realistic 7-day plan with simple meals and friendly descriptions.
- Include an approximate macro line when helpful (e.g., "~450 kcal, 35g protein").
- Keep meals approachable: grocery-store ingredients, minimal fancy products.
- Prefer high-fiber, hydration-friendly, and balanced meals unless user goal indicates otherwise.
- No URLs.

Return JSON with EXACTLY this shape:
{
  "title": "",
  "nutritionTargets": {
    "caloriesPerDay": 0,
    "proteinGPerDay": 0,
    "carbsGPerDay": 0,
    "fatsGPerDay": 0,
    "notes": ""
  },
  "days": [
    {
      "day": "Day 1",
      "meals": {
        "breakfast": {"title": "", "description": "", "approxMacros": ""},
        "lunch": {"title": "", "description": "", "approxMacros": ""},
        "dinner": {"title": "", "description": "", "approxMacros": ""},
        "snack": {"title": "", "description": "", "approxMacros": ""}
      },
      "notes": ""
    }
  ],
  "groceryList": [""],
  "mealPrepSuggestions": [""],
  "whyThisFits": [""],
  "medicalSafetyDisclaimer": "AI-generated nutrition suggestions are for educational and planning purposes only and are not a replacement for medical advice. Users with medical conditions should consult a licensed healthcare professional or registered dietitian before making major diet changes."
}
''';
    }

    Map<String, dynamic> body() => {
          'model': 'gpt-4o',
          'temperature': 0.4,
          'response_format': {'type': 'json_object'},
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a careful nutrition planning assistant. You must output ONLY valid JSON matching the requested schema. Never include extra text.'
            },
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt()},
              ]
            }
          ]
        };

    int attempt = 0;
    while (true) {
      try {
        final data = await OpenAIClient._invokeOpenAiProxy(body(), timeout: const Duration(seconds: 45));
        AiSafetyPolicy.recordCall();
        final content = data['choices']?[0]?['message']?['content'];
        String? jsonText;
        if (content is String) {
          jsonText = content;
        } else if (content is List) {
          try {
            final buf = StringBuffer();
            for (final part in content) {
              final type = part['type'];
              if (type == 'output_text' || type == 'text') {
                final t = part['text'];
                if (t is String) buf.write(t);
              }
            }
            jsonText = buf.isEmpty ? null : buf.toString();
          } catch (e) {
            debugPrint('OpenAI content parts parse error (diet plan): $e');
          }
        }

        if (jsonText == null || jsonText.trim().isEmpty) throw Exception('Empty AI response');
        try {
          return Map<String, dynamic>.from(jsonDecode(jsonText) as Map);
        } catch (e) {
          debugPrint('OpenAI JSON parse error (diet plan): $e');
          throw Exception('Malformed JSON from AI');
        }
      } catch (e) {
        attempt += 1;
        if (attempt >= 2) rethrow;
        await Future.delayed(Duration(milliseconds: 450 * attempt));
      }
    }
  }
}

