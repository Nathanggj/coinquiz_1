import 'package:coinquiz/list_calendar.dart';
import 'package:coinquiz/login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Controlla se un utente è loggato
  User? currentUser = FirebaseAuth.instance.currentUser;

  runApp(
    MaterialApp(
      title: 'Calendario Coinquilini',
      debugShowCheckedModeBanner: false,
      home: currentUser != null ? CalendarListScreen() : LoginScreen(),
    ),
  );
}
