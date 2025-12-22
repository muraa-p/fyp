/*
 * Make sure to add these dependencies to your pubspec.yaml:
 *
 * dependencies:
 *   flutter_local_notifications: ^16.1.0
 *   timezone: ^0.9.2
 *   permission_handler: ^11.0.1
 *   device_info_plus: ^9.1.1
 *   url_launcher: ^6.1.14
 *   supabase_flutter: ^1.10.3
 */

import 'dart:async';
import 'dart:io'; // For Platform check
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../screens/workshop_detail_screen.dart'; // Add this import

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _workshopRemindersEnabled = true;
  bool _newWorkshopAlertsEnabled = true;

  // Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Request notification permissions
    await _requestPermissions();

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for workshop reminders
    const AndroidNotificationChannel workshopChannel = AndroidNotificationChannel(
      'workshop_reminders',
      'Workshop Reminders',
      description: 'Notifications for upcoming workshops',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(workshopChannel);

    // Create notification channel for new workshop alerts
    const AndroidNotificationChannel newWorkshopChannel = AndroidNotificationChannel(
      'new_workshop_alerts',
      'New Workshop Alerts',
      description: 'Notifications for new workshops',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(newWorkshopChannel);

    _isInitialized = true;
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    // Android 13+ requires explicit permission
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        await Permission.notification.request();
      }
    }

    // iOS permissions are handled by initialization settings
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) async {
    if (response.payload != null) {
      try {
        // Fetch full workshop data before navigating
        final workshopData = await Supabase.instance.client
            .from('workshops')
            .select('*, users!workshops_creator_id_fkey (name)')
            .eq('id', response.payload as Object) // Fixed: removed "as Object"
            .single();

        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => WorkshopDetailScreen(workshop: workshopData),
          ),
        );
      } catch (e) {
        print('Error fetching workshop data: $e');
        // Navigate to home screen as fallback
        navigatorKey.currentState?.pushNamed('/home');
      }
    }
  }

  // Enable or disable workshop reminders
  void setWorkshopReminders(bool enabled) {
    _workshopRemindersEnabled = enabled;
  }

  // Enable or disable new workshop alerts
  void setNewWorkshopAlerts(bool enabled) {
    _newWorkshopAlertsEnabled = enabled;
  }

  // Schedule a workshop reminder
  Future<void> scheduleWorkshopReminder(
      String workshopId, String workshopTitle, DateTime workshopDateTime) async {
    if (!_workshopRemindersEnabled) return;

    // Calculate reminder time (15 minutes before workshop)
    final reminderTime = workshopDateTime.subtract(const Duration(minutes: 15));

    // Don't schedule if reminder time is in the past
    if (reminderTime.isBefore(DateTime.now())) return;

    // Only schedule if workshop is within the next 24 hours
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    if (workshopDateTime.isAfter(tomorrow)) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      workshopId.hashCode,
      'Workshop Starting Soon',
      'Your workshop "$workshopTitle" starts in 15 minutes!',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'workshop_reminders',
          'Workshop Reminders',
          channelDescription: 'Notifications for upcoming workshops',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: workshopId,
    );
  }

  // Cancel a workshop reminder
  Future<void> cancelWorkshopReminder(String workshopId) async {
    await flutterLocalNotificationsPlugin.cancel(workshopId.hashCode);
  }

  // Cancel all workshop reminders
  Future<void> cancelAllWorkshopReminders() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Schedule reminders for all enrolled workshops
  Future<void> scheduleAllWorkshopReminders() async {
    if (!_workshopRemindersEnabled) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Get all enrolled workshops
      final response = await Supabase.instance.client
          .from('workshop_enrollments')
          .select('workshops(*)')
          .eq('user_id', user.id)
          .gte('workshops.date', DateTime.now().toIso8601String());

      for (final enrollment in response) {
        final workshop = enrollment['workshops'] as Map<String, dynamic>;
        final workshopId = workshop['id'] as String;
        final workshopTitle = workshop['title'] as String;
        final workshopDate = DateTime.parse(workshop['date'] as String);

        await scheduleWorkshopReminder(workshopId, workshopTitle, workshopDate);
      }
    } catch (e) {
      print('Error scheduling workshop reminders: $e');
    }
  }

  // Check for upcoming workshops and schedule reminders
  Future<void> checkAndScheduleReminders() async {
    if (!_workshopRemindersEnabled) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Get all upcoming workshops (next 24 hours)
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      final response = await Supabase.instance.client
          .from('workshop_enrollments')
          .select('workshops(*)')
          .eq('user_id', user.id)
          .gte('workshops.date', now.toIso8601String())
          .lte('workshops.date', tomorrow.toIso8601String());

      for (final enrollment in response) {
        final workshop = enrollment['workshops'] as Map<String, dynamic>;
        final workshopId = workshop['id'] as String;
        final workshopTitle = workshop['title'] as String;
        final workshopDate = DateTime.parse(workshop['date'] as String);

        await scheduleWorkshopReminder(workshopId, workshopTitle, workshopDate);
      }
    } catch (e) {
      print('Error checking and scheduling reminders: $e');
    }
  }

  // Check if notification permissions are granted
  Future<bool> hasPermission() async {
    final result = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled() ?? false;

    return result;
  }

  // Open app settings
  Future<void> openAppSettings() async {
    // Open app settings on Android
    if (Platform.isAndroid) {
      // Use url_launcher instead of AndroidIntent
      if (await canLaunchUrl(Uri.parse('app-settings:'))) {
        await launchUrl(Uri.parse('app-settings:'));
      }
    } else if (Platform.isIOS) {
      // Open app settings on iOS
      if (await canLaunchUrl(Uri.parse('app-settings:'))) {  // Fixed: removed extra closing parenthesis
        await launchUrl(Uri.parse('app-settings:'));
      }
    }
  }

  // Send a notification for a new workshop
  Future<void> sendNewWorkshopAlert(Map<String, dynamic> workshop) async {
    if (!_newWorkshopAlertsEnabled) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || workshop['creator_id'] == currentUserId) {
      // Don't send notification for user's own workshop
      return;
    }

    print('Sending notification for workshop: ${workshop['title']}');

    await flutterLocalNotificationsPlugin.show(
      workshop['id'].hashCode,
      'New Workshop Available!',
      'Check out "${workshop['title']}" by ${workshop['users']['name'] ?? 'Unknown Instructor'}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'new_workshop_alerts',
          'New Workshop Alerts',
          channelDescription: 'Notifications for new workshops',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: workshop['id'],
    );
  }
}