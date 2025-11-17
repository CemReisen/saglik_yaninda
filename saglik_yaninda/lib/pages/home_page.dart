import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Firestore test fonksiyonu
  Future<void> testFirestore() async {
    try {
      await FirebaseFirestore.instance.collection("testData").add({
        "message": "Firestore çalışıyor paşam!",
        "timestamp": DateTime.now(),
      });
      print("Veri başarıyla eklendi!");
    } catch (e) {
      print("Firestore hata: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // ✅ gri zemin korunur
      body: Center(
        child: ElevatedButton(
          onPressed: testFirestore,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4DB6AC),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "Firestore'u Test Et",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
