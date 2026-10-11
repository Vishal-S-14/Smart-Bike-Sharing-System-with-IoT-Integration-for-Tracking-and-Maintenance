import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PhotoPage extends StatefulWidget {
  const PhotoPage({Key? key}) : super(key: key);

  @override
  _PhotoPageState createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> with SingleTickerProviderStateMixin {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();

  String? profilePictureUrl;
  File? _image;

  bool isLoading = false;
  String errorMessage = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    getUserData();

    // Initialize animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    fullNameController.dispose();
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> getUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var snapshot = await FirebaseFirestore.instance
            .collection('client')
            .doc(user.uid)
            .get();

        if (snapshot.exists) {
          Map<String, dynamic> data = snapshot.data()!;
          setState(() {
            fullNameController.text = data['Full Name'] ?? '';
            emailController.text = data['Email'] ?? '';
            usernameController.text = data['Username'] ?? '';
            passwordController.text = data['Password'] ?? '';
            phoneNumberController.text = data['Phone Number'] ?? '';
            profilePictureUrl = data['profilePicture'] ?? '';
          });
        }
      } catch (e) {
        debugPrint('Failed to fetch user data: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImageToStorage(File image, String uid) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(image);
      String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Failed to upload image: $e');
      return null;
    }
  }

  Future<void> _updateUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      try {
        if (_image != null) {
          profilePictureUrl = await _uploadImageToStorage(_image!, user.uid);
          if (profilePictureUrl == null) {
            throw Exception('Image upload failed');
          }
        }

        await FirebaseFirestore.instance.collection('client').doc(user.uid).update({
          'Full Name': fullNameController.text,
          'Email': emailController.text,
          'Username': usernameController.text,
          'Phone Number': phoneNumberController.text,
          'Password': passwordController.text, // Note: Storing passwords in plain text is insecure!
          'profilePicture': profilePictureUrl ?? '',
        });

        Navigator.pop(context, {
          'phoneNumber': phoneNumberController.text,
          'profilePicture': profilePictureUrl,
        });
      } catch (e) {
        debugPrint('Failed to update profile: $e');
        setState(() {
          errorMessage = 'Failed to save changes. Try again.';
        });
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[900]!.withOpacity(0.9),
              Colors.blue[400]!.withOpacity(0.7),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        "Edit Profile",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 44), // Placeholder for symmetry
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Profile Picture Section
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.blue[700]!, Colors.blue[400]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue[900]!.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 56,
                            backgroundColor: Colors.white,
                            backgroundImage: _image != null
                                ? FileImage(_image!)
                                : (profilePictureUrl != null && profilePictureUrl!.isNotEmpty)
                                ? NetworkImage(profilePictureUrl!)
                                : const AssetImage('assets/image.png') as ImageProvider,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.blue[900],
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Form Fields
                  _buildTextField(
                    hintText: 'Full Name',
                    controller: fullNameController,
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    hintText: 'Email',
                    controller: emailController,
                    icon: Icons.email,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    hintText: 'Username',
                    controller: usernameController,
                    icon: Icons.account_circle,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    hintText: 'Phone Number',
                    controller: phoneNumberController,
                    icon: Icons.phone,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    hintText: 'Password',
                    controller: passwordController,
                    icon: Icons.lock,
                    isPassword: true,
                  ),
                  const SizedBox(height: 20),
                  // Error Message
                  if (errorMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red[200]!.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        errorMessage,
                        style: TextStyle(
                          color: Colors.red[900],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Save Button
                  Center(
                    child: isLoading
                        ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[900]!),
                    )
                        : ElevatedButton(
                      onPressed: _updateUserData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 100),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: Colors.blue[900]!.withOpacity(0.4),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    required TextEditingController controller,
    bool isPassword = false,
    IconData? icon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(15),
        elevation: 6,
        shadowColor: Colors.blue[200],
        child: TextField(
          controller: controller,
          obscureText: isPassword,
          style: TextStyle(color: Colors.blue[900], fontSize: 16, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
            filled: true,
            fillColor: Colors.transparent,
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.blue[900], size: 20)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.blue[200]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.blue[900]!, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}