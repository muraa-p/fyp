import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class WorkshopListenerService {
  static final WorkshopListenerService _instance = WorkshopListenerService._internal();
  factory WorkshopListenerService() => _instance;
  WorkshopListenerService._internal();

  final NotificationService _notificationService = NotificationService();
  RealtimeChannel? _workshopChannel;
  bool _isListening = false;

  // Start listening for new workshops
  void startListening() {
    if (_isListening) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Optional: change channel name to something simple
    _workshopChannel = Supabase.instance.client.channel('new-workshops-alerts');

    _workshopChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'workshops',
      callback: (payload) async {
        try {
          final newRecord = payload.newRecord;
          final workshopId = newRecord['id'] as String;

          final workshopData = await Supabase.instance.client
              .from('workshops')
              .select('*, users!workshops_creator_id_fkey (name)')
              .eq('id', workshopId)
              .single();

          if (workshopData['creator_id'] != currentUserId) {
            await _notificationService.sendNewWorkshopAlert(workshopData);
          }
        } catch (e) {
          print('Error handling new workshop: $e');
        }
      },
    ).subscribe((status, [error]) {
      if (status == 'SUBSCRIBED') {
        print('Successfully subscribed to new workshops');
      } else if (status == 'CLOSED' || status == 'CHANNEL_ERROR') {
        print('Subscription error: $status - $error');
      }
    });

    _isListening = true;
    print('Started listening for new workshops');
  }

  // Stop listening for new workshops
  void stopListening() {
    if (_workshopChannel != null) {
      Supabase.instance.client.removeChannel(_workshopChannel!);
      _workshopChannel = null;
      _isListening = false;
      print('Stopped listening for new workshops');
    }
  }

  // Check if currently listening
  bool get isListening => _isListening;
}