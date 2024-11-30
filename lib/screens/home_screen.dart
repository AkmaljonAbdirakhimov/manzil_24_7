import 'package:flutter/material.dart';

import '../models/location.dart';
import '../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();

    _initializeLocation();
  }

  void _initializeLocation() async {
    await LocationService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<LocationModel>(
          stream: LocationService.locationStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(snapshot.error.toString()),
              );
            }

            final location = snapshot.data;
            if (location == null) {
              return const Center(
                child: Text("No'malum manzil"),
              );
            }

            return Center(
              child: Text(
                "Latitude: ${location.latitude},\nLongitude: ${location.longitude}",
              ),
            );
          }),
    );
  }
}
