import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'map_page.dart';
import 'admin_dashboard.dart';
import 'dart:math';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;

  bool isLoading = false;
  String errorMessage = '';
  bool isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 1200));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut)..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _controller.forward();
        }
      }),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> navigateToNextPage(User user) async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('client')
          .doc(user.uid)
          .get();

      if (!snapshot.exists) {
        setState(() => errorMessage = "User data not found.");
        return;
      }

      String role = snapshot.get('Role') ?? 'User';
      String phoneNumber = snapshot.get('Phone Number') ?? 'No phone number';

      Future.delayed(Duration.zero, () {
        Widget nextScreen = (role == "Admin")
            ? AdminDashboard()
            : MapScreen(phoneNumber: phoneNumber);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextScreen),
        );
      });
    } catch (e) {
      setState(() => errorMessage = "Error fetching user data.");
    }
  }

  Future<void> loginUser() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        navigateToNextPage(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.code == 'user-not-found'
            ? "User not found."
            : e.code == 'wrong-password'
            ? "Incorrect password."
            : e.message ?? "Login failed.";
      });
    } catch (e) {
      setState(() => errorMessage = "Login failed. Try again.");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Stack(
          children: [
            // Background with Gradient and Animated Particles
            Container(
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade900, Colors.purple.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: AnimatedBackground(),
            ),
            // Main Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo and Title (Stationary Text, Animated Icon)
                        Column(
                          children: [
                            AnimatedBuilder(
                              animation: _glowAnimation,
                              builder: (context, child) {
                                return Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.3 * _glowAnimation.value),
                                        blurRadius: 20 * _glowAnimation.value,
                                        spreadRadius: 5 * _glowAnimation.value,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.lock_rounded,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Welcome Back!",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.purple.shade300.withOpacity(0.5),
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 10),
                            Text(
                              "Sign in to continue your journey",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        SizedBox(height: 50),

                        // Form Fields without Slide Animation
                        Column(
                          children: [
                            buildTextField(
                              "Email Address",
                              emailController,
                              false,
                              Icons.email_rounded,
                            ),
                            SizedBox(height: 20),
                            buildTextField(
                              "Password",
                              passwordController,
                              !isPasswordVisible,
                              Icons.lock_rounded,
                            ),
                            SizedBox(height: 20),

                            // Error Message with Fade Animation
                            if (errorMessage.isNotEmpty)
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    errorMessage,
                                    style: TextStyle(color: Colors.redAccent, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            SizedBox(height: 20),

                            // Login Button with Glowing Effect
                            AnimatedBuilder(
                              animation: _glowAnimation,
                              builder: (context, child) {
                                return Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.purple.shade300.withOpacity(0.3 * _glowAnimation.value),
                                        blurRadius: 15 * _glowAnimation.value,
                                        spreadRadius: 5 * _glowAnimation.value,
                                      ),
                                    ],
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 55,
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      child: ElevatedButton(
                                        onPressed: isLoading ? null : loginUser,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.purple.shade700,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                          elevation: 5,
                                          shadowColor: Colors.purple.shade200,
                                        ),
                                        child: isLoading
                                            ? SizedBox(
                                          height: 25,
                                          width: 25,
                                          child: CircularProgressIndicator(
                                            color: Colors.purple.shade700,
                                            strokeWidth: 3,
                                          ),
                                        )
                                            : Text(
                                          "Login",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade700,
                                            shadows: [
                                              Shadow(
                                                color: Colors.purple.shade300.withOpacity(0.5),
                                                blurRadius: 5,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 20),

                            // Sign Up Link without Underline
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => SignUpScreen()),
                                );
                              },
                              child: Text(
                                "Don't have an account? Sign Up",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  foreground: Paint()
                                    ..shader = LinearGradient(
                                      colors: [Colors.purple.shade300, Colors.white],
                                    ).createShader(Rect.fromLTWH(0, 0, 200, 20)),
                                  shadows: [
                                    Shadow(
                                      color: Colors.purple.shade900.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(
      String hintText, TextEditingController controller, bool obscureText, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade300.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.15),
          prefixIcon: Icon(icon, color: Colors.white70, size: 24),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white70, fontSize: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          suffixIcon: hintText == "Password"
              ? IconButton(
            icon: Icon(
              isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.white70,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                isPasswordVisible = !isPasswordVisible;
              });
            },
          )
              : null,
        ),
      ),
    );
  }
}

// Animated Background with Particle Effect
class AnimatedBackground extends StatefulWidget {
  @override
  _AnimatedBackgroundState createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Particle> particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: 10))..repeat();
    for (int i = 0; i < 50; i++) {
      particles.add(Particle());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        for (var particle in particles) {
          particle.update();
        }
        return CustomPaint(
          painter: ParticlePainter(particles),
          child: Container(),
        );
      },
    );
  }
}

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
        size = Random().nextDouble() * 3 + 1,
        speedX = (Random().nextDouble() - 0.5) * 2,
        speedY = (Random().nextDouble() - 0.5) * 2,
        color = Colors.white.withOpacity(Random().nextDouble() * 0.3 + 0.1);

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