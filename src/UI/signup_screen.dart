import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart'; // Replace with your actual HomeScreen
import 'dart:math';

class Particle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  Color color;

  Particle()
      : x = Random().nextDouble() * 1000,
        y = Random().nextDouble() * 1000,
        size = Random().nextDouble() * 2 + 0.5,
        speedX = (Random().nextDouble() - 0.5) * 0.5,
        speedY = (Random().nextDouble() - 0.5) * 0.5,
        color = Colors.white.withOpacity(Random().nextDouble() * 0.5 + 0.2);

  void update() {
    x += speedX;
    y += speedY;
    if (x < 0 || x > 1000) speedX = -speedX;
    if (y < 0 || y > 1000) speedY = -speedY;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.purple.shade700, BlendMode.srcOver);
    final paint = Paint();
    for (var particle in particles) {
      paint.color = particle.color;
      canvas.drawCircle(
        Offset(particle.x * size.width / 1000, particle.y * size.height / 1000),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with SingleTickerProviderStateMixin {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  String errorMessage = '';
  String passwordStrength = '';
  Color strengthColor = Colors.grey;
  double strengthProgress = 0.0;
  bool isLoading = false;
  String? selectedRole;
  bool isAdminExists = false; // For UI only, not enforced pre-signup
  bool isPasswordVisible = false;

  late AnimationController _controller;
  List<Particle> particles = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 50; i++) {
      particles.add(Particle());
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(() {
      setState(() {
        for (var particle in particles) {
          particle.update();
        }
      });
    })..repeat();

    // Can't check Admin existence here due to rules; defer to signup
  }

  @override
  void dispose() {
    _controller.dispose();
    usernameController.dispose();
    phoneController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void checkPasswordStrength(String password) {
    int strength = 0;

    if (password.length >= 6) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    setState(() {
      if (password.isEmpty) {
        passwordStrength = '';
        strengthProgress = 0.0;
        strengthColor = Colors.grey;
      } else if (strength <= 1) {
        passwordStrength = "Weak";
        strengthColor = Colors.red;
        strengthProgress = 0.2;
      } else if (strength <= 3) {
        passwordStrength = "Medium";
        strengthColor = Colors.orange;
        strengthProgress = 0.6;
      } else {
        passwordStrength = "Strong";
        strengthColor = Colors.green;
        strengthProgress = 1.0;
      }
    });
  }

  Future<void> _signUpUser() async {
    if (_formKey.currentState!.validate() && selectedRole != null) {
      setState(() => isLoading = true);

      try {
        // Step 1: Create the user
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        // Step 2: Write initial user data
        await FirebaseFirestore.instance.collection('client').doc(userCredential.user!.uid).set({
          "uid": userCredential.user!.uid,
          "Username": usernameController.text,
          "Full Name": nameController.text,
          "Phone Number": phoneController.text,
          "Email": emailController.text,
          "Role": selectedRole,
        });

        // Step 3: Check for existing Admins if the selected role is Admin
        if (selectedRole == "Admin") {
          QuerySnapshot adminQuery = await FirebaseFirestore.instance
              .collection('client')
              .where('Role', isEqualTo: 'Admin')
              .get();

          // If more than one Admin exists (including this new one), roll back
          if (adminQuery.docs.length > 1) {
            // Delete the newly created user data
            await FirebaseFirestore.instance.collection('client').doc(userCredential.user!.uid).delete();
            await userCredential.user!.delete(); // Delete the Firebase Auth user
            throw Exception("Admin account already exists. Only one Admin is allowed.");
          }
        }

        // Step 4: Navigate on success
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen()));
      } on FirebaseAuthException catch (e) {
        setState(() => errorMessage = _getFirebaseErrorMessage(e));
      } on Exception catch (e) {
        setState(() => errorMessage = e.toString());
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return "This email is already registered.";
      case 'weak-password':
        return "Password is too weak.";
      case 'invalid-email':
        return "Invalid email format.";
      default:
        return "Sign-up failed. Please try again.";
    }
  }

  Widget buildTextField({
    required String hintText,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: isPassword && !isPasswordVisible,
      style: const TextStyle(color: Colors.white),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.white,
          ),
          onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
        )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
    );
  }

  Widget buildRoleBubble(String role, IconData icon, {bool disable = false}) {
    return GestureDetector(
      onTap: disable ? null : () => setState(() => selectedRole = role),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        decoration: BoxDecoration(
          color: selectedRole == role ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          children: [
            Icon(icon, color: selectedRole == role ? Colors.purple : Colors.white),
            const SizedBox(width: 5),
            Text(
              role,
              style: TextStyle(
                color: selectedRole == role ? Colors.purple : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: CustomPaint(
              painter: ParticlePainter(particles),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_add, size: 90, color: Colors.white),
                      const SizedBox(height: 15),
                      const Text(
                        "Create an Account",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 25),
                      buildTextField(hintText: "Username", controller: usernameController, icon: Icons.account_circle),
                      const SizedBox(height: 12),
                      buildTextField(hintText: "Full Name", controller: nameController, icon: Icons.person),
                      const SizedBox(height: 12),
                      buildTextField(hintText: "Phone Number", controller: phoneController, icon: Icons.phone),
                      const SizedBox(height: 12),
                      buildTextField(hintText: "Email Address", controller: emailController, icon: Icons.email),
                      const SizedBox(height: 12),
                      buildTextField(
                        hintText: "Password",
                        controller: passwordController,
                        icon: Icons.lock,
                        isPassword: true,
                        onChanged: checkPasswordStrength,
                      ),
                      const SizedBox(height: 12),
                      if (passwordStrength.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Strength: $passwordStrength",
                                style: TextStyle(
                                  color: strengthColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: strengthProgress,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (errorMessage.isNotEmpty)
                        Text(
                          errorMessage,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          buildRoleBubble("User", Icons.person),
                          const SizedBox(width: 10),
                          buildRoleBubble("Admin", Icons.admin_panel_settings, disable: isAdminExists),
                        ],
                      ),
                      const SizedBox(height: 20),
                      isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : ElevatedButton(
                        onPressed: _signUpUser,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(color: Colors.purple, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}