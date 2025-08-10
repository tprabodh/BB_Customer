import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:customer_app/screens/home_screen.dart';
import 'package:customer_app/screens/login_screen.dart';

class InitialChecksScreen extends StatefulWidget {
  @override
  _InitialChecksScreenState createState() => _InitialChecksScreenState();
}

class _InitialChecksScreenState extends State<InitialChecksScreen> {
  bool _isLoading = true;
  bool _hasInternet = false;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _performChecks();
  }

  Future<void> _performChecks() async {
    setState(() {
      _isLoading = true;
    });

    // Check for internet connectivity
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      setState(() {
        _hasInternet = false;
        _isLoading = false;
      });
      return;
    }
    _hasInternet = true;

    // Check for location permission
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _hasLocationPermission = false;
        _isLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _hasLocationPermission = false;
          _isLoading = false;
        });
        return;
      }
    }

    _hasLocationPermission = true;

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasInternet) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Internet is required for this app.'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _performChecks,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasLocationPermission) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Location permission is required for this app.'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _performChecks,
                child: Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return HomeScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}
