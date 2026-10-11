import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// RideHistory model (assumed, adjust as per your actual implementation)
class RideHistory {
  final String rideId;
  final double amount;
  final DateTime dateTime;
  final int durationMinutes;

  RideHistory({
    required this.rideId,
    required this.amount,
    required this.dateTime,
    required this.durationMinutes,
  });

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'amount': amount,
      'dateTime': Timestamp.fromDate(dateTime), // Convert DateTime to Firestore Timestamp
      'durationMinutes': durationMinutes,
    };
  }
}

class FapeUpiPayment extends StatefulWidget {
  final double rate;
  final String rideId;
  final int durationMinutes;
  final DateTime dateTime;

  const FapeUpiPayment({
    Key? key,
    required this.rate,
    required this.rideId,
    required this.durationMinutes,
    required this.dateTime,
  }) : super(key: key);

  @override
  _FapeUpiPaymentState createState() => _FapeUpiPaymentState();
}

class _FapeUpiPaymentState extends State<FapeUpiPayment> {
  bool _isPaymentCompleted = false;
  bool _isLoading = true;
  String _paymentStatus = '';
  String _randomUpiId = '';

  // Simulated UPI details
  final String receiverName = "Fape Service";
  final String transactionNote = "Payment for Fape Ride";

  @override
  void initState() {
    super.initState();
    _randomUpiId = "fape${Random().nextInt(10000)}@upi";

    // Initial loading state
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });

    // Simulate payment completion and save to Firestore
    Future.delayed(Duration(seconds: Random().nextInt(3) + 3), () {
      if (mounted) {
        setState(() {
          _isPaymentCompleted = true;
          _paymentStatus = 'Payment Successful! (Simulated)';
        });

        // Save ride details to Firestore
        _saveRideToFirestore();

        // Navigate back after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    });
  }

  Future<void> _saveRideToFirestore() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ No user logged in!");
        setState(() => _paymentStatus = "Error: No user logged in");
        return;
      }

      RideHistory ride = RideHistory(
        rideId: widget.rideId,
        amount: widget.rate,
        dateTime: widget.dateTime,
        durationMinutes: widget.durationMinutes,
      );

      print("Saving ride: ${ride.toMap()} for user: ${user.uid}");
      await FirebaseFirestore.instance
          .collection("client")
          .doc(user.uid)
          .collection("rideHistory")
          .add(ride.toMap());

      print("✅ Ride history saved to Firestore!");
    } catch (e) {
      print("❌ Error saving ride history to Firestore: $e");
      setState(() => _paymentStatus = "Error saving ride: $e");
    }
  }

  // Generate UPI QR Code
  Widget _buildUpiQrCode() {
    String upiUri =
        'upi://pay?pa=$_randomUpiId&pn=$receiverName&am=${widget.rate.toStringAsFixed(2)}&cu=INR&tn=$transactionNote';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 5),
        ],
      ),
      child: QrImageView(
        data: upiUri,
        version: QrVersions.auto,
        size: 200,
        backgroundColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fape UPI Payment'),
        backgroundColor: Colors.deepPurple.shade900,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade900, Colors.purple.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Amount: ₹${widget.rate.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const CircularProgressIndicator(color: Colors.white)
                else if (!_isPaymentCompleted)
                  Column(
                    children: [
                      _buildUpiQrCode(),
                      const SizedBox(height: 20),
                      const Text(
                        'Scan this QR code with any UPI app\n(Auto-payment in 3-5 seconds)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 60),
                      const SizedBox(height: 20),
                      Text(
                        _paymentStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
