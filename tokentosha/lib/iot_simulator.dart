// iot_simulator.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';

/// Simulates an IoT smart meter sending real-time usage data
/// In production, this would be an actual ESP32/ESP8266 device
class IoTMeterSimulator {
  static Timer? _simulationTimer;
  static final Random _random = Random();
  static bool _isRunning = false;

  /// Start simulating IoT meter readings (for demo purposes)
  static void startSimulation() {
    if (_isRunning) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    _isRunning = true;
    print('🔌 IoT Meter Simulator Started (Simulating ESP32 device)');

    // Simulate meter readings every 30 seconds (in production: every 5 minutes)
    _simulationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        // Simulate realistic usage (between 0.3 - 2.0 kWh per reading)
        double usageThisPeriod = 0.3 + _random.nextDouble() * 1.7;
        
        // Get current token balance
        var tokenSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tokens')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (tokenSnapshot.docs.isEmpty) {
          print('⚠️ No tokens found for user');
          return;
        }

        double currentBalance = (tokenSnapshot.docs.first['tokenAmount'] ?? 0).toDouble();
        double newBalance = (currentBalance - usageThisPeriod).clamp(0, double.infinity);

        // Save "IoT reading" to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('iot_readings')
            .add({
          'usage': usageThisPeriod,
          'remainingBalance': newBalance,
          'timestamp': FieldValue.serverTimestamp(),
          'meterStatus': newBalance > 10 ? 'Normal' : 'Low',
          'deviceType': 'Simulated ESP32', // In production: actual device ID
        });

        // Update the latest token balance
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tokens')
            .doc(tokenSnapshot.docs.first.id)
            .update({
          'tokenAmount': newBalance,
        });

        print('📊 IoT Reading: ${usageThisPeriod.toStringAsFixed(2)} kWh used, ${newBalance.toStringAsFixed(2)} kWh remaining');
      } catch (e) {
        print('❌ IoT Simulation Error: $e');
      }
    });
  }

  /// Stop the simulation
  static void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isRunning = false;
    print('🛑 IoT Meter Simulator Stopped');
  }

  /// Get real-time usage stream (as if reading from actual IoT device)
  static Stream<Map<String, dynamic>> getRealTimeUsage() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('iot_readings')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return {'usage': 0.0, 'remainingBalance': 0.0, 'meterStatus': 'No Data'};
      }
      return snapshot.docs.first.data();
    });
  }

  /// Get usage history for the last 24 hours
  static Future<List<Map<String, dynamic>>> getUsageHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    var yesterday = DateTime.now().subtract(const Duration(hours: 24));

    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('iot_readings')
        .where('timestamp', isGreaterThan: yesterday)
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Calculate average daily usage from IoT readings
  static Future<double> getAverageDailyUsage() async {
    final history = await getUsageHistory();
    if (history.isEmpty) return 0.0;

    double totalUsage = 0;
    for (var reading in history) {
      totalUsage += (reading['usage'] ?? 0).toDouble();
    }

    return totalUsage / history.length;
  }
}