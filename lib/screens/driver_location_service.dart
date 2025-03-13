import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class DriverLocationService {
  final String driverId; // Driver's unique ID
  DriverLocationService({required this.driverId});

  // Function to request permissions
  Future<bool> requestLocationPermission() async {
    var status = await Permission.location.request();
    return status.isGranted;
  }

  // Function to get current location
  Future<Position?> getCurrentLocation() async {
    if (await requestLocationPermission()) {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    }
    return null;
  }

  // Function to update Firebase with driver’s location
  Future<void> updateDriverLocation() async {
    Position? position = await getCurrentLocation();
    if (position != null) {
      DatabaseReference driverRef = FirebaseDatabase.instance.ref("Drivers/$driverId/Location");

      await driverRef.set({
        "Latitude": position.latitude,
        "Longitude": position.longitude,
        "Timestamp": DateTime.now().toIso8601String(),
      });
    }
  }

  // Start updating location every 10 seconds
  void startLocationUpdates() {
    Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update when driver moves 10 meters
      ),
    ).listen((Position position) {
      updateDriverLocation();
    });
  }
}
