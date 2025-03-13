import 'package:aers_driver_app/screens/driver_booking_list_screen.dart';
import 'package:aers_driver_app/screens/driver_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:aers_driver_app/screens/home_screen.dart';
import 'package:aers_driver_app/screens/login_screen.dart';
import 'package:aers_driver_app/screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(AERSDriverApp());
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          return DriverHomeScreen();
        } else {
          return DriverLoginScreen();
        }
      },
    );
  }
}

class AERSDriverApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AERS Driver App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthWrapper(),
      routes: {
        '/login': (context) => DriverLoginScreen(),
        '/home': (context) => DriverHomeScreen(),
        '/profile': (context) {
          final driverId = ModalRoute.of(context)!.settings.arguments as String;
          return DriverProfileScreen(userId: driverId);
        },
        '/bookingList': (context) => DriverBookingListScreen(),
        '/mapScreen': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return MapNavigationScreen(
            driverLocation: args["driverLocation"],
            accidentLocation: args["accidentLocation"],
            bookingId: args["bookingId"], // Ensure booking ID is passed
          );
        },
      },
    );
  }
}
