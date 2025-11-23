// screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController meterNumberController = TextEditingController();
  final TextEditingController feedbackController = TextEditingController();

  File? _image;
  String? _imageUrl;
  bool _isLoading = false;
  bool _isSubmittingFeedback = false;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    meterNumberController.dispose();
    feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          userData = doc.data();
          nameController.text = userData?['name'] ?? '';
          meterNumberController.text = userData?['meterNumber'] ?? '';
          _imageUrl = userData?['imageUrl'];
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  Future<void> _saveChanges() async {
    if (user == null) return;

    setState(() => _isLoading = true);
    String? imageUrl = _imageUrl;

    try {
      // Upload image if user picked one
      if (_image != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images/${user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        UploadTask uploadTask = ref.putFile(_image!);
        TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      // Save user data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'name': nameController.text,
        'meterNumber': meterNumberController.text,
        'email': user!.email,
        'imageUrl': imageUrl,
      }, SetOptions(merge: true));

      // Update local state
      if (mounted) {
        setState(() {
          _isLoading = false;
          _imageUrl = imageUrl;
          _image = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitFeedback() async {
    if (user == null || feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback.')),
      );
      return;
    }

    setState(() => _isSubmittingFeedback = true);

    try {
      // Save feedback to a simple, accessible collection
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user!.uid,
        'userName': nameController.text.isNotEmpty ? nameController.text : 'Anonymous',
        'userEmail': user!.email,
        'meterNumber': meterNumberController.text,
        'message': feedbackController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Pending', // Admin can change to 'Resolved'
        'type': 'Feedback', // Can be 'Complaint', 'Suggestion', 'Feedback'
      });

      feedbackController.clear();
      
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
        Navigator.of(context).pop(); // Close dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Feedback submitted! Thank you.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFeedbackDialog() {
    feedbackController.clear();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.feedback, color: Colors.green),
                  SizedBox(width: 10),
                  Text('Submit Feedback'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'We value your feedback! Let us know how we can improve.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: feedbackController,
                      maxLines: 5,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'Describe your issue, suggestion, or feedback...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    feedbackController.clear();
                  },
                ),
                ElevatedButton.icon(
                  onPressed: _isSubmittingFeedback ? null : _submitFeedback,
                  icon: _isSubmittingFeedback
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSubmittingFeedback ? 'Submitting...' : 'Submit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Picture
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _image != null
                              ? FileImage(_image!)
                              : (_imageUrl != null
                                  ? NetworkImage(_imageUrl!)
                                  : null) as ImageProvider?,
                          child: _image == null && _imageUrl == null
                              ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tap to change photo',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  // Name Field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      prefixIcon: const Icon(Icons.person, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Meter Number Field
                  TextField(
                    controller: meterNumberController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Meter Number',
                      prefixIcon: const Icon(Icons.electric_meter, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Changes Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saveChanges,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Feedback Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _showFeedbackDialog,
                      icon: const Icon(Icons.feedback_outlined, color: Colors.orange),
                      label: const Text(
                        'Submit Feedback',
                        style: TextStyle(color: Colors.orange),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Saved Details Section
                  if (userData != null) ...[
                    const Divider(thickness: 2),
                    const SizedBox(height: 10),
                    const Text(
                      'Account Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(Icons.person, 'Name', nameController.text),
                            const Divider(),
                            _buildDetailRow(Icons.electric_meter, 'Meter Number', meterNumberController.text),
                            const Divider(),
                            _buildDetailRow(Icons.email, 'Email', user?.email ?? 'Not available'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not set' : value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}