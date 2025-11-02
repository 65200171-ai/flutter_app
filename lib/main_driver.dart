import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/driver_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: DriverScreen()));
}
