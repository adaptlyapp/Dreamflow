import 'package:wellspring/models/journey_template.dart';

/// Built-in template library for ARIE to use when generating personalized recovery journeys
class JourneyTemplateLibrary {
  /// Get all milestone templates for a specific domain and phase
  static List<MilestoneTemplate> getTemplatesForDomainPhase(String domainType, String phaseName) {
    return _allTemplates
        .where((t) => t.domainType == domainType && t.phaseName == phaseName)
        .toList();
  }

  /// Get all templates matching patient profile (sorted by relevance)
  static List<MilestoneTemplate> getRelevantTemplates(PatientProfileInput profile) {
    final scored = _allTemplates.map((template) {
      final relevance = template.calculateRelevance(profile.toJson());
      return (template: template, score: relevance);
    }).where((item) => item.score >= 40).toList(); // Only include if relevance >= 40%

    scored.sort((a, b) => b.score.compareTo(a.score)); // Highest score first
    return scored.map((item) => item.template).toList();
  }

  /// All available milestone templates
  static final List<MilestoneTemplate> _allTemplates = [
    // ═══════════════════════════════════════════════════════════════
    // BOWEL & BLADDER DOMAIN
    // ═══════════════════════════════════════════════════════════════
    
    MilestoneTemplate(
      id: 'bowel_bladder_program_hospital',
      domainType: 'bowelBladder',
      phaseName: 'Hospital',
      titleTemplate: 'Establish Bowel & Bladder Management Program',
      descriptionTemplate: 'Learn and establish initial bowel and bladder management routines with clinical support.',
      order: 1,
      priority: 'critical',
      applicableConditions: ['SCI', 'TBI', '*'],
      relevanceCriteria: {'recoveryPhase': 'acute'},
      goalTemplates: [
        GoalTemplate(
          id: 'learn_bowel_program',
          titleTemplate: 'Learn Bowel Program Basics',
          descriptionTemplate: 'Understand timing, techniques, and supplies needed for bowel management.',
          order: 1,
          targetValue: 1,
          unit: 'completion',
          taskTemplates: [
            TaskTemplate(
              id: 'meet_specialist',
              titleTemplate: 'Meet with Bowel/Bladder Specialist',
              descriptionTemplate: 'Initial consultation to learn techniques and establish routine.',
              order: 1,
              estimatedDaysFromStart: 3,
            ),
            TaskTemplate(
              id: 'practice_program',
              titleTemplate: 'Practice Program with Nursing Staff',
              descriptionTemplate: 'Hands-on training with supervision.',
              order: 2,
              estimatedDaysFromStart: 5,
            ),
          ],
        ),
        GoalTemplate(
          id: 'establish_bladder_routine',
          titleTemplate: 'Establish Bladder Management Routine',
          descriptionTemplate: 'Learn catheterization or other management techniques.',
          order: 2,
          targetValue: 1,
          unit: 'completion',
          taskTemplates: [
            TaskTemplate(
              id: 'learn_cath',
              titleTemplate: 'Learn Catheterization Technique',
              order: 1,
              estimatedDaysFromStart: 2,
            ),
            TaskTemplate(
              id: 'order_supplies',
              titleTemplate: 'Order Initial Supplies',
              descriptionTemplate: 'Ensure you have catheters, gloves, and other needed items.',
              order: 2,
              estimatedDaysFromStart: 7,
            ),
          ],
        ),
      ],
      educationContent: '''
# Bowel & Bladder Management

## Why This Matters
After a spinal cord injury, bowel and bladder function changes. Establishing a routine early helps prevent:
- Urinary tract infections (UTIs)
- Constipation or impaction
- Skin breakdown
- Accidents

## What You'll Learn
- Intermittent catheterization technique
- Bowel program timing and positioning
- Recognizing signs of infection
- Supply management
''',
    ),

    MilestoneTemplate(
      id: 'bowel_bladder_independence_postdischarge',
      domainType: 'bowelBladder',
      phaseName: 'Post-Discharge',
      titleTemplate: 'Achieve Independence in Bowel & Bladder Management',
      descriptionTemplate: 'Perform bowel and bladder care independently or with minimal assistance.',
      order: 1,
      priority: 'high',
      applicableConditions: ['SCI', '*'],
      relevanceCriteria: {'recoveryPhase': 'postDischarge'},
      goalTemplates: [
        GoalTemplate(
          id: 'independent_cath',
          titleTemplate: 'Perform Independent Catheterization',
          descriptionTemplate: 'Catheterize yourself on schedule without assistance.',
          order: 1,
          targetValue: 21,
          unit: 'days',
          taskTemplates: [
            TaskTemplate(
              id: 'practice_daily',
              titleTemplate: 'Practice Daily Catheterization',
              order: 1,
              estimatedDaysFromStart: 1,
            ),
            TaskTemplate(
              id: 'track_schedule',
              titleTemplate: 'Track Catheterization Schedule',
              descriptionTemplate: 'Log times and any issues.',
              order: 2,
              estimatedDaysFromStart: 1,
            ),
          ],
        ),
        GoalTemplate(
          id: 'bowel_program_consistency',
          titleTemplate: 'Maintain Consistent Bowel Program',
          descriptionTemplate: 'Complete bowel program on schedule without accidents.',
          order: 2,
          targetValue: 14,
          unit: 'days',
          taskTemplates: [
            TaskTemplate(
              id: 'same_time_daily',
              titleTemplate: 'Perform at Same Time Daily',
              order: 1,
              estimatedDaysFromStart: 1,
            ),
            TaskTemplate(
              id: 'adjust_diet',
              titleTemplate: 'Adjust Diet for Regularity',
              descriptionTemplate: 'Increase fiber and fluids as needed.',
              order: 2,
              estimatedDaysFromStart: 3,
            ),
          ],
        ),
      ],
      educationContent: '''
# Achieving Independence

## Building Confidence
Independence comes with practice. It's normal to need time to develop a routine that works for you.

## Common Challenges
- Timing adjustments
- Managing supplies while traveling
- Recognizing early signs of UTI or constipation

## When to Seek Help
Contact your healthcare provider if you experience:
- Fever or chills
- Blood in urine
- Abdominal pain or distension
- Missed bowel movement for 3+ days
''',
    ),

    // ═══════════════════════════════════════════════════════════════
    // MOBILITY DOMAIN
    // ═══════════════════════════════════════════════════════════════

    MilestoneTemplate(
      id: 'mobility_equipment_hospital',
      domainType: 'mobility',
      phaseName: 'Hospital',
      titleTemplate: 'Get Fitted for Mobility Equipment',
      descriptionTemplate: 'Work with PT/OT to determine and order appropriate wheelchair or assistive devices.',
      order: 1,
      priority: 'critical',
      applicableConditions: ['SCI', '*'],
      goalTemplates: [
        GoalTemplate(
          id: 'wheelchair_evaluation',
          titleTemplate: 'Complete Wheelchair Evaluation',
          order: 1,
          targetValue: 1,
          unit: 'completion',
          taskTemplates: [
            TaskTemplate(
              id: 'meet_therapist',
              titleTemplate: 'Meet with PT/OT for Assessment',
              order: 1,
              estimatedDaysFromStart: 7,
            ),
            TaskTemplate(
              id: 'insurance_approval',
              titleTemplate: 'Submit Insurance Authorization',
              order: 2,
              estimatedDaysFromStart: 14,
            ),
          ],
        ),
      ],
      educationContent: '''
# Mobility Equipment Fitting

## Why Proper Fit Matters
A properly fitted wheelchair prevents pressure injuries, reduces pain, and maximizes independence.

## The Evaluation Process
- Measurements and positioning assessment
- Discussing your daily activities and goals
- Selecting cushion and back support
- Power vs manual options
''',
    ),

    MilestoneTemplate(
      id: 'mobility_transfers_postdischarge',
      domainType: 'mobility',
      phaseName: 'Post-Discharge',
      titleTemplate: 'Master Independent Transfers',
      descriptionTemplate: 'Perform transfers (bed, chair, car, toilet) safely and independently.',
      order: 1,
      priority: 'high',
      applicableConditions: ['SCI', '*'],
      goalTemplates: [
        GoalTemplate(
          id: 'bed_transfers',
          titleTemplate: 'Complete Bed Transfers Independently',
          order: 1,
          targetValue: 21,
          unit: 'days',
        ),
        GoalTemplate(
          id: 'car_transfers',
          titleTemplate: 'Complete Car Transfers Independently',
          order: 2,
          targetValue: 10,
          unit: 'times',
        ),
      ],
    ),

    // ═══════════════════════════════════════════════════════════════
    // SKIN INTEGRITY DOMAIN
    // ═══════════════════════════════════════════════════════════════

    MilestoneTemplate(
      id: 'skin_education_hospital',
      domainType: 'skinIntegrity',
      phaseName: 'Hospital',
      titleTemplate: 'Learn Skin Care & Pressure Relief',
      descriptionTemplate: 'Understand pressure injury prevention and daily skin checks.',
      order: 1,
      priority: 'critical',
      applicableConditions: ['SCI', '*'],
      goalTemplates: [
        GoalTemplate(
          id: 'learn_pressure_relief',
          titleTemplate: 'Learn Pressure Relief Techniques',
          descriptionTemplate: 'Weight shifts, repositioning, and frequency.',
          order: 1,
          targetValue: 1,
          unit: 'completion',
          taskTemplates: [
            TaskTemplate(
              id: 'attend_education',
              titleTemplate: 'Attend Skin Care Education Session',
              order: 1,
              estimatedDaysFromStart: 5,
            ),
            TaskTemplate(
              id: 'practice_weight_shifts',
              titleTemplate: 'Practice Weight Shifts Every 30 Minutes',
              order: 2,
              estimatedDaysFromStart: 6,
            ),
          ],
        ),
        GoalTemplate(
          id: 'daily_skin_checks',
          titleTemplate: 'Perform Daily Skin Checks',
          descriptionTemplate: 'Use mirror to inspect all pressure points.',
          order: 2,
          targetValue: 7,
          unit: 'days',
        ),
      ],
      educationContent: '''
# Skin Integrity: Your First Priority

## Why Skin Care Is Critical
Pressure injuries (bed sores) can develop quickly and take months to heal. Prevention is essential.

## High-Risk Areas
- Tailbone (sacrum)
- Sitting bones (ischial tuberosities)
- Heels
- Elbows

## Daily Routine
1. Check skin morning and night
2. Shift weight every 15-30 minutes when seated
3. Turn in bed every 2-4 hours
4. Keep skin clean and dry
''',
    ),

    MilestoneTemplate(
      id: 'skin_prevention_routine_postdischarge',
      domainType: 'skinIntegrity',
      phaseName: 'Post-Discharge',
      titleTemplate: 'Establish Consistent Skin Prevention Routine',
      descriptionTemplate: 'Maintain daily skin checks and pressure relief without reminders.',
      order: 1,
      priority: 'high',
      applicableConditions: ['SCI', '*'],
      goalTemplates: [
        GoalTemplate(
          id: 'independent_checks',
          titleTemplate: 'Complete Independent Skin Checks Daily',
          order: 1,
          targetValue: 30,
          unit: 'days',
        ),
        GoalTemplate(
          id: 'pressure_relief_habit',
          titleTemplate: 'Perform Pressure Reliefs on Schedule',
          descriptionTemplate: 'Weight shifts every 30 min while seated.',
          order: 2,
          targetValue: 30,
          unit: 'days',
        ),
      ],
    ),

    // ═══════════════════════════════════════════════════════════════
    // SELF-CARE DOMAIN
    // ═══════════════════════════════════════════════════════════════

    MilestoneTemplate(
      id: 'selfcare_adl_training_hospital',
      domainType: 'selfCare',
      phaseName: 'Hospital',
      titleTemplate: 'Begin ADL Training',
      descriptionTemplate: 'Learn adaptive techniques for dressing, grooming, and bathing.',
      order: 1,
      priority: 'high',
      applicableConditions: ['SCI', '*'],
      goalTemplates: [
        GoalTemplate(
          id: 'learn_dressing',
          titleTemplate: 'Learn Adaptive Dressing Techniques',
          order: 1,
          targetValue: 1,
          unit: 'completion',
        ),
        GoalTemplate(
          id: 'learn_bathing',
          titleTemplate: 'Learn Safe Bathing Methods',
          order: 2,
          targetValue: 1,
          unit: 'completion',
        ),
      ],
      educationContent: '''
# Activities of Daily Living (ADL)

## Adaptive Techniques
You'll learn new ways to accomplish daily tasks using:
- Adaptive equipment (reachers, dressing sticks, etc.)
- Modified techniques
- Energy conservation strategies

## Common Adaptive Equipment
- Long-handled sponge
- Sock aid
- Button hook
- Reacher/grabber
''',
    ),

    MilestoneTemplate(
      id: 'selfcare_independence_postdischarge',
      domainType: 'selfCare',
      phaseName: 'Post-Discharge',
      titleTemplate: 'Achieve ADL Independence',
      descriptionTemplate: 'Complete grooming, dressing, and bathing independently or with minimal assistance.',
      order: 1,
      priority: 'medium',
      applicableConditions: ['SCI', '*'],
      goalTemplates: [
        GoalTemplate(
          id: 'independent_dressing',
          titleTemplate: 'Dress Independently',
          order: 1,
          targetValue: 14,
          unit: 'days',
        ),
        GoalTemplate(
          id: 'independent_bathing',
          titleTemplate: 'Complete Bathing Routine Independently',
          order: 2,
          targetValue: 14,
          unit: 'days',
        ),
      ],
    ),

    // ═══════════════════════════════════════════════════════════════
    // MENTAL HEALTH DOMAIN (Universal)
    // ═══════════════════════════════════════════════════════════════

    MilestoneTemplate(
      id: 'mental_health_adjustment_postdischarge',
      domainType: 'mental',
      phaseName: 'Post-Discharge',
      titleTemplate: 'Build Emotional Support System',
      descriptionTemplate: 'Connect with mental health resources and peer support.',
      order: 1,
      priority: 'high',
      applicableConditions: ['*'], // Universal
      goalTemplates: [
        GoalTemplate(
          id: 'connect_therapist',
          titleTemplate: 'Connect with Therapist or Counselor',
          order: 1,
          targetValue: 1,
          unit: 'completion',
          taskTemplates: [
            TaskTemplate(
              id: 'research_providers',
              titleTemplate: 'Research Mental Health Providers',
              order: 1,
              estimatedDaysFromStart: 7,
            ),
            TaskTemplate(
              id: 'schedule_appointment',
              titleTemplate: 'Schedule Initial Appointment',
              order: 2,
              estimatedDaysFromStart: 14,
            ),
          ],
        ),
        GoalTemplate(
          id: 'join_support_group',
          titleTemplate: 'Join Peer Support Group',
          descriptionTemplate: 'Connect with others who understand your experience.',
          order: 2,
          targetValue: 1,
          unit: 'completion',
        ),
      ],
      educationContent: '''
# Mental Health & Adjustment

## It's Normal to Struggle
Adjusting to life after injury is challenging. Many people experience:
- Grief and loss
- Anxiety about the future
- Depression
- Anger or frustration

## Getting Support
You don't have to do this alone. Support is available:
- Individual therapy
- Peer mentorship programs
- Support groups (in-person or online)
- Family counseling

## Crisis Resources
If you're in crisis, reach out:
- National Suicide Prevention Lifeline: 988
- Crisis Text Line: Text HOME to 741741
''',
    ),

    MilestoneTemplate(
      id: 'mental_health_coping_longterm',
      domainType: 'mental',
      phaseName: 'Long-Term',
      titleTemplate: 'Develop Long-Term Coping Strategies',
      descriptionTemplate: 'Build resilience and find meaning in your new chapter.',
      order: 1,
      priority: 'medium',
      applicableConditions: ['*'],
      goalTemplates: [
        GoalTemplate(
          id: 'identify_activities',
          titleTemplate: 'Identify Meaningful Activities',
          descriptionTemplate: 'Find hobbies, work, or volunteer opportunities that bring joy.',
          order: 1,
          targetValue: 3,
          unit: 'activities',
        ),
        GoalTemplate(
          id: 'practice_mindfulness',
          titleTemplate: 'Practice Regular Mindfulness or Meditation',
          order: 2,
          targetValue: 21,
          unit: 'days',
        ),
      ],
    ),

    // ═══════════════════════════════════════════════════════════════
    // NUTRITION DOMAIN (Universal)
    // ═══════════════════════════════════════════════════════════════

    MilestoneTemplate(
      id: 'nutrition_assessment_postdischarge',
      domainType: 'nutrition',
      phaseName: 'Post-Discharge',
      titleTemplate: 'Establish Healthy Nutrition Plan',
      descriptionTemplate: 'Meet with dietitian and create sustainable eating plan.',
      order: 1,
      priority: 'medium',
      applicableConditions: ['*'],
      goalTemplates: [
        GoalTemplate(
          id: 'dietitian_consult',
          titleTemplate: 'Consult with Registered Dietitian',
          order: 1,
          targetValue: 1,
          unit: 'completion',
        ),
        GoalTemplate(
          id: 'meal_planning',
          titleTemplate: 'Plan and Prepare Balanced Meals',
          descriptionTemplate: 'Ensure adequate protein, fiber, and hydration.',
          order: 2,
          targetValue: 14,
          unit: 'days',
        ),
      ],
      educationContent: '''
# Nutrition for Recovery

## Why Nutrition Matters
Proper nutrition supports:
- Wound healing
- Bowel regularity
- Bladder health
- Energy levels
- Weight management

## Key Focus Areas
- **Protein:** For healing and maintaining muscle mass
- **Fiber:** For bowel health (25-35g daily)
- **Fluids:** 2-3 liters daily (unless restricted)
- **Calcium & Vitamin D:** For bone health

## Common Challenges
- Reduced appetite
- Swallowing difficulties
- Limited mobility affecting meal prep
- Bowel program timing around meals
''',
    ),

    // ═══════════════════════════════════════════════════════════════
    // EQUIPMENT DOMAIN
    // ═══════════════════════════════════════════════════════════════

    MilestoneTemplate(
      id: 'equipment_home_setup_postdischarge',
      domainType: 'equipment',
      phaseName: 'Post-Discharge',
      titleTemplate: 'Set Up Home Medical Equipment',
      descriptionTemplate: 'Ensure all needed equipment is ordered, delivered, and functional.',
      order: 1,
      priority: 'critical',
      applicableConditions: ['*'],
      goalTemplates: [
        GoalTemplate(
          id: 'inventory_equipment',
          titleTemplate: 'Create Equipment Inventory',
          descriptionTemplate: 'List all prescribed equipment and verify delivery.',
          order: 1,
          targetValue: 1,
          unit: 'completion',
          taskTemplates: [
            TaskTemplate(
              id: 'list_prescribed',
              titleTemplate: 'List All Prescribed Equipment',
              order: 1,
              estimatedDaysFromStart: 1,
            ),
            TaskTemplate(
              id: 'confirm_orders',
              titleTemplate: 'Confirm All Orders Placed',
              order: 2,
              estimatedDaysFromStart: 3,
            ),
            TaskTemplate(
              id: 'verify_delivery',
              titleTemplate: 'Verify Delivery Before Discharge',
              order: 3,
              estimatedDaysFromStart: 5,
            ),
          ],
        ),
        GoalTemplate(
          id: 'learn_maintenance',
          titleTemplate: 'Learn Equipment Maintenance',
          descriptionTemplate: 'Understand cleaning, charging, and troubleshooting.',
          order: 2,
          targetValue: 1,
          unit: 'completion',
        ),
      ],
    ),

    // ═══════════════════════════════════════════════════════════════
    // HOME MODIFICATION DOMAIN
    // ═══════════════════════════════════════════════════════════════

    MilestoneTemplate(
      id: 'home_mod_assessment_postdischarge',
      domainType: 'homeModification',
      phaseName: 'Post-Discharge',
      titleTemplate: 'Complete Home Accessibility Assessment',
      descriptionTemplate: 'Identify and address barriers to safe mobility at home.',
      order: 1,
      priority: 'high',
      applicableConditions: ['SCI', '*'],
      goalTemplates: [
        GoalTemplate(
          id: 'home_visit',
          titleTemplate: 'Schedule OT Home Visit',
          descriptionTemplate: 'Have therapist assess your home for modifications.',
          order: 1,
          targetValue: 1,
          unit: 'completion',
        ),
        GoalTemplate(
          id: 'complete_mods',
          titleTemplate: 'Complete Priority Modifications',
          descriptionTemplate: 'Install ramps, grab bars, and other essential changes.',
          order: 2,
          targetValue: 1,
          unit: 'completion',
          taskTemplates: [
            TaskTemplate(
              id: 'prioritize_list',
              titleTemplate: 'Prioritize Modification List',
              order: 1,
              estimatedDaysFromStart: 7,
            ),
            TaskTemplate(
              id: 'hire_contractor',
              titleTemplate: 'Hire Contractor or Request Assistance',
              order: 2,
              estimatedDaysFromStart: 14,
            ),
            TaskTemplate(
              id: 'install_mods',
              titleTemplate: 'Complete Installation',
              order: 3,
              estimatedDaysFromStart: 30,
            ),
          ],
        ),
      ],
      educationContent: '''
# Home Modifications

## Common Modifications
- **Ramps:** For entry/exit
- **Widened Doorways:** 36" minimum for wheelchairs
- **Grab Bars:** Bathroom and bedroom
- **Roll-in Shower:** Or transfer bench
- **Lowered Counters:** Kitchen and bathroom

## Funding Sources
- Insurance (varies by plan)
- Veterans benefits (if applicable)
- State vocational rehabilitation
- Non-profit assistance programs
- Home equity loans or grants

## Prioritization
Focus first on:
1. Safe entry/exit
2. Accessible bathroom
3. Bedroom accessibility
''',
    ),

    // ═══════════════════════════════════════════════════════════════
    // ADVOCACY DOMAIN (Universal - Outpatient Phase)
    // ═══════════════════════════════════════════════════════════════

    MilestoneTemplate(
      id: 'advocacy_benefits_outpatient',
      domainType: 'advocacy',
      phaseName: 'Outpatient',
      titleTemplate: 'Apply for Disability Benefits',
      descriptionTemplate: 'Navigate SSDI/SSI application process and secure financial support.',
      order: 1,
      priority: 'high',
      applicableConditions: ['*'],
      goalTemplates: [
        GoalTemplate(
          id: 'research_benefits',
          titleTemplate: 'Research Available Benefits',
          descriptionTemplate: 'SSDI, SSI, state programs, veterans benefits.',
          order: 1,
          targetValue: 1,
          unit: 'completion',
        ),
        GoalTemplate(
          id: 'submit_application',
          titleTemplate: 'Submit Disability Application',
          order: 2,
          targetValue: 1,
          unit: 'completion',
          taskTemplates: [
            TaskTemplate(
              id: 'gather_documents',
              titleTemplate: 'Gather Medical Documentation',
              order: 1,
              estimatedDaysFromStart: 7,
            ),
            TaskTemplate(
              id: 'complete_forms',
              titleTemplate: 'Complete Application Forms',
              order: 2,
              estimatedDaysFromStart: 14,
            ),
            TaskTemplate(
              id: 'submit',
              titleTemplate: 'Submit Application',
              order: 3,
              estimatedDaysFromStart: 21,
            ),
          ],
        ),
      ],
      educationContent: '''
# Navigating Disability Benefits

## Types of Benefits
- **SSDI:** Social Security Disability Insurance (work history required)
- **SSI:** Supplemental Security Income (need-based)
- **State Programs:** Medicaid, state disability
- **Veterans Benefits:** If service-related

## Application Tips
- Apply as soon as possible (processing takes months)
- Keep copies of all medical records
- Consider working with an advocate or attorney
- Be prepared for potential denial and appeal

## Resources
- Local disability advocacy organizations
- Social workers
- Benefits counseling services
''',
    ),
  ];

  /// Get phase names for a given recovery phase
  static List<String> getPhaseNamesForRecoveryPhase(String recoveryPhase) {
    switch (recoveryPhase.toLowerCase().replaceAll('-', '').replaceAll(' ', '')) {
      case 'acute':
        return ['Hospital'];
      case 'postdischarge':
        return ['Post-Discharge'];
      case 'outpatient':
        return ['Outpatient'];
      case 'longterm':
        return ['Long-Term'];
      default:
        return ['Post-Discharge']; // Default
    }
  }
}
