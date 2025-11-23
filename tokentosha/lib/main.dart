// main.dart
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/tokens_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'notification_service.dart';
import 'iot_simulator.dart'; 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();
  runApp(const TokenToshaApp());
}

class TokenToshaApp extends StatelessWidget {
  const TokenToshaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TokenTosha',
      theme: ThemeData(primarySwatch: Colors.green),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => HomeScreen(),
        '/tokens': (context) => TokensScreen(),
        '/auth-check': (context) => const AuthCheckScreen(), // ← ADD THIS
      },
      home: const SplashScreen(), // ← CHANGED THIS
    );
  }
}

class AuthCheckScreen extends StatelessWidget {
  const AuthCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

// Main Navigation
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    DashboardScreen(),
    TokensScreen(),
    PaymentsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: "Tokens"),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: "Payments"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// Dashboard Screen
class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double? _predictedDays;
  double? _tokenAmount;
  double? _dailyUsage;
  List<FlSpot> _usagePoints = [];

  @override
  void initState() {
    super.initState();
     IoTMeterSimulator.startSimulation();
    fetchTokenData();
  }
  @override
void dispose() {
  IoTMeterSimulator.stopSimulation(); // ← ADD THIS
  super.dispose();
}
  Future<void> fetchTokenData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      var tokensSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tokens')
          .orderBy('timestamp', descending: true)
          .get();

      if (tokensSnapshot.docs.isEmpty) return;

      var tokens = tokensSnapshot.docs;
      _usagePoints.clear();

      double totalUsage = 0;
      int count = 0;

      for (int i = 0; i < tokens.length - 1; i++) {
        double currentUnits = (tokens[i]['tokenAmount'] ?? 0).toDouble();
        double prevUnits = (tokens[i + 1]['tokenAmount'] ?? 0).toDouble();

        DateTime currentDate = tokens[i]['timestamp'].toDate();
        DateTime prevDate = tokens[i + 1]['timestamp'].toDate();

        int daysBetween = currentDate.difference(prevDate).inDays;
        if (daysBetween == 0) daysBetween = 1;

        double dailyUsage = (currentUnits / daysBetween).clamp(0, 1000);
        totalUsage += dailyUsage;
        count++;

        _usagePoints.add(FlSpot(i.toDouble(), dailyUsage));
      }

      double averageDailyUsage = count > 0 ? totalUsage / count : 0;
      double latestBalance = (tokens.first['tokenAmount'] ?? 0).toDouble();
      double predictedDays = averageDailyUsage > 0 ? latestBalance / averageDailyUsage : 0;
      if (mounted) {
        setState(() {
        _tokenAmount = latestBalance;
        _dailyUsage = averageDailyUsage;
        _predictedDays = predictedDays;
      });

      _checkLowTokenAlert(latestBalance);
      }
    } catch (e) {
      print("❌ Error fetching token data: $e");
    }
  }

  double predictDays(double tokenAmount, double dailyUsage) {
    double intercept = 5.25;
    double coefToken = 0.083;
    double coefUsage = -0.46;
    double predictedDays = intercept + (coefToken * tokenAmount) + (coefUsage * dailyUsage);
    return predictedDays.clamp(0, 30);
  }

  void _checkLowTokenAlert(double remainingTokens) {
    if (remainingTokens < 10) {
      NotificationService.showLowTokenNotification(remainingTokens);
      _showLowTokenAlert(remainingTokens);
    }
  }

  void _showLowTokenAlert(double balance) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("⚠️ Low Token Alert"),
        content: Text(
          "Your token balance is low!\n"
          "Remaining: ${balance.toStringAsFixed(1)} kWh\n\n"
          "Please top up soon to avoid disconnection.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Dismiss"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentsScreen()),
              );
            },
            child: const Text("Buy Tokens"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Current Balance", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Text(
                      _tokenAmount == null
                          ? "Loading..."
                          : "${_tokenAmount!.toStringAsFixed(2)} kWh",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _dailyUsage == null
                          ? "Estimating daily usage..."
                          : "Daily Usage: ${_dailyUsage!.toStringAsFixed(2)} kWh/day",
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _predictedDays == null
                          ? "Predicting remaining days..."
                          : "Estimated ${_predictedDays!.toStringAsFixed(1)} days left",
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Quick Actions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickAction(Icons.flash_on, "Buy Tokens"),
                _quickAction(Icons.history, "Usage History"),
                _quickAction(Icons.notifications, "Alerts"),
              ],
            ),
            const SizedBox(height: 30),
            const Text("Daily Usage Trend", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: _usagePoints.isEmpty
                  ? const Center(
                      child: Text("📊 Not enough data yet", style: TextStyle(color: Colors.grey)),
                    )
                  : LineChart(
                      LineChartData(
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _usagePoints,
                            isCurved: true,
                            color: Colors.green,
                            belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.2)),
                            dotData: FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, size: 30, color: Colors.blueAccent),
          onPressed: () async {
            if (label == "Buy Tokens") {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsScreen()));
            } else if (label == "Usage History") {
              Navigator.pushNamed(context, '/tokens');
            } else if (label == "Alerts") {
              _checkLowTokenAlert(_tokenAmount ?? 0);
            }
          },
        ),
        Text(label),
      ],
    );
  }
}