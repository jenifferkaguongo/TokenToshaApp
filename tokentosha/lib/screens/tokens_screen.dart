// screens/tokens_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TokensScreen extends StatefulWidget {
  const TokensScreen({super.key});

  @override
  State<TokensScreen> createState() => _TokensScreenState();
}

class _TokensScreenState extends State<TokensScreen> {
  final _amountController = TextEditingController();
  final _numberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
  late final CollectionReference _tokensCollection;

  @override
  void initState() {
    super.initState();
    _tokensCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('tokens');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _addToken() async {
    if (_formKey.currentState!.validate()) {
      final amount = int.parse(_amountController.text);
      final number = _numberController.text.trim();

      setState(() {
        FocusScope.of(context).unfocus();
      });

      try {
        await _tokensCollection.add({
          'amount': amount,
          'tokenNumber': number,
          'purchaseDate': Timestamp.now(),
          'isUsed': false,
          'userId': _userId,
        });

        _amountController.clear();
        _numberController.clear();
        _showMessage(context, "Token added successfully!");
      } catch (e) {
        _showMessage(context, "Failed to add token: $e", isError: true);
      }
    }
  }

  Future<void> _toggleTokenUsed(String docId, bool currentStatus) async {
    try {
      await _tokensCollection.doc(docId).update({
        'isUsed': !currentStatus,
      });
      _showMessage(context, "Token status updated!");
    } catch (e) {
      _showMessage(context, "Failed to update status: $e", isError: true);
    }
  }

  Future<void> _deleteToken(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text(
            "Are you sure you want to delete this token permanently?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _tokensCollection.doc(docId).delete();
        _showMessage(context, "Token deleted!");
      } catch (e) {
        _showMessage(context, "Failed to delete token: $e", isError: true);
      }
    }
  }

  void _showMessage(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4CAF50); // TokenTosha Green

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Tokens",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Add Token Form
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Add New Electricity Token",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Amount (KES)",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon:
                              const Icon(Icons.flash_on, color: primaryColor),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              int.tryParse(value) == null) {
                            return 'Please enter a valid amount.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _numberController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: "Token Number (12+ digits)",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon:
                              const Icon(Icons.numbers, color: primaryColor),
                        ),
                        maxLength: 16,
                        validator: (value) {
                          if (value == null || value.length < 12) {
                            return 'Token number must be at least 12 characters long.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _addToken,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 3,
                        ),
                        child: const Text("Save Token",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Your Tokens",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
          ),

          // Token List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _tokensCollection
                  .orderBy('purchaseDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: primaryColor));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No tokens saved yet. Add one above!",
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                final tokens = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: tokens.length,
                  itemBuilder: (context, index) {
                    final tokenDoc = tokens[index];
                    final tokenData = tokenDoc.data() as Map<String, dynamic>;
                    final docId = tokenDoc.id;
                    final isUsed = tokenData['isUsed'] as bool? ?? false;
                    final amount = tokenData['amount'] as int? ?? 0;
                    final number = tokenData['tokenNumber'] as String? ?? 'N/A';
                    final date = (tokenData['purchaseDate'] as Timestamp?)?.toDate();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isUsed
                              ? Colors.grey.shade300
                              : primaryColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      color: isUsed ? Colors.grey.shade100 : Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isUsed ? Colors.grey : primaryColor,
                          child: Text(
                            amount.toString(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                        title: Text(
                          number,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isUsed ? Colors.grey : Colors.black87,
                            decoration: isUsed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          'KES $amount | Purchased: ${date?.toLocal().toString().split(' ')[0] ?? 'N/A'}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isUsed
                                    ? Icons.refresh
                                    : Icons.check_circle_outline,
                                color: isUsed ? Colors.orange : primaryColor,
                              ),
                              onPressed: () => _toggleTokenUsed(docId, isUsed),
                              tooltip:
                                  isUsed ? 'Mark as Unused' : 'Mark as Used',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteToken(docId),
                              tooltip: 'Delete Token',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}