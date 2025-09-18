import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_notifier.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.lightBlue[400],
        iconTheme: IconThemeData(color: Colors.white),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
      ),
      body: Consumer<ThemeNotifier>(
        builder: (context, notifier, child) => SwitchListTile(
          title: const Text('Dark Mode', style: TextStyle(color: Colors.lightBlue)),
          value: notifier.darkTheme,
          onChanged: (val) => notifier.toggleTheme(),
          activeThumbColor: Colors.lightBlue[400],
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
          tileColor: Colors.white,
        ),
      ),
    );
  }
}
