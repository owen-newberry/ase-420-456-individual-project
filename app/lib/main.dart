import 'package:flutter/material.dart';
import 'screens/adminDashboard.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DNA Sports Center',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AdminDashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}
