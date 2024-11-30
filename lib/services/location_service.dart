import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:background_locator_2/background_locator.dart';
import 'package:background_locator_2/location_dto.dart';
import 'package:background_locator_2/settings/android_settings.dart';
import 'package:background_locator_2/settings/ios_settings.dart';
import 'package:background_locator_2/settings/locator_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../models/location.dart';
import 'notification_service.dart';

class LocationService {
  static const String _isolateName = "LocatorIsolate";
  static final ReceivePort _port = ReceivePort();
  static final StreamController _locationController =
      StreamController<LocationModel>.broadcast();

  static Stream<LocationModel> get locationStream async* {
    yield* _locationController.stream.cast<LocationModel>();
  }

  static Future<void> initialize() async {
    final hasPermission = await _checkPermission();
    if (hasPermission) {
      // Manzilni sozlamalari
      _getBackgroundLocation();
      _getForegroundLocation();
    }
  }

  static Future<bool> _checkPermission() async {
    final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      return false;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        print('Location permissions are denied');
        return false;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      print(
          'Location permissions are permanently denied, we cannot request permissions.');
      return false;
    }

    return true;
  }

  static void _getBackgroundLocation() async {
    IsolateNameServer.registerPortWithName(_port.sendPort, _isolateName);
    _port.listen((dynamic data) {
      final location = LocationModel(
        latitude: data['latitude'],
        longitude: data['longitude'],
      );
      _locationController.add(location);

      NotificationService.showNotification(
        title: "New Location",
        body:
            "Latitude: ${location.latitude},\nLongitude: ${location.longitude}",
      );
    });
    await BackgroundLocator.initialize();
    _startBackgroundLocationService();
  }

  static void _getForegroundLocation() {
    late geo.LocationSettings locationSettings;
    const int distanceFilter = 10;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = geo.AndroidSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: distanceFilter,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
          notificationText:
              "Example app will continue to receive your location even when you aren't using it",
          notificationTitle: "Running in Background",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = geo.AppleSettings(
        accuracy: geo.LocationAccuracy.high,
        activityType: geo.ActivityType.fitness,
        distanceFilter: distanceFilter,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: distanceFilter,
      );
    }

    geo.Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((location) {
      _locationController.add(
        LocationModel(
          latitude: location.latitude,
          longitude: location.longitude,
        ),
      );
    });
  }

  static void _startBackgroundLocationService() {
    BackgroundLocator.registerLocationUpdate(
      _backgroundLocationCallback,
      initCallback: _initBackgroundLocationCallback,
      initDataCallback: {},
      disposeCallback: _disposeBackgroundLocationCallback,
      autoStop: false,
      iosSettings: const IOSSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        distanceFilter: 10,
      ),
      androidSettings: const AndroidSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        interval: 5,
        distanceFilter: 10,
        androidNotificationSettings: AndroidNotificationSettings(
          notificationChannelName: 'Location tracking',
          notificationTitle: 'Start Location Tracking',
          notificationMsg: 'Track location in background',
          notificationBigMsg:
              'Background location is on to keep the app up-tp-date with your location. This is required for main features to work properly when the app is not running.',
          notificationIcon: '',
          notificationIconColor: Colors.grey,
          notificationTapCallback: _notificationBackgroundLocationCallback,
        ),
      ),
    );
  }

  @pragma('vm:entry-point')
  static void _backgroundLocationCallback(LocationDto locationDto) async {
    final send = IsolateNameServer.lookupPortByName(_isolateName);
    send?.send({
      "latitude": locationDto.latitude,
      "longitude": locationDto.longitude,
    });
  }

//Optional
  @pragma('vm:entry-point')
  static void _initBackgroundLocationCallback(Map<String, dynamic> callback) {
    print('Plugin initialization');
  }

//Optional
  @pragma('vm:entry-point')
  static void _disposeBackgroundLocationCallback() {
    print('Plugin diposed');
    IsolateNameServer.removePortNameMapping(_isolateName);
    BackgroundLocator.unRegisterLocationUpdate();
    _locationController.close();
  }

//Optional
  @pragma('vm:entry-point')
  static void _notificationBackgroundLocationCallback() {
    print('User clicked on the notification');
  }
}
