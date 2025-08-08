import 'package:flutter/material.dart';
import 'package:customer_app/screens/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geodesy/geodesy.dart';
import 'package:customer_app/screens/vendor_detail_screen.dart';

import 'invoices_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  final Geodesy geodesy = Geodesy();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  double _calculateDistance(GeoPoint vendorLocation) {
    if (_currentPosition == null) return 0.0;

    LatLng customerLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    LatLng vendorLatLng = LatLng(vendorLocation.latitude, vendorLocation.longitude);

    return geodesy.distanceBetweenTwoGeoPoints(customerLatLng, vendorLatLng) / 1000; // Distance in kilometers
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/customer_app_logo_.png'),
        ),
        titleSpacing: 0.0, // Remove default spacing
        title: const Text(
          'Home',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 5.0,
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.receipt_long, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InvoicesScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Bike Executives Near Me',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Theme.of(context).primaryColorDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: _currentPosition == null
                  ? Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('vendors').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              'No vendors found.',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          );
                        }

                        // Filter vendors by distance and working status
                        List<DocumentSnapshot> nearbyVendors = [];
                        for (var doc in snapshot.data!.docs) {
                          try {
                            bool isWorking = doc['working'] ?? false;
                            if (isWorking) {
                              GeoPoint vendorLocation = doc['location'];
                              double distance = _calculateDistance(vendorLocation);
                              if (distance <= 1000000) {
                                nearbyVendors.add(doc);
                              }
                            }
                          } catch (e) {
                            // Handle cases where location might be missing or malformed
                          }
                        }

                        if (nearbyVendors.isEmpty) {
                          return Center(
                            child: Text(
                              'Currently there are no active vendors in the area, please try again after some time.',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          );
                        } else if (nearbyVendors.length == 1) {
                          var singleVendor = nearbyVendors.first;
                          GeoPoint vendorLocation = singleVendor['location'];
                          double distance = _calculateDistance(vendorLocation);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VendorDetailScreen(
                                  vendorId: singleVendor.id,
                                  distance: distance,
                                ),
                              ),
                            );
                          });
                          return Center(child: CircularProgressIndicator()); // Show loading while navigating
                        } else { // This else block handles nearbyVendors.length > 1
                          return ListView.builder(
                            itemCount: nearbyVendors.length,
                            itemBuilder: (context, index) {
                              var vendor = nearbyVendors[index];
                              String vendorName = vendor['name'] ?? 'Unknown Vendor';
                              GeoPoint vendorLocation = vendor['location'];
                              double distance = _calculateDistance(vendorLocation);

                              return Card(
                                elevation: 4.0,
                                margin: EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Container(
                                  color: Colors.white,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20.0, vertical: 10.0),
                                    leading: Icon(Icons.person,
                                        color: Theme.of(context).primaryColorDark),
                                    title: Text(
                                      vendorName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColorDark,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'Distance: ${distance.toStringAsFixed(2)} km',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    ),
                                    trailing: Icon(Icons.arrow_forward_ios,
                                        color: Theme.of(context).primaryColor, size: 16.0),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              VendorDetailScreen(vendorId: vendor.id, distance: distance),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
