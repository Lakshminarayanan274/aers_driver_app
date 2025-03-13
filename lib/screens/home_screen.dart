import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'driver_booking_list_screen.dart';
import 'driver_profile_screen.dart';
import 'map_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  @override
  _DriverHomeScreenState createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final DatabaseReference bookingRef = FirebaseDatabase.instance.ref().child('Bookings');
  String? currentDriverId;
  double driverLat = 0.0;
  double driverLng = 0.0;
  Map<String, dynamic>? acceptedBooking;

  @override
  void initState() {
    super.initState();
    getCurrentDriverId();
    getCurrentLocation();
  }

  Future<void> getCurrentDriverId() async {
    User? user = auth.currentUser;
    if (user != null) {
      setState(() {
        currentDriverId = user.uid;
      });
      fetchAcceptedBooking();
    }
  }

  Future<void> getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      driverLat = position.latitude;
      driverLng = position.longitude;
    });
  }

  void fetchAcceptedBooking() {
    bookingRef.orderByChild('driverId').equalTo(currentDriverId).onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> bookings = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        bookings.forEach((key, booking) {
          if (booking['status'] == 'accepted') {
            setState(() {
              acceptedBooking = {'id': key, ...booking};
            });
          }
        });
      } else {
        setState(() {
          acceptedBooking = null;
        });
      }
    });
  }

  void cancelBooking() {
    if (acceptedBooking != null) {
      String bookingId = acceptedBooking!['id'];

      bookingRef.child(bookingId).update({
        'status': 'pending', // Make available for other drivers
        'driverId': null, // Unassign driver
      }).then((_) {
        setState(() {
          acceptedBooking = null; // Remove from UI
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Booking canceled successfully")),
        );
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to cancel booking: $error")),
        );
      });
    }
  }

  void navigateToBooking() {
    if (acceptedBooking != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapNavigationScreen(
            driverLocation: LatLng(driverLat, driverLng),
            accidentLocation: LatLng(
              acceptedBooking!['location']['latitude'],
              acceptedBooking!['location']['longitude'],
            ),
            bookingId: acceptedBooking!['id'],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("AERS Driver Dashboard")),
      body: Column(
        children: [
          if (acceptedBooking != null)
            Card(
              margin: EdgeInsets.all(10),
              child: ListTile(
                title: Text("Active Booking"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Details: ${acceptedBooking!['details'] ?? 'No details'}"),
                    Text("Location: ${acceptedBooking!['location']['locname'] ?? 'Unknown'}"),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: navigateToBooking,
                      child: Text("Navigate"),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: cancelBooking,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text("Cancel",style:TextStyle(color:Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "No active booking",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: Center(
              child: Text("Welcome to AERS Driver App"),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Bookings"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DriverBookingListScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DriverProfileScreen(userId: currentDriverId!)),
            );
          }
        },
      ),
    );
  }
}
