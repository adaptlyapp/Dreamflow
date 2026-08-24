import 'package:flutter/material.dart';
import 'package:wellspring/screens/recovery/care_team_schedule_screen.dart';

/// Family view: show the patient's Care Team Schedule exactly like the patient sees it
class FamilyDailyCareTimelineScreen extends StatelessWidget {
  final String? patientId;
  const FamilyDailyCareTimelineScreen({super.key, this.patientId});

  @override
  Widget build(BuildContext context) {
    // Simply render the patient's CareTeamScheduleScreen
    // The screen already handles loading patient data and rendering all sections:
    // - Today's Schedule Summary with medications and routines
    // - Medications section (collapsible)
    // - Daily Care Timeline section (collapsible)
    // - Care Team section with team members
    // - Weekly Schedule calendar
    // - Week calendar grid with time slots
    return CareTeamScheduleScreen(patientId: patientId);
  }
}
