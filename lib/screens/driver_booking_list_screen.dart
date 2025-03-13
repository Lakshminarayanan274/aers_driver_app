import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'driver_profile_screen.dart';
import 'home_screen.dart';

class DriverBookingListScreen extends StatefulWidget {
  @override
  _DriverBookingListScreenState createState() => _DriverBookingListScreenState();
}

class _DriverBookingListScreenState extends State<DriverBookingListScreen> {
  final DatabaseReference bookingRef = FirebaseDatabase.instance.ref().child('Bookings');
  final FirebaseAuth auth = FirebaseAuth.instance;

  String? currentDriverId;
  double driverLat = 0.0;
  double driverLng = 0.0;
  String? activeBookingId;
  String? acceptedBooking;
  bool isAvailable = true;
  double accidentLat=0.0;
  double accidentLng=0.0;
  @override
  void initState() {
    super.initState();
    getCurrentDriverId();
    getCurrentLocation();
    checkForActiveBooking();
  }

  Future<void> getCurrentDriverId() async {
    User? user = auth.currentUser;
    if (user != null) {
      if (!mounted) return;
      setState(() {
        currentDriverId = user.uid;
      });
    }
  }
  void rejectBooking(String bookingId) {
    setState(() {
      pendingBookings.removeWhere((booking) => booking['id'] == bookingId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Booking rejected.")),
    );
  }
  Future<void> getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      driverLat = position.latitude;
      driverLng = position.longitude;
    });
  }

  Future<void> checkForActiveBooking() async {
    bookingRef.orderByChild('driverId').equalTo(currentDriverId).once().then((snapshot) {
      if (snapshot.snapshot.value != null) {
        Map<dynamic, dynamic> bookings = Map<dynamic, dynamic>.from(snapshot.snapshot.value as Map);
        bookings.forEach((key, booking) {
          if (booking['status'] != 'completed') {
            setState(() {
              activeBookingId = key;
              acceptedBooking = "Booking ID: $key, Location: ${booking['location']['locname']}, User: ${booking['Name']}";
              accidentLat = booking['location']['latitude'];
              accidentLng = booking['location']['longitude'];
            });
          }
        });
      }
    });
  }

  bool isBookingExpired(dynamic timestamp) {
    if (timestamp == null) return false;
    final int currentTime = DateTime.now().millisecondsSinceEpoch;
    final int bookingTime = timestamp is int ? timestamp : 0;
    return (currentTime - bookingTime) > (12 * 60 * 60 * 1000);
  }

  bool isWithin10km(double lat1, double lng1, double lat2, double lng2) {
    double distance = Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
    return distance <= 10;
  }

  void acceptBooking(String bookingId, double latitude, double longitude, String locationName, String userName) async {
    if (activeBookingId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You already have an active booking. Complete it first.')),
      );
      return;
    }

    await bookingRef.child(bookingId).update({
      'status': 'accepted',
      'driverId': currentDriverId,

    });

    setState(() {
      activeBookingId = bookingId;
      acceptedBooking = "Booking ID: $bookingId, Location: $locationName, User: $userName";
    });

    Navigator.pushNamed(
      context,
      '/mapScreen',
      arguments: {
        "bookingId": bookingId,
        "driverLocation": LatLng(driverLat, driverLng),
        "accidentLocation": LatLng(latitude, longitude),
      },
    );
  }

  void toggleAvailability() {
    setState(() {
      isAvailable = !isAvailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Available Bookings")),
      body: Column(
        children: [
          Card(
            margin: EdgeInsets.all(10),
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Driver Availability", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Switch(
                        value: isAvailable,
                        onChanged: (value) => toggleAvailability(),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  activeBookingId != null
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Active Booking:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(acceptedBooking ?? "No details available"),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/mapScreen',
                            arguments: {
                              "bookingId": activeBookingId,
                              "driverLocation": LatLng(driverLat, driverLng),
                              "accidentLocation":LatLng(accidentLat,accidentLng),



                            },
                          );
                        },
                        child: Text("Navigate to Incident"),
                      ),
                    ],
                  )
                      : Text("No Active Bookings", style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: bookingRef.onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return Center(child: Text("No bookings available"));
                }

                Map<dynamic, dynamic> bookings = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
                List<Map<String, dynamic>> pendingBookings = [];

                bookings.forEach((key, booking) {
                  if (booking['status'] == 'pending' &&
                      !isBookingExpired(booking['timestamp']) &&
                      booking['driverId'] == null &&
                      isWithin10km(driverLat, driverLng, booking['location']['latitude'], booking['location']['longitude'])) {
                    pendingBookings.add({'id': key, ...booking});
                  }
                });

                if (pendingBookings.isEmpty) {
                  return Center(child: Text("No nearby bookings available"));
                }

                return ListView.builder(
                  itemCount: pendingBookings.length,
                  itemBuilder: (context, index) {
                    final booking = pendingBookings[index];
                    double distanceToAccident = Geolocator.distanceBetween(
                      driverLat, driverLng,
                      booking['location']['latitude'], booking['location']['longitude'],
                    ) / 1000;

                    return Card(
                      child: ListTile(
                        title: Text(booking['details'] ?? 'No details'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("User: ${booking['Name'] ?? 'Unknown'}"),
                            Text("Location: ${booking['location']['locname']}"),
                            Text("Distance to accident: ${distanceToAccident.toStringAsFixed(2)} km"),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                        children:[
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () => acceptBooking(
                            booking['id'],
                            booking['location']['latitude'],
                            booking['location']['longitude'],
                            booking['location']['locname'],
                            booking['Name'],
                          ),
                        ),
                          IconButton(
                            icon: Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => rejectBooking(booking['id']),
                          ),
                        ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Bookings"),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DriverHomeScreen()),
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
