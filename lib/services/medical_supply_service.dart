import 'package:wellspring/models/medical_supply.dart';

/// Service providing curated medical supplies & equipment catalog
/// with educational resources from trusted sources including:
/// - NIH (nih.gov)
/// - MedlinePlus (medlineplus.gov)
/// - USDA FoodData Central (fdc.nal.usda.gov)
/// - SUNA (suna.org)
/// - Craig Hospital (craighospital.org)
/// - Mayo Clinic
/// - United Spinal
/// - Comfort Medical
class MedicalSupplyService {
  MedicalSupplyService._();
  static final MedicalSupplyService instance = MedicalSupplyService._();

  /// All supply categories
  static const List<SupplyCategory> categories = [
    SupplyCategory(
      id: 'bladder',
      name: 'Bladder Management',
      emoji: '🚽',
      description: 'Catheters, drainage bags, and urinary care supplies',
    ),
    SupplyCategory(
      id: 'bowel',
      name: 'Bowel Management',
      emoji: '🩹',
      description: 'Bowel program supplies and digestive health products',
    ),
    SupplyCategory(
      id: 'ostomy',
      name: 'Ostomy',
      emoji: '👜',
      description: 'Ostomy bags, barriers, and accessories',
    ),
    SupplyCategory(
      id: 'wound',
      name: 'Wound Care',
      emoji: '🩹',
      description: 'Dressings, bandages, and skin protection products',
    ),
    SupplyCategory(
      id: 'diabetes',
      name: 'Diabetes',
      emoji: '💉',
      description: 'Glucose monitors, insulin supplies, and diabetic care',
    ),
    SupplyCategory(
      id: 'respiratory',
      name: 'Respiratory',
      emoji: '🫁',
      description: 'CPAP, oxygen, nebulizers, and breathing equipment',
    ),
    SupplyCategory(
      id: 'mobility',
      name: 'Mobility',
      emoji: '♿',
      description: 'Wheelchairs, walkers, canes, and mobility aids',
    ),
    SupplyCategory(
      id: 'bathroom',
      name: 'Bathroom Safety',
      emoji: '🛁',
      description: 'Shower chairs, grab bars, and bathing equipment',
    ),
    SupplyCategory(
      id: 'pressure',
      name: 'Pressure Relief',
      emoji: '🛏',
      description: 'Cushions, mattresses, and positioning products',
    ),
    SupplyCategory(
      id: 'feeding',
      name: 'Feeding',
      emoji: '🍽',
      description: 'Feeding tubes, adaptive utensils, and nutrition supplies',
    ),
    SupplyCategory(
      id: 'monitoring',
      name: 'Home Monitoring',
      emoji: '❤️',
      description: 'Blood pressure, pulse ox, thermometers, and monitors',
    ),
    SupplyCategory(
      id: 'daily',
      name: 'Daily Living',
      emoji: '🧤',
      description: 'Adaptive tools, dressing aids, and daily care products',
    ),
    SupplyCategory(
      id: 'reorder',
      name: 'Supply Reordering',
      emoji: '📦',
      description: 'Manage subscriptions and automatic refills',
    ),
    SupplyCategory(
      id: 'insurance',
      name: 'Insurance & DME Providers',
      emoji: '🏥',
      description: 'Coverage information and supplier directories',
    ),
  ];

