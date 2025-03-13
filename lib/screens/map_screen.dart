import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;
import 'package:firebase_database/firebase_database.dart';

class MapNavigationScreen extends StatefulWidget {
  final LatLng driverLocation;
  final LatLng accidentLocation;
  final String bookingId; // Booking ID for updating status

  const MapNavigationScreen({
    Key? key,
    required this.driverLocation,
    required this.accidentLocation,
    required this.bookingId,
  }) : super(key: key);

  @override
  _MapNavigationScreenState createState() => _MapNavigationScreenState();
}

class _MapNavigationScreenState extends State<MapNavigationScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  loc.Location _location = loc.Location();
  String googleApiKey = "AIzaSyDguKHUXspNVB_08ZF2jpSZFnj8tYxXuyU"; // Replace securely
  late LatLng _currentDestination;
  bool _navigatingToHospital = false;

  @override
  void initState() {
    super.initState();
    _currentDestination = widget.accidentLocation;
    _addMarkers();
    _fetchRoute();
    _listenForLocationUpdates();
  }

  void _addMarkers() {
    setState(() {
      _markers.add(Marker(
        markerId: const MarkerId("driver"),
        position: widget.driverLocation,
        infoWindow: const InfoWindow(title: "Your Location"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));

      _markers.add(Marker(
        markerId: const MarkerId("accident"),
        position: widget.accidentLocation,
        infoWindow: const InfoWindow(title: "Accident Location"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    });
  }

  Future<void> _fetchRoute() async {
    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${widget.driverLocation.latitude},${widget.driverLocation.longitude}&destination=${_currentDestination.latitude},${_currentDestination.longitude}&mode=driving&key=$googleApiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data["status"] == "OK") {
      String encodedPolyline = data["routes"][0]["overview_polyline"]["points"];
      List<LatLng> routePoints = _decodePolyline(encodedPolyline);

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId("route"),
          color: Colors.green,
          width: 5,
          points: routePoints,
        ));
      });
    } else {
      print("Error fetching route: ${data["status"]}");
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _listenForLocationUpdates() {
    _location.onLocationChanged.listen((loc.LocationData locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        LatLng driverPosition = LatLng(locationData.latitude!, locationData.longitude!);

        // Check if driver reached the accident location
        if (!_navigatingToHospital && _isAtLocation(driverPosition, widget.accidentLocation)) {
          _updateBookingStatus("At incident location");
          _findNearestHospital();
        }

        // Check if driver reached the hospital
        if (_navigatingToHospital && _isAtLocation(driverPosition, _currentDestination)) {
          _updateBookingStatus("Completed");
          _showCompletionDialog();
        }
      }
    });
  }

  bool _isAtLocation(LatLng position, LatLng target, {double threshold = 0.0005}) {
    return (position.latitude - target.latitude).abs() < threshold &&
        (position.longitude - target.longitude).abs() < threshold;
  }

  Future<void> _updateBookingStatus(String status) async {
    DatabaseReference bookingRef = FirebaseDatabase.instance.ref("Bookings/${widget.bookingId}");
    await bookingRef.update({"Status": status});
    print("Booking status updated to: $status");
  }

  Future<void> _findNearestHospital() async {
    final String url =
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${widget.accidentLocation.latitude},${widget.accidentLocation.longitude}&radius=5000&type=hospital&key=$googleApiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data["status"] == "OK" && data["results"].isNotEmpty) {
      var hospital = data["results"][0];
      LatLng hospitalLocation = LatLng(
        hospital["geometry"]["location"]["lat"],
        hospital["geometry"]["location"]["lng"],
      );

      setState(() {
        _currentDestination = hospitalLocation;
        _navigatingToHospital = true;
      });

      _updateBookingStatus("On the way to hospital");
      _fetchRoute();
    } else {
      print("No hospitals found nearby.");
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Booking Completed"),
          content: const Text("You have successfully transported the patient to the hospital."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Exit to previous screen
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Navigation to Accident")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.driverLocation,
          zoom: 14.0,
        ),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
        myLocationEnabled: true,
        compassEnabled: true,
      ),
    );
  }
}
