import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:wellspring/models/medication.dart';
import 'package:wellspring/models/goal.dart';
import 'package:wellspring/models/milestone.dart';

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

  // Stable ID ranges per kind so we can cancel them independently.
  static const int _medBase = 100000;
  static const int _goalBase = 200000;
  static const int _milestoneBase = 300000;
  static const int _socialBase = 400000;
  static const int _achievementBase = 500000;
  static const int _familyBase = 600000;

  Future<void> init() async {
    if (_initialized) return;
    debugPrint('NotificationService: Starting initialization...');
    try {
      tzdata.initializeTimeZones();
      // We don't have flutter_native_timezone; assume device local.
      // tz.local is set from system; if unset, default to UTC.
      // ignore: unnecessary_statements
      tz.local;
      debugPrint('NotificationService: Timezone initialized');
    } catch (e) {
      debugPrint('NotificationService: timezone init failed: $e');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    try {
      await _plugin.initialize(settings: settings);
      _initialized = true;
      debugPrint('✅ NotificationService: Initialized successfully');
      debugPrint('NOTE: Notifications only work on real iOS/Android devices, not in web preview.');
    } catch (e) {
      debugPrint('❌ NotificationService: init error: $e');
    }
  }

  Future<bool> requestPermission() async {
    await init();
    debugPrint('NotificationService: Requesting permissions...');
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        debugPrint('NotificationService: iOS platform detected, requesting permissions');
        final ok = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('NotificationService: iOS permission result: ${ok == true ? "GRANTED" : "DENIED"} ');
        return ok ?? false;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        debugPrint('NotificationService: Android platform detected, requesting permissions');
        final ok = await android.requestNotificationsPermission();
        debugPrint('NotificationService: Android permission result: ${ok == true ? "GRANTED" : "DENIED"} ');
        // Best-effort: also ask for exact alarms.
        try {
          await android.requestExactAlarmsPermission();
        } catch (_) {}
        return ok ?? false;
      }
      debugPrint('NotificationService: No native platform detected (likely web). Notifications will not work.');
    } catch (e) {
      debugPrint('NotificationService.requestPermission error: $e');
    }
    return false;
  }

  NotificationDetails _detailsFor(String channelId) {
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
      default:
        name = 'Reminders';
    }
    final android = AndroidNotificationDetails(
      channelId,
      name,
      channelDescription: name,
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwin = DarwinNotificationDetails();
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
  }) async {
    await init();
    debugPrint('🔔 NOTIFICATION: [$channelId] $title - $body');
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _detailsFor(channelId),
      );
      debugPrint('✅ Notification sent successfully (id: $id)');
    } catch (e) {
      debugPrint('❌ NotificationService.showNow error: $e');
      debugPrint('NOTE: Local notifications do not work in web preview. Deploy to iOS/Android to test.');
    }
  }

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required String channelId,
    DateTimeComponents? matchComponents,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _detailsFor(channelId),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
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
    for (var i = 0; i < med.times.length; i++) {
      final t = med.times[i];
      final parts = t.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final now = tz.TZDateTime.now(tz.local);
      var when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (when.isBefore(now)) {
        when = when.add(const Duration(days: 1));
      }
      await _zonedSchedule(
        id: _medIdFor(med.id, i),
        title: 'Medication reminder',
        body: med.dosage == null || med.dosage!.isEmpty
            ? 'Time to take ${med.name}'
            : 'Time to take ${med.name} (${med.dosage})',
        when: when,
        channelId: medicationChannelId,
        matchComponents: DateTimeComponents.time,
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
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));
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
    // Notify at 9am the day before, or at due time itself if already past day-1.
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
