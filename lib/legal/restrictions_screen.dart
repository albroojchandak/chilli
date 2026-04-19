import 'package:flutter/material.dart';

class RestrictionsScreen extends StatelessWidget {
  const RestrictionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0A1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1030),
        title: const Text('Account Restrictions', style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildItem('Harassment', 'Any form of abuse is strictly prohibited.'),
            _buildItem('Illegal Content', 'Sharing illegal material will result in immediate ban.'),
            _buildItem('Underage Use', 'Platform is only for users aged 18+.'),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(String title, String desc) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(desc, style: const TextStyle(color: Colors.white70)),
    );
  }
}
