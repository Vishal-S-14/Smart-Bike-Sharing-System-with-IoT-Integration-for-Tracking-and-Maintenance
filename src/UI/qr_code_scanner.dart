import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class QRCodeScanner extends StatefulWidget {
  @override
  _QRCodeScannerState createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends State<QRCodeScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isProcessing = false;
  String? microcontrollerID;
  final String esp32BaseURL = "http://192.168.157.97"; // Replace with actual ESP32 IP

  @override
  void initState() {
    super.initState();
    fetchMicrocontrollerID();
  }

  Future<void> fetchMicrocontrollerID() async {
    try {
      final response = await http.get(Uri.parse("$esp32BaseURL/get_id"));
      if (response.statusCode == 200) {
        setState(() {
          microcontrollerID = jsonDecode(response.body)['id'];
        });
        print("✅ Fetched ESP32 ID: $microcontrollerID");
      } else {
        print("❌ Failed to fetch ESP32 ID: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error fetching ESP32 ID: $e");
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    controller?.pauseCamera();
    controller?.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Custom AppBar with gradient
      appBar: AppBar(
        title: const Text(
          "Scan QR Code",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background gradient for the body
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurpleAccent, Colors.black87],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Column(
            children: <Widget>[
              // QR Scanner Area
              Expanded(
                flex: 4,
                child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Colors.purpleAccent,
                    borderRadius: 12,
                    borderLength: 40,
                    borderWidth: 8,
                    cutOutSize: 280,
                    overlayColor: Colors.black.withOpacity(0.6),
                  ),
                ),
              ),
              // Instruction Text
              Expanded(
                flex: 1,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Align the QR code within the frame to unlock your ride',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Custom Loading Overlay
          if (isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                        strokeWidth: 5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Processing QR Code...",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code != null && !isProcessing) {
        setState(() => isProcessing = true);
        String scannedID = scanData.code!;

        if (scannedID == microcontrollerID) {
          bool esp32Success = await sendRequestToESP32();
          if (esp32Success) {
            await saveToFirebase(scannedID);
            controller.dispose();
            Navigator.pop(context, scannedID);
          } else {
            setState(() => isProcessing = false);
            showError("ESP32 did not respond.");
          }
        } else {
          setState(() => isProcessing = false);
          showError("Invalid QR Code: $scannedID");
        }
      }
    });
  }

  Future<bool> sendRequestToESP32() async {
    try {
      // Step 1: Confirm the scan
      final confirmResponse = await http.get(Uri.parse("$esp32BaseURL/confirm_scan"));
      if (confirmResponse.statusCode != 200) {
        print("❌ Failed to confirm scan.");
        return false;
      }

      // Step 2: Unlock the bike
      final unlockResponse = await http.get(Uri.parse("$esp32BaseURL/unlock"));
      if (unlockResponse.statusCode == 200) {
        print("✅ Bike Unlocked!");
        return true;
      } else {
        print("❌ Failed to unlock the bike.");
        return false;
      }
    } catch (e) {
      print("❌ Error connecting to ESP32: $e");
      return false;
    }
  }

  Future<void> saveToFirebase(String scannedID) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");

      await FirebaseFirestore.instance.collection("client").doc(user.uid).set({
        "esp32_id": scannedID,
        "timestamp": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("✅ ESP32 ID saved to Firebase!");
    } catch (e) {
      print("❌ Error saving to Firebase: $e");
      showError("Error saving to Firebase: $e");
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}