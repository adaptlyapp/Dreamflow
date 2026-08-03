import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wellspring/models/education_resource.dart';

/// Service exposing the curated catalog of trusted educational resources
/// surfaced in the Family Education Hub, plus per-user "saved" favorites
/// stored locally via SharedPreferences.
///
/// All sources are reputable public health organizations and databases:
/// - MedlinePlus / NIH / NLM (trusted health information)
/// - USDA FoodData Central (nutrition database)
/// - SUNA (Society of Urologic Nurses and Associates - specialized education)
class EducationService {
  EducationService._();
  static final EducationService instance = EducationService._();

  static const _favoritesKeyPrefix = 'edu_hub_favorites_';

  /// Curated, hand-picked catalog of trusted educational content.
  /// Links point at MedlinePlus & related NIH-backed pages.
  static const List<EducationResource> _catalog = [
    // ---------- Spinal Cord Injury ----------
    EducationResource(
      id: 'sci-overview',
      title: 'Spinal Cord Injury: Overview',
      description:
          'What a spinal cord injury is, how it happens, and what to expect during recovery.',
      summary:
          'A spinal cord injury (SCI) damages the bundle of nerves that carries signals between the brain and the body. Depending on the location and severity of the injury, it can affect movement, sensation, breathing, bladder, bowel, and skin care.',
      keyTakeaways: [
        'SCI severity depends on the level and completeness of the injury.',
        'Early rehabilitation greatly improves long-term outcomes.',
        'Families play a vital role in mobility, skin care, and emotional support.',
      ],
      whyItMatters:
          'Understanding the basics of SCI helps families anticipate care needs, ask informed questions, and partner effectively with the medical team.',
      category: 'Spinal Cord Injury',
      tags: ['SCI', 'paralysis', 'rehab', 'overview'],
      type: EducationResourceType.article,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/spinalcordinjuries.html',
      estimatedMinutes: 6,
    ),
    EducationResource(
      id: 'sci-anatomy-video',
      title: 'Spinal Cord Anatomy (Video)',
      description:
          'Animated MedlinePlus video explaining the structure of the spinal cord.',
      summary:
          'This short animation walks through the regions of the spinal cord (cervical, thoracic, lumbar, sacral) and shows how nerves branch out to control the body.',
      keyTakeaways: [
        'Higher-level injuries (cervical) typically affect more of the body.',
        'Nerves exit at each vertebral level to control specific muscles and sensations.',
      ],
      whyItMatters:
          'Seeing the anatomy makes it easier to understand why an injury at a specific level produces specific symptoms.',
      category: 'Spinal Cord Injury',
      tags: ['anatomy', 'spinal cord', 'video'],
      type: EducationResourceType.video,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/anatomyvideos.html',
      estimatedMinutes: 3,
    ),

    // ---------- Stroke ----------
    EducationResource(
      id: 'stroke-overview',
      title: 'Stroke: What Families Should Know',
      description:
          'How strokes happen, warning signs, and the road to recovery.',
      summary:
          'A stroke happens when blood flow to part of the brain is blocked or a blood vessel bursts. Quick treatment limits damage; rehabilitation helps the brain rewire.',
      keyTakeaways: [
        'Remember F.A.S.T.: Face drooping, Arm weakness, Speech difficulty, Time to call 911.',
        'Recovery is most rapid in the first 3-6 months but continues for years.',
        'Therapy, repetition, and emotional support all drive progress.',
      ],
      whyItMatters:
          'Spotting stroke warning signs quickly — even after discharge — can prevent another event and save lives.',
      category: 'Stroke',
      tags: ['stroke', 'FAST', 'brain', 'rehab'],
      type: EducationResourceType.article,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/stroke.html',
      estimatedMinutes: 7,
    ),
    EducationResource(
      id: 'stroke-anatomy-video',
      title: 'How a Stroke Affects the Brain (Video)',
      description:
          'Animated explainer of ischemic vs. hemorrhagic stroke.',
      summary:
          'A short, plain-language animation showing what happens inside the brain during a stroke and how different types of stroke are treated.',
      keyTakeaways: [
        'Ischemic strokes are caused by clots; hemorrhagic strokes by bleeding.',
        'The location of the stroke predicts which abilities are affected.',
      ],
      whyItMatters:
          'Understanding the type of stroke helps families understand why specific therapies were chosen.',
      category: 'Stroke',
      tags: ['stroke', 'video', 'brain'],
      type: EducationResourceType.video,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/anatomyvideos.html',
      estimatedMinutes: 3,
    ),

    // ---------- Traumatic Brain Injury ----------
    EducationResource(
      id: 'tbi-overview',
      title: 'Traumatic Brain Injury: A Family Guide',
      description:
          'Understanding TBI severity, symptoms, and recovery milestones.',
      summary:
          'TBI ranges from mild (concussion) to severe. Recovery is highly individual and often includes physical, cognitive, and emotional changes.',
      keyTakeaways: [
        'Cognitive fatigue is real — short, frequent rests help.',
        'Mood and personality changes are common and treatable.',
        'Structure, calm environments, and routine accelerate recovery.',
      ],
      whyItMatters:
          'Family understanding reduces frustration and helps the person with TBI feel supported and safe.',
      category: 'Traumatic Brain Injury',
      tags: ['TBI', 'concussion', 'brain injury', 'cognition'],
      type: EducationResourceType.article,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/traumaticbraininjury.html',
      estimatedMinutes: 8,
    ),

    // ---------- Neurological Conditions ----------
    EducationResource(
      id: 'neuro-overview',
      title: 'Neurological Conditions: Big Picture',
      description:
          'Overview of disorders affecting the brain, spinal cord, and nerves.',
      summary:
          'Neurological conditions affect how the nervous system controls the body. Symptoms vary widely — from weakness and tremor to memory loss.',
      keyTakeaways: [
        'Many neurological conditions are managed long-term, not "cured".',
        'Therapy, medication adherence, and rest are the foundations of care.',
      ],
      whyItMatters:
          'Setting realistic expectations helps families pace themselves for the long haul.',
      category: 'Neurological Conditions',
      tags: ['neurology', 'nerve', 'brain', 'overview'],
      type: EducationResourceType.article,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/neurologicdiseases.html',
      estimatedMinutes: 6,
    ),
    EducationResource(
      id: 'nervous-system-video',
      title: 'The Nervous System (Video)',
      description: 'Animated anatomy of the nervous system.',
      summary:
          'Short MedlinePlus animation explaining how the central and peripheral nervous systems work together.',
      keyTakeaways: [
        'The central nervous system = brain + spinal cord.',
        'Peripheral nerves carry signals to and from every muscle and organ.',
      ],
      whyItMatters:
          'A clear mental model of the nervous system makes other diagnoses easier to understand.',
      category: 'Neurological Conditions',
      tags: ['anatomy', 'nervous system', 'video'],
      type: EducationResourceType.video,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/anatomyvideos.html',
      estimatedMinutes: 3,
    ),

    // ---------- Mobility & Transfers ----------
    EducationResource(
      id: 'mobility-transfers',
      title: 'Safe Transfers: Bed, Chair, and Wheelchair',
      description:
          'Step-by-step guidance on safely helping a loved one move between surfaces.',
      summary:
          'Safe transfers protect both the patient and the caregiver. Use a gait belt, lock wheels, plan the move, and lift with the legs — never the back.',
      keyTakeaways: [
        'Always lock the wheelchair before transferring.',
        'Position yourself close to the person — distance increases strain.',
        'Move on a count of three so everyone moves together.',
      ],
      whyItMatters:
          'Most caregiver injuries happen during transfers. Good technique prevents falls and back injuries.',
      category: 'Mobility & Transfers',
      tags: ['transfer', 'wheelchair', 'caregiver', 'safety'],
      type: EducationResourceType.guide,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/mobilityaids.html',
      estimatedMinutes: 6,
    ),
    EducationResource(
      id: 'wheelchair-use',
      title: 'Using a Wheelchair Safely',
      description: 'Daily wheelchair use, fit, and skin protection.',
      summary:
          'Covers proper wheelchair fit, posture, pressure relief, and tips for navigating curbs, ramps, and tight spaces.',
      keyTakeaways: [
        'Shift weight every 15-30 minutes to protect the skin.',
        'Check tire pressure and brakes weekly.',
        'A properly fit chair prevents posture and pain problems.',
      ],
      whyItMatters:
          'A well-fit chair used correctly preserves independence and prevents pressure injuries.',
      category: 'Mobility & Transfers',
      tags: ['wheelchair', 'mobility', 'independence'],
      type: EducationResourceType.guide,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/mobilityaids.html',
      estimatedMinutes: 5,
    ),

    // ---------- Bladder & Bowel ----------
    EducationResource(
      id: 'bladder-management',
      title: 'Bladder Management After Injury',
      description: 'Catheter care, schedules, and infection prevention.',
      summary:
          'After spinal cord or neurological injury, bladder routines often change. A consistent schedule and clean technique prevent UTIs and accidents.',
      keyTakeaways: [
        'Wash hands before and after every catheterization.',
        'Watch for cloudy urine, fever, or new back pain — possible UTI signs.',
        'Stay hydrated, but on a planned schedule.',
      ],
      whyItMatters:
          'UTIs are the #1 reason for re-hospitalization after SCI. Good bladder care prevents them.',
      category: 'Bladder & Bowel Management',
      tags: ['catheter', 'UTI', 'bladder', 'infection'],
      type: EducationResourceType.guide,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/urinarycatheters.html',
      estimatedMinutes: 6,
    ),
    EducationResource(
      id: 'bowel-program',
      title: 'Bowel Program Basics',
      description: 'Building a predictable, dignified bowel routine.',
      summary:
          'A bowel program uses timing, diet, hydration, and sometimes medication or digital stimulation to create predictable bowel movements.',
      keyTakeaways: [
        'Consistency (same time daily) is more important than the exact method.',
        'Fiber + fluids = softer, easier movements.',
        'Track results to spot problems early.',
      ],
      whyItMatters:
          'A reliable bowel program restores dignity, freedom, and confidence to leave the house.',
      category: 'Bladder & Bowel Management',
      tags: ['bowel', 'routine', 'caregiver'],
      type: EducationResourceType.guide,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/bowelmovement.html',
      estimatedMinutes: 5,
    ),

    // ---------- Skin Health ----------
    EducationResource(
      id: 'pressure-injury',
      title: 'Preventing Pressure Injuries (Bedsores)',
      description: 'How to spot, prevent, and respond to pressure injuries.',
      summary:
          'Pressure injuries form when skin is squeezed against a bone for too long. They can develop in hours. Prevention is far easier than treatment.',
      keyTakeaways: [
        'Reposition every 2 hours in bed, every 15-30 minutes in a chair.',
        'Inspect skin daily, especially the tailbone, heels, and hips.',
        'Keep skin clean, dry, and moisturized — but not soaked.',
      ],
      whyItMatters:
          'A serious pressure injury can require months of bed rest or surgery. Daily prevention is worth it.',
      category: 'Skin Health',
      tags: ['skin', 'bedsore', 'pressure injury', 'prevention'],
      type: EducationResourceType.guide,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/pressuresores.html',
      estimatedMinutes: 6,
    ),
    EducationResource(
      id: 'skin-care-daily',
      title: 'Daily Skin Care Checklist',
      description: 'A simple morning + evening skin care routine.',
      summary:
          'Two short, daily skin inspections catch problems early. Look for redness that does not fade, broken skin, or new bruising.',
      keyTakeaways: [
        'Use a mirror to see hard-to-reach spots.',
        'Photograph anything new and share with the care team.',
      ],
      whyItMatters:
          'Catching a stage-1 issue means a few days of off-loading. Missing it can mean a hospital stay.',
      category: 'Skin Health',
      tags: ['skin', 'checklist', 'routine'],
      type: EducationResourceType.guide,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/skinconditions.html',
      estimatedMinutes: 4,
    ),

    // ---------- Mental Health ----------
    EducationResource(
      id: 'caregiver-mental-health',
      title: 'Caring for the Caregiver: Mental Health',
      description: 'Recognizing burnout and protecting your own well-being.',
      summary:
          'Caregivers are at high risk for depression, anxiety, and burnout. Naming the feelings, taking real breaks, and connecting with other caregivers all help.',
      keyTakeaways: [
        'You cannot pour from an empty cup — rest is care.',
        'Burnout signs: irritability, sleep problems, hopelessness.',
        'Help is out there — ask the care team.',
      ],
      whyItMatters:
          'A healthy caregiver is the single biggest predictor of a healthy patient at home.',
      category: 'Mental Health & Emotional Well-Being',
      tags: ['caregiver', 'mental health', 'burnout', 'depression'],
      type: EducationResourceType.article,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/caregivers.html',
      estimatedMinutes: 5,
    ),
    EducationResource(
      id: 'patient-emotional',
      title: 'Emotional Recovery After Serious Illness',
      description: 'Grief, identity, and finding meaning again.',
      summary:
          'Patients often grieve the life they had. Sadness, anger, and fear are normal. Counseling, peer support, and time all help.',
      keyTakeaways: [
        'Adjustment is a process, not a moment.',
        'Persistent low mood deserves professional support.',
      ],
      whyItMatters:
          'Emotional recovery is just as real as physical recovery — and often slower.',
      category: 'Mental Health & Emotional Well-Being',
      tags: ['depression', 'grief', 'emotional', 'recovery'],
      type: EducationResourceType.article,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/mentalhealth.html',
      estimatedMinutes: 6,
    ),

    // ---------- Caregiver Education ----------
    EducationResource(
      id: 'caregiver-medications',
      title: 'Managing Medications at Home',
      description: 'Organizing, tracking, and giving medications safely.',
      summary:
          'Use a pill organizer, keep a single up-to-date medication list, and bring it to every appointment. Never crush or split a medication without checking first.',
      keyTakeaways: [
        'One master list, kept current, prevents most errors.',
        'Set phone alarms — don\'t rely on memory.',
        'Ask the pharmacist anything; it\'s free.',
      ],
      whyItMatters:
          'Medication errors are a leading cause of re-admission. A good system at home prevents them.',
      category: 'Caregiver Education',
      tags: ['medication', 'caregiver', 'safety'],
      type: EducationResourceType.guide,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/medicines.html',
      estimatedMinutes: 5,
    ),
    EducationResource(
      id: 'caregiver-emergency',
      title: 'When to Call 911 vs. the Care Team',
      description: 'A simple decision guide for common situations.',
      summary:
          'Trouble breathing, chest pain, sudden weakness, stroke signs, or unresponsive — call 911. Fever, increased pain, or new symptoms without red flags — call the care team first.',
      keyTakeaways: [
        'When in doubt, call 911 — never feel embarrassed.',
        'Keep a printed list of meds and conditions by the phone.',
      ],
      whyItMatters:
          'Knowing in advance who to call removes panic from emergencies.',
      category: 'Caregiver Education',
      tags: ['emergency', '911', 'caregiver', 'safety'],
      type: EducationResourceType.guide,
      sourceName: 'MedlinePlus',
      url: 'https://medlineplus.gov/emergencymedicalservices.html',
      estimatedMinutes: 4,
    ),

    // ---------- Nutrition & Food Database ----------
    EducationResource(
      id: 'usda-food-database',
      title: 'USDA FoodData Central',
      description: 'Comprehensive nutrition database for foods and ingredients.',
      summary:
          'FoodData Central provides detailed nutrient profiles for thousands of foods. Search by food name to find calorie, protein, vitamin, and mineral content for meal planning.',
      keyTakeaways: [
        'Search over 300,000 foods for complete nutrition data.',
        'Compare nutrients across different food brands and types.',
        'Use data to plan balanced meals and track dietary intake.',
      ],
      whyItMatters:
          'Accurate nutrition information helps caregivers meet dietary needs and manage health conditions through food.',
      category: 'Nutrition & Food Database',
      tags: ['nutrition', 'food', 'database', 'USDA', 'diet'],
      type: EducationResourceType.guide,
      sourceName: 'USDA',
      url: 'https://fdc.nal.usda.gov/',
      estimatedMinutes: 10,
    ),

    // ---------- Specialized Nursing Education ----------
    EducationResource(
      id: 'suna-urologic-education',
      title: 'SUNA Online Education for Urologic Care',
      description: 'Specialized education from the Society of Urologic Nurses and Associates.',
      summary:
          'SUNA provides evidence-based education on urologic conditions including catheter care, bladder management, kidney health, and urologic cancers from nursing experts.',
      keyTakeaways: [
        'Learn from certified urologic nursing specialists.',
        'Access webinars, courses, and patient education materials.',
        'Evidence-based guidance for complex urologic conditions.',
      ],
      whyItMatters:
          'Specialized nursing education provides advanced knowledge for managing urologic conditions at home with confidence.',
      category: 'Bladder & Bowel Management',
      tags: ['urologic', 'catheter', 'bladder', 'kidney', 'nursing', 'SUNA'],
      type: EducationResourceType.guide,
      sourceName: 'SUNA',
      url: 'https://www.suna.org/online-education',
      estimatedMinutes: 15,
    ),

    // ---------- General Health Resources ----------
    EducationResource(
      id: 'nih-health-info',
      title: 'NIH Health Information',
      description: 'Trusted health information from the National Institutes of Health.',
      summary:
          'The NIH provides research-backed health information on diseases, conditions, wellness, and clinical trials. Access the latest medical research and consumer health guides.',
      keyTakeaways: [
        'Access cutting-edge medical research and clinical trial information.',
        'Learn about rare diseases and specialized treatments.',
        'Find NIH-funded research relevant to your condition.',
      ],
      whyItMatters:
          'NIH is the nation\'s medical research agency, providing authoritative information on health conditions and treatments.',
      category: 'Caregiver Education',
      tags: ['NIH', 'research', 'health', 'clinical trials'],
      type: EducationResourceType.article,
      sourceName: 'NIH',
      url: 'https://www.nih.gov/',
      estimatedMinutes: 8,
    ),
  ];

