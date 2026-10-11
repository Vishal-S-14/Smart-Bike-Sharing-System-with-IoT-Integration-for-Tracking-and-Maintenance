import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Convert RideHistory to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'amount': amount,
      'dateTime': dateTime,
      'durationMinutes': durationMinutes,
    };
  }

  // Create RideHistory from Firestore document
  factory RideHistory.fromMap(Map<String, dynamic> map) {
    return RideHistory(
      rideId: map['rideId'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      durationMinutes: map['durationMinutes'] ?? 0,
    );
  }
}