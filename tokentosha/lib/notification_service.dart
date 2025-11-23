// notification_service.dart
import 'package:flutter/services.dart';

class NotificationService {
  static const platform = MethodChannel('com.tokentosha/notifications');

  static Future<void> initialize() async {
    try {
      print('🔔 Initializing notifications...');
      await platform.invokeMethod('initialize');
      print('✅ Notifications initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize notifications: $e');
    }
  }

  static Future<void> showLowTokenNotification(double balance) async {
    try {
      print('📤 Attempting to show notification for balance: $balance kWh');
      await platform.invokeMethod('showNotification', {
        'title': '⚠️ Low Token Alert',
        'message': 'Your balance is ${balance.toStringAsFixed(1)} kWh. Please top up soon!',
        'id': 1,
      });
      print('✅ Notification command sent successfully');
    } catch (e) {
      print('❌ Failed to show notification: $e');
    }
  }

  static Future<void> showPurchaseSuccessNotification(double amount) async {
    try {
      print('📤 Attempting to show purchase notification for $amount kWh');
      await platform.invokeMethod('showNotification', {
        'title': '✅ Tokens Purchased',
        'message': 'Successfully added ${amount.toStringAsFixed(1)} kWh!',
        'id': 2,
      });
      print('✅ Purchase notification sent');
    } catch (e) {
      print('❌ Failed to show notification: $e');
    }
  }
}