  /// Curated catalog of medical supplies with educational resources
  static final List<MedicalSupply> _catalog = [
    // ========== BLADDER MANAGEMENT ==========
    MedicalSupply(
      id: 'intermittent-catheter',
      name: 'Intermittent Catheters',
      category: 'bladder',
      description:
          'Single-use catheters inserted periodically throughout the day to empty the bladder. Available in various lengths, materials, and tip types.',
      whoUsesIt:
          'People with spinal cord injury, multiple sclerosis, spina bifida, or neurogenic bladder who need scheduled bladder emptying.',
      commonBrands: [
        'Coloplast SpeediCath',
        'Hollister VaPro',
        'ConvaTec GentleCath',
        'Cure Medical',
        'Bard',
      ],
      resources: [
        InstructionalResource(
          title: 'SUNA Catheter Education Tool (PDF)',
          url: 'https://www.suna.org/',
          type: ResourceType.pdf,
          description: 'Comprehensive catheter care guide from urologic nursing experts',
        ),
        InstructionalResource(
          title: 'MedlinePlus: Urinary Catheters',
          url: 'https://medlineplus.gov/urinarycatheters.html',
          type: ResourceType.article,
          description: 'Overview of catheter types, use, and infection prevention',
        ),
        InstructionalResource(
          title: 'SUNA Online Education',
          url: 'https://www.suna.org/online-education',
          type: ResourceType.website,
          description: 'Expert webinars and courses on urologic care',
        ),
        InstructionalResource(
          title: 'Craig Hospital: Bladder Management',
          url: 'https://craighospital.org/',
          type: ResourceType.article,
          description: 'SCI-specific bladder care from a leading rehabilitation hospital',
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions:
            'Intermittent catheters are single-use and should be discarded after each use. Wash hands thoroughly before and after catheterization.',
        replacementSchedule: 'Use a new catheter for each catheterization (4-6 times daily)',
      ),
      troubleshooting:
          'Difficulty inserting: Try relaxation techniques, use more lubricant, or try a different angle.\nBurning sensation: May indicate UTI - contact healthcare provider.\nNo urine flow: Ensure catheter is fully inserted; try gentle cough or belly press.',
      whereToObtain: const [
        ObtainmentOption(
          source: 'Comfort Medical',
          details: 'https://www.comfortmedical.com/en/ - Direct-to-consumer catheter supplier with insurance billing',
        ),
        ObtainmentOption(source: 'DME Supplier', details: 'Prescribed by urologist and delivered monthly'),
        ObtainmentOption(source: 'Pharmacy', details: 'Some pharmacies stock catheters with prescription'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage:
            'Medicare Part B covers up to 200 catheters per month with prescription. Most private insurance covers with prior authorization.',
        tips:
            'Get a prescription for "sterile intermittent catheters" with quantity per month. Request samples to try different brands before committing.',
      ),
      iconEmoji: '🚽',
    ),
    MedicalSupply(
      id: 'foley-catheter',
      name: 'Indwelling (Foley) Catheters',
      category: 'bladder',
      description:
          'Long-term catheters that remain in the bladder, draining continuously into a collection bag. Held in place by a small balloon.',
      whoUsesIt:
          'People who cannot perform intermittent catheterization or need continuous drainage due to surgery, illness, or severe mobility limitations.',
      commonBrands: ['Bard', 'Medline', 'Dover'],
      resources: [
        InstructionalResource(
          title: 'MedlinePlus: Foley Catheter Care',
          url: 'https://medlineplus.gov/urinarycatheters.html',
          type: ResourceType.article,
        ),
        InstructionalResource(
          title: 'SUNA: Catheter-Associated UTI Prevention',
          url: 'https://www.suna.org/online-education',
          type: ResourceType.website,
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions: 'Clean catheter insertion site daily with soap and water. Empty drainage bag when 2/3 full.',
        replacementSchedule: 'Typically changed every 2-4 weeks by a nurse or trained caregiver',
      ),
      troubleshooting:
          'Leaking around catheter: May indicate blockage or bladder spasms - contact provider.\nCatheter not draining: Check for kinks in tubing; ensure bag is below bladder level.\nStrong odor: May indicate infection - increase fluids and notify healthcare team.',
      whereToObtain: const [
        ObtainmentOption(source: 'Home Health Nurse', details: 'Usually changed during home health visits'),
        ObtainmentOption(source: 'DME Supplier', details: 'Delivery of monthly supplies with prescription'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage: 'Medicare and most insurance cover supplies with prescription and medical necessity documentation.',
        tips: 'Ensure proper documentation of why indwelling catheter is medically necessary versus intermittent.',
      ),
      iconEmoji: '🚽',
    ),

    // ========== BOWEL MANAGEMENT ==========
    MedicalSupply(
      id: 'bowel-routine-supplies',
      name: 'Bowel Program Supplies',
      category: 'bowel',
      description:
          'Supplies for establishing predictable bowel movements including suppositories, digital stimulation aids, protective pads, and irrigation systems.',
      whoUsesIt:
          'People with spinal cord injury, neurological conditions, or bowel dysfunction who need scheduled bowel care.',
      commonBrands: ['Magic Bullet', 'Enemeez', 'Peristeen', 'Fleet'],
      resources: [
        InstructionalResource(
          title: 'UNC Bowel Retraining Guide (PDF)',
          url: 'https://www.med.unc.edu/ibs/wp-content/uploads/sites/450/2017/10/BowelRetrain.pdf',
          type: ResourceType.pdf,
          description: 'Step-by-step bowel program instructions',
        ),
        InstructionalResource(
          title: 'Mayo Clinic: Bowel Management (PDF)',
          url: 'https://mcforms.mayo.edu/mc5200-mc5299/mc5283.pdf',
          type: ResourceType.pdf,
          description: 'Comprehensive bowel care guide from Mayo Clinic',
        ),
        InstructionalResource(
          title: 'United Spinal: Bowel Program Techniques',
          url: 'https://unitedspinal.org/bowel-programs-how-perform-different-techniques/',
          type: ResourceType.article,
          description: 'Detailed guide to different bowel program methods',
        ),
        InstructionalResource(
          title: 'MedlinePlus: Bowel Movement',
          url: 'https://medlineplus.gov/bowelmovement.html',
          type: ResourceType.article,
        ),
        InstructionalResource(
          title: 'Craig Hospital: Bowel Management',
          url: 'https://craighospital.org/',
          type: ResourceType.article,
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions: 'Wash reusable equipment with soap and water after each use. Store in clean, dry area.',
        replacementSchedule: 'Suppositories are single-use. Replace digital stimulation devices every 6 months.',
      ),
      troubleshooting:
          'No results after 30-45 minutes: Try additional suppository or change timing of program.\nAccidents between programs: May need to adjust diet, timing, or method - consult with provider.\nAbdominal pain or bleeding: Stop program and contact healthcare provider immediately.',
      whereToObtain: const [
        ObtainmentOption(source: 'Pharmacy', details: 'Suppositories and enemas available over-the-counter'),
        ObtainmentOption(source: 'DME Supplier', details: 'Prescription-only irrigation systems'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage: 'Basic supplies often covered with prescription. Irrigation systems may require prior authorization.',
        tips: 'Track bowel program results for 2 weeks before first GI appointment to help with prescription.',
      ),
      iconEmoji: '🩹',
    ),

    // ========== WOUND CARE ==========
    MedicalSupply(
      id: 'pressure-injury-dressings',
      name: 'Pressure Injury Dressings',
      category: 'wound',
      description:
          'Specialized dressings for pressure injuries (bedsores) including hydrocolloid, foam, alginate, and transparent film dressings.',
      whoUsesIt: 'People with limited mobility at risk for or treating pressure injuries on bony areas.',
      commonBrands: ['DuoDERM', 'Tegaderm', 'Mepilex', 'Aquacel'],
      resources: [
        InstructionalResource(
          title: 'MedlinePlus: Pressure Sores',
          url: 'https://medlineplus.gov/pressuresores.html',
          type: ResourceType.article,
        ),
        InstructionalResource(
          title: 'NIH Wound Care Research',
          url: 'https://www.nih.gov/',
          type: ResourceType.website,
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions: 'Most dressings are single-use. Follow wound care nurse instructions for cleaning wounds.',
        replacementSchedule: 'Change frequency varies by dressing type and wound status (typically 3-7 days)',
      ),
      troubleshooting: 'Increased pain, odor, or drainage: May indicate infection - contact wound care nurse immediately.',
      whereToObtain: const [
        ObtainmentOption(source: 'Home Health Nurse', details: 'Often provided during home health visits'),
        ObtainmentOption(source: 'DME Supplier', details: 'Prescription required for ongoing supplies'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage: 'Covered with prescription and documentation of wound size/stage. May require wound care nurse assessment.',
        tips: 'Take photos of wounds to document healing progress for insurance and medical team.',
      ),
      iconEmoji: '🩹',
    ),

    // ========== MOBILITY ==========
    MedicalSupply(
      id: 'manual-wheelchair',
      name: 'Manual Wheelchairs',
      category: 'mobility',
      description:
          'Self-propelled or attendant-propelled wheelchairs for mobility. Options include standard, lightweight, and ultralight models.',
      whoUsesIt:
          'People with lower extremity weakness, paralysis, or severe mobility limitations who retain upper body strength.',
      commonBrands: ['Invacare', 'Quickie', 'TiLite', 'Permobil'],
      resources: [
        InstructionalResource(
          title: 'MedlinePlus: Mobility Aids',
          url: 'https://medlineplus.gov/mobilityaids.html',
          type: ResourceType.article,
        ),
        InstructionalResource(
          title: 'Craig Hospital: Wheelchair Skills',
          url: 'https://craighospital.org/',
          type: ResourceType.article,
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions: 'Wipe frame weekly. Clean wheels monthly. Check tire pressure weekly.',
        replacementSchedule: 'Medicare replaces wheelchairs every 5 years. Cushions may need yearly replacement.',
      ),
      troubleshooting:
          'Difficulty propelling: Check tire pressure, ensure wheels spin freely, may need different hand rims.\nPoor posture: Likely needs professional seating evaluation and custom cushion.',
      whereToObtain: const [
        ObtainmentOption(source: 'DME Supplier', details: 'Requires prescription and face-to-face evaluation'),
        ObtainmentOption(source: 'Seating Clinic', details: 'Complex rehab wheelchairs require ATP evaluation'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage:
            'Medicare covers standard wheelchairs every 5 years. Complex rehab chairs require detailed documentation and ATP evaluation.',
        tips:
            'Get evaluated by an Assistive Technology Professional (ATP) before ordering. Trial different models if possible.',
      ),
      iconEmoji: '♿',
    ),

    // ========== BATHROOM SAFETY ==========
    MedicalSupply(
      id: 'shower-chair',
      name: 'Shower Chairs & Benches',
      category: 'bathroom',
      description: 'Seats for safe bathing including transfer benches, rolling shower chairs, and wall-mounted fold-down seats.',
      whoUsesIt: 'People with balance issues, weakness, or paralysis who cannot safely stand in the shower.',
      commonBrands: ['Drive Medical', 'Medline', 'Invacare'],
      resources: [
        InstructionalResource(
          title: 'MedlinePlus: Bathroom Safety',
          url: 'https://medlineplus.gov/mobilityaids.html',
          type: ResourceType.article,
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions: 'Rinse after each use. Deep clean weekly with bathroom cleaner. Check for rust or cracks.',
        replacementSchedule: 'Replace when worn, rusted, or no longer stable (typically 3-5 years)',
      ),
      whereToObtain: const [
        ObtainmentOption(source: 'DME Supplier', details: 'With prescription'),
        ObtainmentOption(source: 'Pharmacy/Medical Supply Store', details: 'Available without prescription'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage: 'Often covered with prescription and documented medical necessity.',
        tips: 'Measure bathroom dimensions before ordering. Consider weight capacity and transfer method.',
      ),
      iconEmoji: '🛁',
    ),

    // ========== PRESSURE RELIEF ==========
    MedicalSupply(
      id: 'wheelchair-cushion',
      name: 'Wheelchair Cushions',
      category: 'pressure',
      description:
          'Specialized cushions that distribute pressure and prevent skin breakdown. Types include foam, gel, air, and hybrid cushions.',
      whoUsesIt: 'Full-time wheelchair users at risk for pressure injuries.',
      commonBrands: ['ROHO', 'Jay', 'Varilite', 'Star'],
      resources: [
        InstructionalResource(
          title: 'MedlinePlus: Pressure Sores Prevention',
          url: 'https://medlineplus.gov/pressuresores.html',
          type: ResourceType.article,
        ),
        InstructionalResource(
          title: 'Craig Hospital: Seating and Positioning',
          url: 'https://craighospital.org/',
          type: ResourceType.article,
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions:
            'Wipe cover weekly. Check air levels in ROHO cushions monthly. Wash covers per manufacturer instructions.',
        replacementSchedule: 'Replace cushion every 1-2 years or when compression-set occurs',
      ),
      troubleshooting: 'Sinking or bottoming out: Cushion needs replacement or re-inflation (air cushions).',
      whereToObtain: const [
        ObtainmentOption(source: 'Seating Clinic', details: 'Requires professional fitting and prescription'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage: 'Medicare covers one cushion every 2-3 years with documented medical necessity.',
        tips: 'Get fitted by seating specialist. Trial cushion before finalizing order if possible.',
      ),
      iconEmoji: '🛏',
    ),

    // ========== DAILY LIVING ==========
    MedicalSupply(
      id: 'adaptive-utensils',
      name: 'Adaptive Eating Utensils',
      category: 'daily',
      description: 'Modified utensils with built-up handles, angled designs, or weighted grips for people with limited hand function.',
      whoUsesIt: 'People with arthritis, weakness, tremor, or limited grip strength.',
      commonBrands: ['Good Grips', 'Sammons Preston', 'North Coast'],
      resources: [
        InstructionalResource(
          title: 'NIH: Daily Living Aids',
          url: 'https://www.nih.gov/',
          type: ResourceType.website,
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions: 'Wash after each use. Most are dishwasher safe.',
        replacementSchedule: 'Replace when worn or damaged',
      ),
      whereToObtain: const [
        ObtainmentOption(source: 'Occupational Therapist', details: 'Can provide samples and prescriptions'),
        ObtainmentOption(source: 'Online Retailers', details: 'Available without prescription'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage: 'Rarely covered by insurance unless prescribed by OT with documented need.',
        tips: 'Trial different styles with OT before purchasing.',
      ),
      iconEmoji: '🧤',
    ),

    // ========== HOME MONITORING ==========
    MedicalSupply(
      id: 'blood-pressure-monitor',
      name: 'Blood Pressure Monitors',
      category: 'monitoring',
      description: 'Automated blood pressure cuffs for home monitoring.',
      whoUsesIt: 'People with hypertension, heart conditions, or requiring regular BP monitoring.',
      commonBrands: ['Omron', 'Welch Allyn', 'A&D Medical'],
      resources: [
        InstructionalResource(
          title: 'MedlinePlus: Blood Pressure',
          url: 'https://medlineplus.gov/',
          type: ResourceType.article,
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions: 'Wipe cuff with damp cloth. Store in case. Calibrate annually if required.',
        replacementSchedule: 'Replace every 3-5 years or per manufacturer recommendation',
      ),
      whereToObtain: const [
        ObtainmentOption(source: 'Pharmacy', details: 'Available without prescription'),
        ObtainmentOption(source: 'Online', details: 'Widely available'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage: 'Some insurance plans cover with prescription and documented medical need.',
        tips: 'Choose upper arm cuff over wrist monitors for accuracy.',
      ),
      iconEmoji: '❤️',
    ),

    // ========== DIABETES ==========
    MedicalSupply(
      id: 'glucose-monitor',
      name: 'Continuous Glucose Monitors',
      category: 'diabetes',
      description: 'Wearable sensors that track blood sugar levels continuously and send readings to a smartphone or receiver.',
      whoUsesIt: 'People with Type 1 or Type 2 diabetes requiring intensive glucose monitoring.',
      commonBrands: ['Dexcom', 'Freestyle Libre', 'Medtronic Guardian'],
      resources: [
        InstructionalResource(
          title: 'NIH: Diabetes Management',
          url: 'https://www.nih.gov/',
          type: ResourceType.website,
        ),
        InstructionalResource(
          title: 'USDA FoodData Central',
          url: 'https://fdc.nal.usda.gov/',
          type: ResourceType.website,
          description: 'Nutrition database for carbohydrate counting and meal planning',
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions: 'Sensor is disposable. Clean skin before application. Keep transmitter clean and dry.',
        replacementSchedule: 'Sensors replaced every 7-14 days depending on brand',
      ),
      whereToObtain: const [
        ObtainmentOption(source: 'Pharmacy', details: 'With prescription'),
        ObtainmentOption(source: 'DME Supplier', details: 'Monthly deliveries'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage:
            'Medicare covers for Type 1 diabetes and some Type 2 patients. Private insurance often requires prior authorization.',
        tips: 'Check with manufacturer for free trial sensors. Some offer patient assistance programs.',
      ),
      iconEmoji: '💉',
    ),

    // ========== RESPIRATORY ==========
    MedicalSupply(
      id: 'cpap-machine',
      name: 'CPAP/BiPAP Machines',
      category: 'respiratory',
      description: 'Positive airway pressure devices that keep airways open during sleep for people with sleep apnea.',
      whoUsesIt: 'People diagnosed with obstructive sleep apnea via sleep study.',
      commonBrands: ['ResMed', 'Philips Respironics', 'Fisher & Paykel'],
      resources: [
        InstructionalResource(
          title: 'NIH: Sleep Apnea',
          url: 'https://www.nih.gov/',
          type: ResourceType.website,
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions:
            'Wash mask daily with mild soap. Clean water chamber weekly. Replace filter monthly. Disinfect tubing weekly.',
        replacementSchedule: 'Masks: every 3-6 months; Tubing: every 3 months; Filters: monthly',
      ),
      whereToObtain: const [
        ObtainmentOption(source: 'DME Supplier', details: 'Requires sleep study results and prescription'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage:
            'Medicare and most insurance cover with documented sleep study showing AHI ≥5. Compliance tracking required.',
        tips:
            'Use machine at least 4 hours/night for 70% of nights to maintain coverage. Download usage data for appointments.',
      ),
      iconEmoji: '🫁',
    ),

    // ========== OSTOMY ==========
    MedicalSupply(
      id: 'ostomy-pouches',
      name: 'Ostomy Pouches & Barriers',
      category: 'ostomy',
      description:
          'Collection bags and skin barriers for colostomy, ileostomy, or urostomy. Available in one-piece and two-piece systems.',
      whoUsesIt: 'People who have had ostomy surgery for bowel, bladder, or digestive conditions.',
      commonBrands: ['Hollister', 'ConvaTec', 'Coloplast'],
      resources: [
        InstructionalResource(
          title: 'United Spinal: Ostomy Care',
          url: 'https://unitedspinal.org/',
          type: ResourceType.article,
        ),
        InstructionalResource(
          title: 'MedlinePlus: Colostomy',
          url: 'https://medlineplus.gov/',
          type: ResourceType.article,
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions: 'Empty pouch when 1/3 to 1/2 full. Clean skin around stoma with each change.',
        replacementSchedule: 'One-piece: change every 1-3 days; Two-piece barriers: change every 3-7 days',
      ),
      whereToObtain: const [
        ObtainmentOption(source: 'DME Supplier', details: 'Monthly deliveries with prescription'),
        ObtainmentOption(source: 'Ostomy Nurse', details: 'Can provide samples to find best fit'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage: 'Medicare covers up to 20 pouches/month. Private insurance similar with prior authorization.',
        tips:
            'Work with ostomy nurse to find best system. Request samples before committing to large orders. Measure stoma regularly as size changes.',
      ),
      iconEmoji: '👜',
    ),

    // ========== FEEDING ==========
    MedicalSupply(
      id: 'feeding-tube-supplies',
      name: 'Feeding Tube Supplies',
      category: 'feeding',
      description: 'Enteral nutrition supplies including feeding tubes, extension sets, syringes, and formula.',
      whoUsesIt: 'People who cannot safely swallow or meet nutrition needs orally.',
      commonBrands: ['MIC-KEY', 'AMT', 'Nestle', 'Abbott'],
      resources: [
        InstructionalResource(
          title: 'NIH: Enteral Nutrition',
          url: 'https://www.nih.gov/',
          type: ResourceType.website,
        ),
        InstructionalResource(
          title: 'USDA FoodData Central',
          url: 'https://fdc.nal.usda.gov/',
          type: ResourceType.website,
          description: 'Nutrition information for formula and blended feeds',
        ),
      ],
      maintenance: const MaintenanceInfo(
        cleaningInstructions:
            'Flush tube with water before and after each feeding. Clean extension sets daily. Rotate feeding bag daily.',
        replacementSchedule: 'Feeding bags: daily; Extension sets: weekly; G-tubes: every 3-12 months per type',
      ),
      whereToObtain: const [
        ObtainmentOption(source: 'Home Health', details: 'Initial tube placed by hospital or outpatient procedure'),
        ObtainmentOption(source: 'DME Supplier', details: 'Ongoing supplies delivered monthly'),
      ],
      insuranceInfo: const InsuranceInfo(
        coverage: 'Medicare and insurance cover formula and supplies with prescription and documented medical necessity.',
        tips: 'Keep extra supplies on hand. Many formulas have patient assistance programs.',
      ),
      iconEmoji: '🍽',
    ),
  ];

  List<MedicalSupply> all() => List.unmodifiable(_catalog);

  List<MedicalSupply> byCategory(String categoryId) =>
      _catalog.where((s) => s.category == categoryId).toList();

  MedicalSupply? byId(String id) {
    for (final s in _catalog) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<MedicalSupply> search(String query) {
    if (query.trim().isEmpty) return all();
    return _catalog.where((s) => s.matchesQuery(query)).toList();
  }

  SupplyCategory? getCategoryById(String id) {
    for (final cat in categories) {
      if (cat.id == id) return cat;
    }
    return null;
  }
}
