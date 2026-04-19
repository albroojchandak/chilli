import 'package:flutter/material.dart';

class RefundScreen extends StatelessWidget {
  const RefundScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0A1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1030),
        title: const Text('Refund Policy', style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Coins once purchased are non-refundable. Please read the terms and conditions carefully before making a purchase.',
          style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
