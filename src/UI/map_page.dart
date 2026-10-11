import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

import 'profile_page.dart';
import 'qr_code_scanner.dart';
import 'fape_upi_payment.dart';

DateTime? _lastBackPressed;

class MapScreen extends StatefulWidget {
  final String phoneNumber;
  MapScreen({required this.phoneNumber});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final ValueNotifier<LatLng?> _currentLocation = ValueNotifier<LatLng?>(null);
  final ValueNotifier<LatLng?> _esp32Location = ValueNotifier<LatLng?>(null);
  bool isFollowing = true;
  late MapController _mapController;
  Timer? _locationTimer, _esp32Timer, _dashboardTimer;
  int _selectedIndex = 0;
  String errorMessage = '';

  final String ESP32_IP = "http://192.168.157.97";
  Map<String, dynamic>? userData;
  bool isUserDataLoaded = false;
  bool isLocked = true;
  bool _isPaymentProcessed = false;

  LatLng? _startLocation;
  DateTime? _startTime;
  double _distanceTraveled = 0.0;
  Duration _elapsedTime = Duration.zero;
  List<LatLng> _polylinePoints = [];

  late AnimationController _animationController;
  late Animation<double> _animation;
  late AnimationController _dashboardAnimationController;
  late Animation<double> _dashboardFadeAnimation;
  late AnimationController _qrColorController;
  late Animation<Color?> _qrColor1;
  late Animation<Color?> _qrColor2;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeData();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.6, end: 1.2).animate(_animationController);

    _dashboardAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _dashboardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dashboardAnimationController, curve: Curves.easeIn),
    );

    _qrColorController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat(reverse: true);

    _qrColor1 = ColorTween(
      begin: Colors.blue.shade600,
      end: Colors.blue.shade900,
    ).animate(_qrColorController);

    _qrColor2 = ColorTween(
      begin: Colors.blue.shade400,
      end: Colors.blue.shade700,
    ).animate(_qrColorController);

    _dashboardTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
      }
    });
  }

  void _initializeData() {
    _getCurrentLocation();
    _fetchUserData();
    _getESP32Location();

    _locationTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      _getCurrentLocation();
      print("Fetching current location...");
    });
    _esp32Timer = Timer.periodic(Duration(seconds: 5), (timer) {
      _getESP32Location();
      print("Fetching ESP32 location...");
    });
  }

  void _fetchUserData() async {
    if (isUserDataLoaded) return;

    try {
      String formattedPhoneNumber = widget.phoneNumber.replaceAll(RegExp(r'\s+|-|\(|\)'), '').trim();
      var snapshot = await FirebaseFirestore.instance
          .collection('client')
          .where('Phone Number', isEqualTo: formattedPhoneNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        userData = snapshot.docs.first.data();
        setState(() => isUserDataLoaded = true);
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() => isUserDataLoaded = true);
    }
  }

  Future<void> _getESP32Location() async {
    try {
      print("Fetching ESP32 location from $ESP32_IP/location");
      final response = await http.get(Uri.parse("$ESP32_IP/location")).timeout(Duration(seconds: 5));
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        print("Parsed data: $data");
        LatLng newLocation = LatLng(data["lat"], data["lng"]);
        _esp32Location.value = newLocation;
        print("ESP32 location updated: $newLocation");
        setState(() {});

        if (!isLocked && _startLocation != null) {
          setState(() {
            _polylinePoints.add(newLocation);
            _distanceTraveled = Geolocator.distanceBetween(
              _startLocation!.latitude,
              _startLocation!.longitude,
              newLocation.latitude,
              newLocation.longitude,
            );
          });
        }
      } else {
        throw "Invalid ESP32 response: ${response.statusCode}";
      }
    } catch (e) {
      print("Error fetching ESP32 location: $e");
      _esp32Location.value = null;
    }
  }

  void _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
        _currentLocation.value = LatLng(position.latitude, position.longitude);
        print("Current location updated: ${_currentLocation.value}");
      }
    } catch (e) {
      print("Error fetching current location: $e");
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _esp32Timer?.cancel();
    _dashboardTimer?.cancel();
    _animationController.dispose();
    _dashboardAnimationController.dispose();
    _qrColorController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void _handleESP32Tap() {
    final BuildContext parentContext = context;
    if (isLocked) {
      showModalBottomSheet(
        context: parentContext,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        backgroundColor: Colors.white,
        builder: (context) {
          return Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.directions_bike, color: Colors.blue),
                  title: Text("Vehicle No: 5032054", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Range: 43 ~ 45 Km"),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      parentContext,
                      MaterialPageRoute(builder: (context) => QRCodeScanner()),
                    ).then((value) {
                      print("QR Scanner returned: $value");
                      if (value != null && _currentLocation.value != null) {
                        setState(() {
                          _startLocation = _currentLocation.value;
                          _startTime = DateTime.now();
                          _polylinePoints = [_startLocation!];
                          isLocked = false;
                          _isPaymentProcessed = false;
                          _dashboardAnimationController.forward();
                          print("Vehicle unlocked, isLocked=$isLocked, _isPaymentProcessed=$_isPaymentProcessed");
                        });
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(
                    "Unlock Vehicle",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: parentContext,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        backgroundColor: Colors.white,
        builder: (context) {
          return Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.directions_bike, color: Colors.blue),
                  title: Text("Vehicle No: 5032054", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Range: 43 ~ 45 Km"),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    double rate = (_distanceTraveled / 1000 * _elapsedTime.inMinutes).toDouble();
                    String rideId = "Miracle ride ${DateTime.now().millisecondsSinceEpoch}";

                    try {
                      await http.get(Uri.parse("$ESP32_IP/lock")).timeout(Duration(seconds: 5));
                      print("Lock request sent to ESP32");
                    } catch (e) {
                      print("Error sending lock request to ESP32: $e");
                    }

                    String formattedPhoneNumber = widget.phoneNumber.replaceAll(RegExp(r'\s+|-|\(|\)'), '').trim();
                    print("Formatted phone number: $formattedPhoneNumber");
                    try {
                      var snapshot = await FirebaseFirestore.instance
                          .collection('client')
                          .where('Phone Number', isEqualTo: formattedPhoneNumber)
                          .limit(1)
                          .get();

                      if (snapshot.docs.isNotEmpty) {
                        String userDocId = snapshot.docs.first.id;
                        await FirebaseFirestore.instance.collection('client').doc(userDocId).update({
                          'esp32_id': '',
                          'timestamp': '',
                        });
                        print("Firestore updated successfully: esp32_id and timestamp cleared");
                      } else {
                        print("No document found for phone number: $formattedPhoneNumber");
                      }
                    } catch (e) {
                      print("Error updating Firestore: $e");
                    }

                    setState(() {
                      _startLocation = null;
                      _startTime = null;
                      _distanceTraveled = 0.0;
                      _elapsedTime = Duration.zero;
                      _polylinePoints.clear();
                      isLocked = true;
                      _dashboardAnimationController.reverse();
                      print("Vehicle locked, isLocked=$isLocked, _isPaymentProcessed=$_isPaymentProcessed");
                    });

                    if (!_isPaymentProcessed) {
                      print("Navigating to FapeUpiPayment with rate: $rate");
                      Navigator.push(
                        parentContext,
                        MaterialPageRoute(
                          builder: (context) => FapeUpiPayment(
                            rate: rate,
                            rideId: rideId,
                            durationMinutes: _elapsedTime.inMinutes,
                            dateTime: DateTime.now(),
                          ),
                        ),
                      ).then((_) {
                        setState(() {
                          _isPaymentProcessed = true;
                          print("Returned from FapeUpiPayment, _isPaymentProcessed=$_isPaymentProcessed");
                        });
                      });
                    } else {
                      print("Payment already processed, skipping FapeUpiPayment");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(
                    "Lock Vehicle",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildMap() {
    return ValueListenableBuilder<LatLng?>(
      valueListenable: isLocked ? _currentLocation : _esp32Location,
      builder: (context, location, child) {
        if (location == null) {
          print("Map location is null: isLocked=$isLocked");
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
        }

        print("Building map with location: $location, isLocked=$isLocked");
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade200, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: location,
                  initialZoom: 18.0,
                  maxZoom: 20.0,
                  minZoom: 5.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                  ),
                  PolylineLayer(
                    polylines: [
                      if (!isLocked && _polylinePoints.length >= 2)
                        Polyline(
                          points: _polylinePoints,
                          strokeWidth: 4.0,
                          color: Colors.blueAccent.withOpacity(0.8),
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      if (isLocked && _currentLocation.value != null)
                        Marker(
                          width: 50.0,
                          height: 50.0,
                          point: _currentLocation.value!,
                          child: AnimatedBuilder(
                            animation: _animation,
                            builder: (context, child) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: _animation.value * 40,
                                    height: _animation.value * 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue.withOpacity(0.3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.2),
                                          blurRadius: 10,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 30),
                                ],
                              );
                            },
                          ),
                        ),
                      if (_esp32Location.value != null)
                        Marker(
                          width: 50.0,
                          height: 50.0,
                          point: _esp32Location.value!,
                          child: GestureDetector(
                            onTap: _handleESP32Tap,
                            child: Icon(Icons.pin_drop_rounded, color: Colors.redAccent, size: 30),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Beautified Live Dashboard
            if (!isLocked)
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: FadeTransition(
                  opacity: _dashboardFadeAnimation,
                  child: Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade800, Colors.blue.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildDashboardItem(
                            icon: Icons.map,
                            label: "Distance",
                            value: "${(_distanceTraveled / 1000).toStringAsFixed(2)} km",
                          ),
                          _buildDashboardItem(
                            icon: Icons.timer,
                            label: "Time",
                            value: "${_elapsedTime.inMinutes}:${(_elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}",
                          ),
                          _buildDashboardItem(
                            icon: Icons.speed,
                            label: "Rate",
                            value: "${(_distanceTraveled / 1000 * _elapsedTime.inMinutes).toStringAsFixed(2)}",
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Rounded QR Code Scanner Button
            if (isLocked && _selectedIndex == 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 15,
                child: Center(
                  child: SizedBox(
                    width: 150,
                    height: 60, // Added height to maintain proportions
                    child: AnimatedBuilder(
                      animation: _qrColorController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_qrColor1.value!, _qrColor2.value!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30), // Increased radius for more rounded look
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: FloatingActionButton.extended(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => QRCodeScanner()),
                              ).then((value) {
                                if (value != null && _currentLocation.value != null) {
                                  setState(() {
                                    _startLocation = _currentLocation.value;
                                    _startTime = DateTime.now();
                                    _polylinePoints = [_startLocation!];
                                    isLocked = false;
                                    _isPaymentProcessed = false;
                                    _dashboardAnimationController.forward();
                                    print("Vehicle unlocked via FAB, isLocked=$isLocked, _isPaymentProcessed=$_isPaymentProcessed");
                                  });
                                }
                              });
                            },
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Matching radius
                            tooltip: "Scan to Unlock",
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  "Scan to Unlock",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardItem({required IconData icon, required String label, required String value}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 30),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 6),
        AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: Text(
            value,
            key: ValueKey(value),
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex == 1) {
          setState(() => _selectedIndex = 0);
          return false;
        }

        DateTime now = DateTime.now();
        if (_lastBackPressed == null || now.difference(_lastBackPressed!) > Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Press back again to exit"),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.blueGrey,
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: [_buildMap(), ProfilePage()]),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.map, size: 28),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person, size: 28),
                label: 'Profile',
              ),
            ],
          ),
        ),
        floatingActionButton: _selectedIndex == 0
            ? FloatingActionButton(
          onPressed: () {
            if (_currentLocation.value != null) {
              _mapController.move(_currentLocation.value!, 18.0);
              print("Map centered on current location: ${_currentLocation.value}");
            }
          },
          backgroundColor: Colors.blueAccent,
          elevation: 8,
          tooltip: "Center Map",
          shape: CircleBorder(),
          child: Icon(Icons.my_location, color: Colors.white, size: 28),
        )
            : null,
      ),
    );
  }
}