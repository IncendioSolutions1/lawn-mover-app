import 'package:flutter/material.dart';
import 'sidebar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Sidebar App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SidebarPage(), // Load sidebar as the first screen
    );
  }
}
