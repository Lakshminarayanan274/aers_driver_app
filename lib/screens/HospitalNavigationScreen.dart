import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HospitalNavigationScreen extends StatelessWidget {
  final LatLng accidentLocation;

  const HospitalNavigationScreen({Key? key, required this.accidentLocation}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock hospital location (replace with nearest hospital logic)
    final LatLng hospitalLocation = LatLng(12.972442, 77.580643); // Example: Bangalore coordinates

    return Scaffold(
      appBar: AppBar(title: Text('Navigate to Hospital')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: accidentLocation,
          zoom: 14,
        ),
        markers: {
          Marker(
            markerId: MarkerId('accident'),
            position: accidentLocation,
                         infoWindow: InfoWindow(title: 'Accident Location'),
          ),
          Marker(
            markerId: MarkerId('hospital'),
            position: hospitalLocation,
            infoWindow: InfoWindow(title: 'Hospital'),
          ),
        },
      ),
    );
  }
}