  /// Categories used to group content in the hub. Order is intentional.
  static const List<String> categories = [
    'Spinal Cord Injury',
    'Stroke',
    'Traumatic Brain Injury',
    'Neurological Conditions',
    'Mobility & Transfers',
    'Bladder & Bowel Management',
    'Skin Health',
    'Mental Health & Emotional Well-Being',
    'Nutrition & Food Database',
    'Caregiver Education',
  ];

  List<EducationResource> all() => List.unmodifiable(_catalog);

  List<EducationResource> byCategory(String category) =>
      _catalog.where((r) => r.category == category).toList();

  EducationResource? byId(String id) {
    for (final r in _catalog) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Returns resources related to [resource] — same category, excluding itself.
  List<EducationResource> related(EducationResource resource, {int limit = 4}) {
    final same = _catalog
        .where((r) => r.category == resource.category && r.id != resource.id)
        .toList();
    return same.take(limit).toList();
  }

  /// Maps a free-form condition name (e.g. "Spinal Cord Injury", "Stroke",
  /// "Multiple Sclerosis") to the catalog categories most relevant to it.
  /// Returns an empty list if no specific match is found.
  List<String> _categoriesForCondition(String conditionName) {
    final c = conditionName.toLowerCase();
    final out = <String>{};
    // Direct condition-specific categories
    if (c.contains('spinal cord') || c == 'sci') {
      out.addAll([
        'Spinal Cord Injury',
        'Mobility & Transfers',
        'Bladder & Bowel Management',
        'Skin Health',
      ]);
    }
    if (c.contains('stroke') || c.contains('cva')) {
      out.addAll(['Stroke', 'Mobility & Transfers']);
    }
    if (c.contains('traumatic brain') || c.contains('tbi') ||
        c.contains('concussion') || c.contains('brain injury')) {
      out.addAll(['Traumatic Brain Injury', 'Mental Health & Emotional Well-Being']);
    }
    if (c.contains('multiple sclerosis') || c.contains(' ms') || c == 'ms' ||
        c.contains('parkinson') || c.contains('als') ||
        c.contains('neuropathy') || c.contains('seizure') ||
        c.contains('epilepsy') || c.contains('guillain') ||
        c.contains('neurolog')) {
      out.addAll([
        'Neurological Conditions',
        'Mobility & Transfers',
      ]);
    }
    if (c.contains('amputee') || c.contains('amputation') ||
        c.contains('paralys') || c.contains('paraplegia') ||
        c.contains('quadriplegia') || c.contains('tetraplegia') ||
        c.contains('mobility')) {
      out.add('Mobility & Transfers');
    }
    if (c.contains('bladder') || c.contains('bowel') ||
        c.contains('incontinence') || c.contains('urinary')) {
      out.add('Bladder & Bowel Management');
    }
    if (c.contains('pressure') || c.contains('skin') ||
        c.contains('wound') || c.contains('bedsore')) {
      out.add('Skin Health');
    }
    if (c.contains('depression') || c.contains('anxiety') ||
        c.contains('ptsd') || c.contains('mental')) {
      out.add('Mental Health & Emotional Well-Being');
    }
    return out.toList();
  }

  /// Returns resources curated to the patient's specific conditions.
  /// [conditionNames] are free-form names taken from the patient profile.
  /// Resources are de-duplicated; caregiver foundations are added at the end
  /// so the list is never empty.
  List<EducationResource> recommendedForConditions(
    List<String> conditionNames, {
    int perCondition = 4,
  }) {
    final out = <EducationResource>[];
    final seen = <String>{};
    for (final cond in conditionNames) {
      final cats = _categoriesForCondition(cond);
      for (final cat in cats) {
        for (final r in byCategory(cat)) {
          if (seen.add(r.id)) {
            out.add(r);
            if (out.length >= perCondition * conditionNames.length) break;
          }
        }
      }
    }
    // Caregiver essentials as a safety net
    for (final id in const [
      'caregiver-medications',
      'caregiver-emergency',
      'caregiver-mental-health',
    ]) {
      final r = byId(id);
      if (r != null && seen.add(r.id)) out.add(r);
    }
    return out;
  }

  /// Groups recommended resources by the originating condition name, so the
  /// UI can render a section per condition (e.g. "For Stroke", "For TBI").
  /// Categories with no condition-specific match are dropped from the map;
  /// callers may show a generic caregiver section instead.
  Map<String, List<EducationResource>> recommendedByCondition(
    List<String> conditionNames,
  ) {
    final map = <String, List<EducationResource>>{};
    final used = <String>{};
    for (final cond in conditionNames) {
      final cats = _categoriesForCondition(cond);
      final list = <EducationResource>[];
      for (final cat in cats) {
        for (final r in byCategory(cat)) {
          if (used.add(r.id)) list.add(r);
        }
      }
      if (list.isNotEmpty) map[cond] = list;
    }
    return map;
  }

  /// Best-effort recommendations for a family. We don't have a verified
  /// patient diagnosis field, so we mix a "starter pack" with anything
  /// matching keywords found in [patientHints] (free-form strings such as
  /// goal titles, condition names, or notes).
  List<EducationResource> recommendedFor(List<String> patientHints,
      {int limit = 6}) {
    final hintsLower = patientHints
        .where((h) => h.isNotEmpty)
        .map((h) => h.toLowerCase())
        .toList();

    final scored = <EducationResource, int>{};
    for (final r in _catalog) {
      var score = 0;
      for (final hint in hintsLower) {
        if (r.title.toLowerCase().contains(hint)) score += 4;
        if (r.category.toLowerCase().contains(hint)) score += 3;
        for (final t in r.tags) {
          if (hint.contains(t.toLowerCase()) ||
              t.toLowerCase().contains(hint)) {
            score += 2;
          }
        }
        if (r.description.toLowerCase().contains(hint)) score += 1;
      }
      if (score > 0) scored[r] = score;
    }

    final ranked = scored.keys.toList()
      ..sort((a, b) => scored[b]!.compareTo(scored[a]!));

    if (ranked.length >= limit) return ranked.take(limit).toList();

    // Pad with caregiver-foundation content so the section is never empty.
    final fallback = [
      'caregiver-medications',
      'caregiver-emergency',
      'pressure-injury',
      'mobility-transfers',
      'caregiver-mental-health',
      'bladder-management',
    ];
    final out = <EducationResource>[...ranked];
    for (final id in fallback) {
      if (out.length >= limit) break;
      final r = byId(id);
      if (r != null && !out.contains(r)) out.add(r);
    }
    return out;
  }

  // ---------- Favorites (local) ----------

  String _key(String userId) => '$_favoritesKeyPrefix$userId';

  Future<Set<String>> getFavorites(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key(userId))?.toSet() ?? <String>{};
    } catch (e) {
      debugPrint('[EducationService] getFavorites error: $e');
      return <String>{};
    }
  }

  Future<bool> isFavorite(String userId, String resourceId) async {
    final favs = await getFavorites(userId);
    return favs.contains(resourceId);
  }

  Future<Set<String>> toggleFavorite(String userId, String resourceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favs = prefs.getStringList(_key(userId))?.toSet() ?? <String>{};
      if (favs.contains(resourceId)) {
        favs.remove(resourceId);
      } else {
        favs.add(resourceId);
      }
      await prefs.setStringList(_key(userId), favs.toList());
      return favs;
    } catch (e) {
      debugPrint('[EducationService] toggleFavorite error: $e');
      return <String>{};
    }
  }

  Future<List<EducationResource>> getSavedResources(String userId) async {
    final favs = await getFavorites(userId);
    return _catalog.where((r) => favs.contains(r.id)).toList();
  }
}
