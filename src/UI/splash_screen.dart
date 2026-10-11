import 'package:flutter/material.dart';
import 'home_screen.dart'; // Import HomeScreen
import 'auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation1;
  late Animation<Color?> _colorAnimation2;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..forward();

    // Gradient animations for live background
    _colorAnimation1 = ColorTween(
      begin: Colors.blue[900],
      end: Colors.purple[900],
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _colorAnimation2 = ColorTween(
      begin: Colors.blue[400],
      end: Colors.purple[400],
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    // Scale animation for logo
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    // Navigate to AuthWrapper after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) { // Check if the widget is still mounted
        try {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AuthWrapper()),
          );
        } catch (e) {
          debugPrint('Navigation error: $e');
          // Optionally, show an error message or navigate to a fallback screen
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _colorAnimation1.value!,
                  _colorAnimation2.value!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Semantics(
                      label: 'Bike Sharing Logo',
                      child: Image.asset(
                        'assets/image.png',
                        width: screenWidth * 0.5, // Responsive width (50% of screen width)
                        height: screenWidth * 0.5, // Responsive height
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.error,
                            size: screenWidth * 0.5,
                            color: Colors.white,
                          ); // Fallback if image fails to load
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  Semantics(
                    label: 'Bike Sharing Title',
                    child: Text(
                      "Bike Sharing",
                      style: TextStyle(
                        fontSize: screenWidth * 0.08, // Responsive font size
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Semantics(
                    label: 'Ride with Ease Subtitle',
                    child: Text(
                      "Ride with Ease",
                      style: TextStyle(
                        fontSize: screenWidth * 0.045, // Responsive font size
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Add a loading indicator
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}