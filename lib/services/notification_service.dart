import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:wellspring/models/medication.dart';
import 'package:wellspring/models/goal.dart';
import 'package:wellspring/models/milestone.dart';

/// Top-level callback for handling notification action taps in the background.
/// Must be a top-level or static function (annotated with @pragma).
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint(
      'NotificationService: background tap actionId=${response.actionId} payload=${response.payload}');
}

/// Local notification service using `flutter_local_notifications`.
///
/// Works on Android, iOS, and macOS. On web/other platforms it gracefully
/// degrades to no-ops (the plugin returns null for platform implementations).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String medicationChannelId = 'med_reminders';
  static const String goalChannelId = 'goal_reminders';
  static const String milestoneChannelId = 'milestone_reminders';
  static const String generalChannelId = 'general_reminders';
  static const String socialChannelId = 'social_notifications';
  static const String achievementChannelId = 'achievements';
  static const String familyChannelId = 'family_alerts';
  static const String engagementChannelId = 'daily_engagement';

  // iOS notification categories (for action buttons)
  static const String medicationCategoryId = 'MEDICATION_CATEGORY';

  // Action IDs
  static const String actionTaken = 'ACTION_MED_TAKEN';
  static const String actionSnooze = 'ACTION_MED_SNOOZE';

  // Stable ID ranges per kind so we can cancel them independently.
  static const int _medBase = 100000;
  static const int _goalBase = 200000;
  static const int _milestoneBase = 300000;
  static const int _socialBase = 400000;
  static const int _achievementBase = 500000;
  static const int _familyBase = 600000;
  static const int _engagementBase = 700000;

  /// Callback invoked when user taps a notification or its action button.
  /// Assign from main.dart / router to navigate accordingly.
  void Function(NotificationResponse response)? onNotificationTap;

  Future<void> init() async {
    if (_initialized) return;
    debugPrint('NotificationService: Starting initialization...');
    try {
      tzdata.initializeTimeZones();
      await _resolveLocalTimezone();
    } catch (e) {
      debugPrint('NotificationService: timezone init failed: $e');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Define iOS action buttons + category for medication reminders.
    final takenAction = DarwinNotificationAction.plain(
      actionTaken,
      'Taken',
      options: <DarwinNotificationActionOption>{
        DarwinNotificationActionOption.foreground,
      },
    );
    final snoozeAction = DarwinNotificationAction.plain(
      actionSnooze,
      'Snooze 10 min',
    );
    final medCategory = DarwinNotificationCategory(
      medicationCategoryId,
      actions: <DarwinNotificationAction>[takenAction, snoozeAction],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    );

    final darwin = DarwinInitializationSettings(
      // We request explicitly via requestPermission() with critical/time-sensitive too.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      // Show notifications when the app is in the foreground.
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
      notificationCategories: <DarwinNotificationCategory>[medCategory],
    );

    final settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      _initialized = true;
      debugPrint('✅ NotificationService: Initialized successfully');
      debugPrint(
          'NOTE: Notifications only work on real iOS/Android devices, not in web preview.');
    } catch (e) {
      debugPrint('❌ NotificationService: init error: $e');
    }
  }

  Future<void> _resolveLocalTimezone() async {
    // 1. Preferred: use flutter_timezone to get the IANA identifier.
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final String localName = info.identifier;
      if (localName.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(localName));
        debugPrint('NotificationService: Timezone set to $localName');
        return;
      }
    } catch (e) {
      debugPrint(
          'NotificationService: flutter_timezone lookup failed: $e — falling back to device offset.');
    }
    // 2. Fallback: use device UTC offset to pick a matching Etc/GMT zone.
    // This is not a real-world zone name but it guarantees wall-clock math
    // matches the device, which is what users actually care about.
    try {
      final offset = DateTime.now().timeZoneOffset;
      final totalMinutes = offset.inMinutes;
      final hours = totalMinutes ~/ 60;
      // Etc/GMT zones have INVERTED signs (Etc/GMT-5 == UTC+5).
      final sign = hours >= 0 ? '-' : '+';
      final absHours = hours.abs();
      final name = 'Etc/GMT$sign$absHours';
      try {
        tz.setLocalLocation(tz.getLocation(name));
        debugPrint(
            'NotificationService: Timezone fallback set to $name (device offset ${offset.inHours}h)');
      } catch (_) {
        // Last resort: leave tz.local as-is (UTC) but log clearly.
        debugPrint(
            'NotificationService: WARNING — could not set local timezone. Device offset=${offset.inHours}h. Schedules will use absolute DateTime.now() math to compensate.');
      }
    } catch (e) {
      debugPrint('NotificationService: offset fallback failed: $e');
    }
  }

  /// Builds a TZDateTime for [hour]:[minute] today (or tomorrow if already
  /// passed) based on the DEVICE's actual local wall clock — NOT `tz.local`.
  ///
  /// This is defensive: even if `tz.local` was not correctly resolved and is
  /// still UTC, the absolute instant we schedule will match the user's real
  /// wall-clock time on the device.
  tz.TZDateTime _nextInstantForTime(int hour, int minute) {
    final now = DateTime.now(); // device local wall time
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    // Convert absolute instant into whatever tz.local is (correct or UTC).
    return tz.TZDateTime.from(target, tz.local);
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    debugPrint(
        'NotificationService: tap actionId=${response.actionId} payload=${response.payload}');
    // Handle snooze inline: re-schedule same notification 10 minutes out.
    if (response.actionId == actionSnooze) {
      _snoozeMedication(response);
    }
    // Delegate other taps to the app-level handler (for navigation).
    try {
      onNotificationTap?.call(response);
    } catch (e) {
      debugPrint('NotificationService.onNotificationTap error: $e');
    }
  }

  Future<void> _snoozeMedication(NotificationResponse response) async {
    try {
      final payload = response.payload;
      String? medName;
      String? dosage;
      if (payload != null && payload.isNotEmpty) {
        // Payload format: med|<id>|<name>|<dosage>
        final parts = payload.split('|');
        if (parts.length >= 3) medName = parts[2];
        if (parts.length >= 4) dosage = parts[3];
      }
      final when = tz.TZDateTime.now(tz.local)
          .add(const Duration(minutes: 10));
      await _zonedSchedule(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
        title: 'Medication reminder',
        body: (dosage == null || dosage.isEmpty)
            ? 'Time to take ${medName ?? 'your medication'}'
            : 'Time to take $medName ($dosage)',
        when: when,
        channelId: medicationChannelId,
        payload: payload,
        useMedicationCategory: true,
      );
      debugPrint('NotificationService: Snoozed medication for 10 minutes');
    } catch (e) {
      debugPrint('NotificationService._snoozeMedication error: $e');
    }
  }

  Future<bool> requestPermission() async {
    await init();
    debugPrint('NotificationService: Requesting permissions...');
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        debugPrint(
            'NotificationService: iOS platform detected, requesting permissions');
        final ok = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          // Allow time-sensitive medication reminders to break through Focus/DND.
          // Requires "Time Sensitive Notifications" capability in Xcode entitlements.
          critical: false,
          provisional: false,
        );
        debugPrint(
            'NotificationService: iOS permission result: ${ok == true ? "GRANTED" : "DENIED"} ');
        return ok ?? false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        debugPrint(
            'NotificationService: Android platform detected, requesting permissions');
        final ok = await android.requestNotificationsPermission();
        debugPrint(
            'NotificationService: Android permission result: ${ok == true ? "GRANTED" : "DENIED"} ');
        try {
          await android.requestExactAlarmsPermission();
        } catch (_) {}
        return ok ?? false;
      }
      debugPrint(
          'NotificationService: No native platform detected (likely web). Notifications will not work.');
    } catch (e) {
      debugPrint('NotificationService.requestPermission error: $e');
    }
    return false;
  }

  NotificationDetails _detailsFor(
    String channelId, {
    bool useMedicationCategory = false,
  }) {
    String name;
    switch (channelId) {
      case medicationChannelId:
        name = 'Medication Reminders';
        break;
      case goalChannelId:
        name = 'Goal Reminders';
        break;
      case milestoneChannelId:
        name = 'Milestone Reminders';
        break;
      case socialChannelId:
        name = 'Social Notifications';
        break;
      case achievementChannelId:
        name = 'Achievements';
        break;
      case familyChannelId:
        name = 'Family Alerts';
        break;
      case engagementChannelId:
        name = 'Daily Reminders';
        break;
      default:
        name = 'Reminders';
    }
    final isMedication = channelId == medicationChannelId;
    final android = AndroidNotificationDetails(
      channelId,
      name,
      channelDescription: name,
      importance: isMedication ? Importance.max : Importance.high,
      priority: isMedication ? Priority.max : Priority.high,
      category:
          isMedication ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
      fullScreenIntent: false,
      playSound: true,
      enableVibration: true,
      actions: isMedication
          ? const <AndroidNotificationAction>[
              AndroidNotificationAction(actionTaken, 'Taken',
                  showsUserInterface: true, cancelNotification: true),
              AndroidNotificationAction(actionSnooze, 'Snooze 10 min',
                  showsUserInterface: false, cancelNotification: true),
            ]
          : null,
    );
    final darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      // Time-sensitive medication alerts bypass Focus/Silent modes on iOS 15+.
      interruptionLevel: isMedication
          ? InterruptionLevel.timeSensitive
          : InterruptionLevel.active,
      categoryIdentifier:
          (isMedication || useMedicationCategory) ? medicationCategoryId : null,
      threadIdentifier: channelId,
    );
    return NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String channelId = generalChannelId,
    String? payload,
  }) async {
    await init();
    debugPrint('🔔 NOTIFICATION: [$channelId] $title - $body');
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _detailsFor(channelId),
        payload: payload,
      );
      debugPrint('✅ Notification sent successfully (id: $id)');
    } catch (e) {
      debugPrint('❌ NotificationService.showNow error: $e');
      debugPrint(
          'NOTE: Local notifications do not work in web preview. Deploy to iOS/Android to test.');
    }
  }

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required String channelId,
    DateTimeComponents? matchComponents,
    String? payload,
    bool useMedicationCategory = false,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails:
            _detailsFor(channelId, useMedicationCategory: useMedicationCategory),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService._zonedSchedule error: $e');
    }
  }

  // -------------------- MEDICATION --------------------

  int _medIdFor(String medId, int timeIndex) =>
      _medBase + (medId.hashCode.abs() % 9000) * 10 + timeIndex;

  Future<void> scheduleMedication(Medication med) async {
    await init();
    await cancelMedication(med.id);
    debugPrint(
        'NotificationService.scheduleMedication: ${med.name} times=${med.times}');
    for (var i = 0; i < med.times.length; i++) {
      final t = med.times[i];
      final parts = t.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final when = _nextInstantForTime(hour, minute);
      debugPrint(
          'NotificationService.scheduleMedication: ${med.name} @ ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} device-local -> scheduled TZ instant=$when (tz.local=${tz.local.name})');
      final payload =
          'med|${med.id}|${med.name}|${med.dosage ?? ''}';
      await _zonedSchedule(
        id: _medIdFor(med.id, i),
        title: '💊 Time for ${med.name}',
        body: med.dosage == null || med.dosage!.isEmpty
            ? 'Tap to log this dose'
            : 'Take ${med.dosage} — tap to log this dose',
        when: when,
        channelId: medicationChannelId,
        matchComponents: DateTimeComponents.time,
        payload: payload,
      );
    }
  }

  Future<void> cancelMedication(String medId) async {
    await init();
    for (var i = 0; i < 24; i++) {
      try {
        await _plugin.cancel(id: _medIdFor(medId, i));
      } catch (_) {}
    }
  }

  Future<void> syncMedications(List<Medication> meds) async {
    await init();
    for (final m in meds) {
      await scheduleMedication(m);
    }
  }

  // -------------------- DAILY ENGAGEMENT (PUSH-BACK-TO-APP) --------------------

  /// Schedules recurring daily local reminders to bring the user back to the app.
  /// Times default to a morning check-in (9:00) and an evening log reminder (20:00).
  Future<void> scheduleDailyEngagementReminders({
    List<({int hour, int minute, String title, String body})>? slots,
  }) async {
    await init();
    final slotsToUse = slots ??
        <({int hour, int minute, String title, String body})>[
          (
            hour: 9,
            minute: 0,
            title: 'Good morning 👋',
            body: 'Check in with Adaptly — log your meds, mood, and start your day.',
          ),
          (
            hour: 20,
            minute: 0,
            title: 'Evening check-in',
            body: 'How did today go? Take a moment to log your progress in Adaptly.',
          ),
        ];

    // Cancel any prior engagement reminders (up to 10 slots).
    for (var i = 0; i < 10; i++) {
      try {
        await _plugin.cancel(id: _engagementBase + i);
      } catch (_) {}
    }

    for (var i = 0; i < slotsToUse.length; i++) {
      final s = slotsToUse[i];
      final when = _nextInstantForTime(s.hour, s.minute);
      await _zonedSchedule(
        id: _engagementBase + i,
        title: s.title,
        body: s.body,
        when: when,
        channelId: engagementChannelId,
        matchComponents: DateTimeComponents.time,
        payload: 'engagement|open_home',
      );
    }
    debugPrint(
        'NotificationService: Scheduled ${slotsToUse.length} daily engagement reminders');
  }

  Future<void> cancelDailyEngagementReminders() async {
    await init();
    for (var i = 0; i < 10; i++) {
      try {
        await _plugin.cancel(id: _engagementBase + i);
      } catch (_) {}
    }
  }

  // -------------------- GOAL --------------------

  int _goalIdFor(String goalId) =>
      _goalBase + (goalId.hashCode.abs() % 90000);

  Future<void> scheduleGoal(Goal goal) async {
    await init();
    if (!goal.active) {
      await cancelGoal(goal.id);
      return;
    }
    // Daily 9am nudge for active goals.
    final when = _nextInstantForTime(9, 0);
    await _zonedSchedule(
      id: _goalIdFor(goal.id),
      title: 'Goal reminder',
      body: goal.title,
      when: when,
      channelId: goalChannelId,
      matchComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelGoal(String goalId) async {
    await init();
    try {
      await _plugin.cancel(id: _goalIdFor(goalId));
    } catch (_) {}
  }

  // -------------------- MILESTONE --------------------

  int _milestoneIdFor(String milestoneId) =>
      _milestoneBase + (milestoneId.hashCode.abs() % 90000);

  Future<void> scheduleMilestone(Milestone m) async {
    await init();
    if (m.completed || m.dueDate == null) {
      await cancelMilestone(m.id);
      return;
    }
    final due = m.dueDate!;
    final dayBefore = DateTime(due.year, due.month, due.day)
        .subtract(const Duration(days: 1))
        .add(const Duration(hours: 9));
    final notifyAt = DateTime.now().isBefore(dayBefore) ? dayBefore : due;
    final when = tz.TZDateTime.from(notifyAt, tz.local);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }
    await _zonedSchedule(
      id: _milestoneIdFor(m.id),
      title: 'Milestone due soon',
      body: m.title,
      when: when,
      channelId: milestoneChannelId,
    );
  }

  Future<void> cancelMilestone(String milestoneId) async {
    await init();
    try {
      await _plugin.cancel(id: _milestoneIdFor(milestoneId));
    } catch (_) {}
  }

  Future<void> syncMilestones(List<Milestone> milestones) async {
    await init();
    for (final m in milestones) {
      await scheduleMilestone(m);
    }
  }

  // -------------------- SOCIAL NOTIFICATIONS --------------------

  int _socialIdFor(String entityId, String type) =>
      _socialBase + ((entityId + type).hashCode.abs() % 90000);

  /// Notify user about a new message
  Future<void> notifyNewMessage({
    required String senderName,
    required String messagePreview,
    String? senderId,
  }) async {
    await init();
    final id = _socialIdFor(senderId ?? DateTime.now().toString(), 'message');
    await showNow(
      id: id,
      title: 'New message from $senderName',
      body: messagePreview,
      channelId: socialChannelId,
    );
  }

  /// Notify user about a like on their post
  Future<void> notifyPostLiked({
    required String likerName,
    required String postTitle,
    required String postId,
  }) async {
    await init();
    final id = _socialIdFor(postId, 'like');
    await showNow(
      id: id,
      title: '$likerName liked your post',
      body: postTitle,
      channelId: socialChannelId,
    );
  }

  /// Notify user about a comment on their post
  Future<void> notifyPostCommented({
    required String commenterName,
    required String postTitle,
    required String commentPreview,
    required String postId,
  }) async {
    await init();
    final id = _socialIdFor(postId + commentPreview, 'comment');
    await showNow(
      id: id,
      title: '$commenterName commented on your post',
      body: commentPreview,
      channelId: socialChannelId,
    );
  }

  // -------------------- ACHIEVEMENT NOTIFICATIONS --------------------

  int _achievementIdFor(String achievementId) =>
      _achievementBase + (achievementId.hashCode.abs() % 90000);

  /// Notify user about unlocking an achievement
  Future<void> notifyAchievementUnlocked({
    required String title,
    required String description,
  }) async {
    await init();
    final id = _achievementIdFor(title + DateTime.now().toString());
    await showNow(
      id: id,
      title: '🏆 Achievement Unlocked!',
      body: '$title - $description',
      channelId: achievementChannelId,
    );
  }

  // -------------------- FAMILY NOTIFICATIONS --------------------

  int _familyIdFor(String patientId, String alertType) =>
      _familyBase + ((patientId + alertType).hashCode.abs() % 90000);

  /// Notify family member about high pain levels
  Future<void> notifyFamilyHighPain({
    required String patientName,
    required int painLevel,
    required String patientId,
  }) async {
    await init();
    final id = _familyIdFor(patientId, 'high_pain');
    await showNow(
      id: id,
      title: 'Health Alert: $patientName',
      body: 'Pain level is $painLevel/10. Consider checking in.',
      channelId: familyChannelId,
    );
  }

  /// Notify family member about missed health logs
  Future<void> notifyFamilyMissedLogs({
    required String patientName,
    required int daysMissed,
    required String patientId,
  }) async {
    await init();
    final id = _familyIdFor(patientId, 'missed_logs');
    await showNow(
      id: id,
      title: 'Health Log Alert: $patientName',
      body: 'No health entries for $daysMissed days',
      channelId: familyChannelId,
    );
  }

  /// Notify family member about milestone completion
  Future<void> notifyFamilyMilestoneCompleted({
    required String patientName,
    required String milestoneTitle,
    required String patientId,
  }) async {
    await init();
    final id = _familyIdFor(patientId + milestoneTitle, 'milestone');
    await showNow(
      id: id,
      title: '🎉 $patientName completed a milestone!',
      body: milestoneTitle,
      channelId: familyChannelId,
    );
  }

  /// Notify family member about infection risk
  Future<void> notifyFamilyInfectionRisk({
    required String patientName,
    required String symptomDescription,
    required String patientId,
  }) async {
    await init();
    final id = _familyIdFor(patientId, 'infection_risk');
    await showNow(
      id: id,
      title: '⚠️ Infection Risk: $patientName',
      body: symptomDescription,
      channelId: familyChannelId,
    );
  }

  // -------------------- COMMUNITY NOTIFICATIONS --------------------

  /// Notify user about new post in their community
  Future<void> notifyCommunityNewPost({
    required String communityName,
    required String authorName,
    required String postTitle,
    required String communityId,
  }) async {
    await init();
    final id = _socialIdFor(communityId + postTitle, 'community_post');
    await showNow(
      id: id,
      title: 'New post in $communityName',
      body: '$authorName: $postTitle',
      channelId: socialChannelId,
    );
  }

  // -------------------- RESOURCE NOTIFICATIONS --------------------

  /// Notify user when their resource suggestion is approved
  Future<void> notifyResourceApproved({
    required String resourceTitle,
    required String resourceId,
  }) async {
    await init();
    final id = _socialIdFor(resourceId, 'resource_approved');
    await showNow(
      id: id,
      title: '✅ Resource Approved',
      body: 'Your suggestion "$resourceTitle" has been approved!',
      channelId: generalChannelId,
    );
  }

  /// Notify user when their resource suggestion needs revision
  Future<void> notifyResourceNeedsRevision({
    required String resourceTitle,
    required String feedback,
    required String resourceId,
  }) async {
    await init();
    final id = _socialIdFor(resourceId, 'resource_revision');
    await showNow(
      id: id,
      title: 'Resource Needs Revision',
      body: '"$resourceTitle" - $feedback',
      channelId: generalChannelId,
    );
  }
}
