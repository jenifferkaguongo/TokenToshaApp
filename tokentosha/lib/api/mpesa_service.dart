import 'dart:convert';
import 'package:http/http.dart' as http;

class MpesaService {
  final String baseUrl = "http://192.168.146.5:3000"; // Remove the space after http://

  Future<void> initiateSTKPush({
    required String phone,
    required String amount,
    required String meterNumber, // Changed from accountReference
  }) async {
    final url = Uri.parse("$baseUrl/stkpush");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "amount": amount,
          "phone": phone,
          "meter": meterNumber, // Changed to match server
        }),
      );

      if (response.statusCode == 200) {
        print("✅ STK Push initiated: ${response.body}");
      } else {
        print("❌ STK Push failed: ${response.body}");
        throw Exception("Failed to initiate STK Push");
      }
    } catch (e) {
      print("❌ Error: $e");
      throw Exception("Failed to connect to server: $e");
    }
  }
}
