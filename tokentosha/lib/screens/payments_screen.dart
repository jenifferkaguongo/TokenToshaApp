import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String _BASE_URL = "http://192.168.146.5:3000";

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({Key? key}) : super(key: key);

  @override
  _PaymentsScreenState createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: '10');
  final TextEditingController _phoneController = TextEditingController(text: '0712345678');
  final TextEditingController _meterController = TextEditingController(text: '1234567890');
  
  bool _isSaving = false;
  bool _isStkProcessing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadUserMeterNumber();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    _meterController.dispose();
    super.dispose();
  }

  // Load meter number from user profile
  Future<void> _loadUserMeterNumber() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data()?['meterNumber'] != null) {
      setState(() {
        _meterController.text = doc.data()!['meterNumber'];
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // Extract details from pasted message
  Map<String, dynamic>? _parseMessage(String text) {
    try {
      final meterMatch = RegExp(r'Mtr:(\d+)').firstMatch(text);
      final tokenMatch = RegExp(r'Token:([\d-]+)').firstMatch(text);
      final dateMatch = RegExp(r'Date:(\d{8}\s\d{2}:\d{2})').firstMatch(text);
      final unitsMatch = RegExp(r'Units:(\d+(\.\d+)?)').firstMatch(text);
      final amtMatch = RegExp(r'Amt:(\d+(\.\d+)?)').firstMatch(text);
      final tknAmtMatch = RegExp(r'TknAmt:(\d+(\.\d+)?)').firstMatch(text);
      final otherChargesMatch = RegExp(r'OtherCharges:(\d+(\.\d+)?)').firstMatch(text);

      if (meterMatch == null || tokenMatch == null) return null;

      return {
        'meterNumber': meterMatch.group(1),
        'tokenNumber': tokenMatch.group(1),
        'date': dateMatch?.group(1),
        'units': double.tryParse(unitsMatch?.group(1) ?? '0') ?? 0,
        'amountPaid': double.tryParse(amtMatch?.group(1) ?? '0') ?? 0,
        'tokenAmount': double.tryParse(tknAmtMatch?.group(1) ?? '0') ?? 0,
        'otherCharges': double.tryParse(otherChargesMatch?.group(1) ?? '0') ?? 0,
        'timestamp': FieldValue.serverTimestamp(),
      };
    } catch (e) {
      return null;
    }
  }

  // Save to Firestore
  Future<void> _saveToFirestore(Map<String, dynamic> tokenData) async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _statusMessage = "User not logged in!");
        return;
      }

      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDoc.collection('tokens').add(tokenData);

      setState(() {
        _statusMessage = "✅ Token saved successfully!";
        _messageController.clear();
      });
    } catch (e) {
      setState(() => _statusMessage = "❌ Failed to save token: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Pay with M-Pesa STK Push
  Future<void> _payWithSTKPush() async {
    final amount = double.tryParse(_amountController.text);
    final phone = _phoneController.text.trim();
    final meter = _meterController.text.trim();

    if (amount == null || amount < 1 || phone.length < 9 || meter.isEmpty) {
      _showSnackBar("Please check Amount (min 1 Ksh), Phone, and Meter Number.", Colors.red);
      return;
    }

    // Format phone to 254 format
    final formattedPhone = phone.startsWith('0') ? '254${phone.substring(1)}' : phone;

    setState(() {
      _isStkProcessing = true;
      _statusMessage = "Initiating M-Pesa STK Push...";
    });

    final url = Uri.parse('$_BASE_URL/stkpush');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': amount.toInt(),
          'phone': formattedPhone,
          'meter': meter,
        }),
      );

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        _showSnackBar("M-Pesa prompt sent! Check your phone to complete payment.", Colors.green);
        setState(() => _statusMessage = "✅ STK Push sent! Enter your M-Pesa PIN on your phone.");
        
        // Simulate token fetch after payment
        _mockTokenFetch(formattedPhone, amount);
      } else {
        final errorMessage = responseData['error'] ?? responseData['message'] ?? 'STK Push failed';
        _showSnackBar(errorMessage.toString(), Colors.red);
        setState(() => _statusMessage = "❌ STK Push Error: $errorMessage");
      }
    } catch (e) {
      print("HTTP Error: $e");
      _showSnackBar('Network error. Check if server is running at $_BASE_URL', Colors.red);
      setState(() => _statusMessage = "❌ Network Error: $e");
    }

    setState(() => _isStkProcessing = false);
  }

  // Mock token fetch (simulates callback)
  Future<void> _mockTokenFetch(String phone, double amount) async {
    setState(() => _statusMessage = "Waiting for payment confirmation...");
    await Future.delayed(const Duration(seconds: 10));

    final url = Uri.parse('$_BASE_URL/fetchToken');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone}),
      );

      final tokenResult = json.decode(response.body);

      if (response.statusCode == 200 && tokenResult['token'] != null) {
        final mockMessage = "Mtr:${_meterController.text}\n"
            "Token:${tokenResult['token']}\n"
            "Date:20251113 ${DateTime.now().hour}:${DateTime.now().minute}\n"
            "Units:${(amount * 5).toStringAsFixed(2)}\n"
            "Amt:${amount.toStringAsFixed(2)}\n"
            "TknAmt:${(amount * 0.9).toStringAsFixed(2)}\n"
            "OtherCharges:${(amount * 0.1).toStringAsFixed(2)}";

        _messageController.text = mockMessage;

        final parsed = _parseMessage(mockMessage);
        if (parsed != null) {
          await _saveToFirestore(parsed);
        }
      } else {
        setState(() => _statusMessage = 'Payment confirmation failed.');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Network error fetching token.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Tokens'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // M-Pesa Payment Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "💳 Pay with M-Pesa",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount (KES)',
                        prefixIcon: const Icon(Icons.money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number (0712345678)',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: _meterController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Meter Number',
                        prefixIcon: const Icon(Icons.electric_meter),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_isStkProcessing)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton.icon(
                        onPressed: _payWithSTKPush,
                        icon: const Icon(Icons.phone_android),
                        label: const Text("Pay with M-Pesa"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),

            // Manual Token Entry Section
            const Text(
              "📝 Or Paste Token Message",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _messageController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: "Mtr:14468925822\nToken:4580-2098-3988-5925-0533\nDate:20251023 02:10\nUnits:2.4\nAmt:50.00\nTknAmt:28.88\nOtherCharges:21.12",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            if (_isSaving) const Center(child: CircularProgressIndicator()),

            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusMessage!.contains("✅")
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _statusMessage!.contains("✅") ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: () {
                final text = _messageController.text.trim();
                final parsed = _parseMessage(text);

                if (parsed == null) {
                  setState(() {
                    _statusMessage = "⚠️ Could not extract details. Check message format.";
                  });
                } else {
                  _saveToFirestore(parsed);
                }
              },
              icon: const Icon(Icons.save),
              label: const Text("Save Token Details"),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}