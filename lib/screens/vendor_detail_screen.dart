import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geodesy/geodesy.dart';
import 'package:customer_app/widgets/menu_item_card.dart';
import 'package:customer_app/screens/profile_screen.dart';
import 'package:customer_app/screens/invoices_screen.dart';
import 'package:customer_app/screens/home_screen.dart';


class VendorDetailScreen extends StatefulWidget {
  final String vendorId;
  final double distance;

  const VendorDetailScreen({Key? key, required this.vendorId, required this.distance}) : super(key: key);

  @override
  _VendorDetailScreenState createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen> {
  Map<String, int> _selectedQuantities = {};
  String? _customerName;
  String? _customerPhoneNumber;
  GeoPoint? _registeredLocation;
  String? _registeredAddress;
  String? _registeredLandmark;
  bool _isBlocking = false;

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  Future<void> _loadCustomerInfo() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot customerDoc = await FirebaseFirestore.instance.collection('customers').doc(user.uid).get();
      if (customerDoc.exists) {
        setState(() {
          _customerName = customerDoc['name'];
          _customerPhoneNumber = customerDoc['phone'];
          _registeredLocation = customerDoc['location'];
          _registeredAddress = customerDoc['address'];
          _registeredLandmark = customerDoc['landmark'];
        });
      }
    }
  }

  void _updateQuantity(String itemName, int quantity) {
    _selectedQuantities[itemName] = quantity;
  }

  Future<void> _handleBlockItems(String vendorId) async {
    if (_selectedQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one item to block.')),
      );
      return;
    }

    // Build the summary of selected items
    String itemsSummary = _selectedQuantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) => '${entry.key} (Qty: ${entry.value})')
        .join('\n');

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Block Items'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Are you sure you want to block the following items?'),
                const SizedBox(height: 10),
                Text(itemsSummary, style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isBlocking = true;
      });

      try {
        if (_registeredLocation == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not retrieve your registered location.')),
          );
          return;
        }

        Position currentPosition = await _determinePosition();
        Geodesy geodesy = Geodesy();
        LatLng registeredLatLng = LatLng(_registeredLocation!.latitude, _registeredLocation!.longitude);
        LatLng currentLatLng = LatLng(currentPosition.latitude, currentPosition.longitude);

        num distance = geodesy.distanceBetweenTwoGeoPoints(registeredLatLng, currentLatLng);

        if (distance <= 300) {
          _blockItems(vendorId, _registeredLocation!, _registeredAddress, _registeredLandmark, false);
        } else {
          _showLocationChoiceDialog(vendorId, currentPosition);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isBlocking = false;
        });
      }
    } else {
      // User cancelled the operation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item blocking cancelled.')),
      );
    }
  }

  Future<void> _showLocationChoiceDialog(String vendorId, Position currentPosition) async {
    String currentAddress = await _getAddressFromLatLng(currentPosition.latitude, currentPosition.longitude);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Warning'),
          content: Text('You are at a different location. Please choose an address to proceed.'),
          actions: <Widget>[
            TextButton(
              child: Text('Registered Address'),
              onPressed: () {
                Navigator.of(context).pop();
                _blockItems(vendorId, _registeredLocation!, _registeredAddress, _registeredLandmark, false);
              },
            ),
            TextButton(
              child: Text('Current Location'),
              onPressed: () {
                Navigator.of(context).pop();
                GeoPoint currentGeoPoint = GeoPoint(currentPosition.latitude, currentPosition.longitude);
                _blockItems(vendorId, currentGeoPoint, currentAddress, null, true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<String> _getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      Placemark place = placemarks[0];
      return "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
    } catch (e) {
      return "Could not get address";
    }
  }

  Future<void> _blockItems(String vendorId, GeoPoint location, String? address, String? landmark, bool isNewLocation) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to block items.')),
      );
      return;
    }

    List<Map<String, dynamic>> blockedItems = [];
    for (var entry in _selectedQuantities.entries) {
      if (entry.value > 0) {
        DocumentSnapshot vendorDoc = await FirebaseFirestore.instance.collection('vendors').doc(vendorId).get();
        if (vendorDoc.exists) {
          List<dynamic> menuItems = vendorDoc['menu'] ?? [];
          var item = menuItems.firstWhere((menuItem) => menuItem['name'] == entry.key, orElse: () => null);
          if (item != null) {
            blockedItems.add({
              'itemName': item['name'],
              'quantity': entry.value,
              'sellingPrice': item['sellingPrice'],
              'mrp': item['mrp'],
              'description': item['description'],
            });
          }
        }
      }
    }

    if (blockedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one item to block.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('blocked_items').add({
        'customerId': user.uid,
        'customerName': _customerName,
        'customerPhoneNumber': _customerPhoneNumber,
        'vendorId': vendorId,
        'blockedItems': blockedItems,
        'timestamp': FieldValue.serverTimestamp(),
        'location': location,
        'address': address,
        'landmark': landmark,
        'new_location': isNewLocation,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Items blocked successfully!')),
      );
      setState(() {
        _selectedQuantities.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to block items: $e')),
      );
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  Future<void> _launchGoogleMaps(GeoPoint location) async {
    final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
    final Uri launchUri = Uri.parse(googleMapsUrl);
    try {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Could not launch Google Maps: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bike Executive Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 5.0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Theme.of(context).primaryColorLight, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('vendors').doc(widget.vendorId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Vendor not found.'));
            }

            var vendorData = snapshot.data!.data() as Map<String, dynamic>;
            List<dynamic> menuItems = vendorData['menu'] ?? [];

            return _VendorDetailsContent(
              vendorData: vendorData,
              menuItems: menuItems,
              selectedQuantities: _selectedQuantities,
              updateQuantity: _updateQuantity,
              handleBlockItems: () => _handleBlockItems(widget.vendorId),
              isBlocking: _isBlocking,
              launchGoogleMaps: _launchGoogleMaps,
              makePhoneCall: _makePhoneCall,
              distance: widget.distance,
            );
          },
        ),
      ),
    );
  }
}

class _VendorDetailsContent extends StatefulWidget {
  final Map<String, dynamic> vendorData;
  final List<dynamic> menuItems;
  final Map<String, int> selectedQuantities;
  final Function(String itemName, int quantity) updateQuantity;
  final VoidCallback handleBlockItems;
  final bool isBlocking;
  final Function(GeoPoint location) launchGoogleMaps;
  final Function(String phoneNumber) makePhoneCall;
  final double distance;

  const _VendorDetailsContent({
    Key? key,
    required this.vendorData,
    required this.menuItems,
    required this.selectedQuantities,
    required this.updateQuantity,
    required this.handleBlockItems,
    required this.isBlocking,
    required this.launchGoogleMaps,
    required this.makePhoneCall,
    required this.distance,
  }) : super(key: key);

  @override
  State<_VendorDetailsContent> createState() => _VendorDetailsContentState();
}

class _VendorDetailsContentState extends State<_VendorDetailsContent> {
  Map<String, String> _menuImageUrls = {};

  @override
  void initState() {
    super.initState();
    _fetchMenuItemImageUrls(widget.menuItems);
  }

  Future<Map<String, String>> _fetchMenuItemImageUrls(List<dynamic> menuItems) async {
    Map<String, String> imageUrls = {};
    for (var item in menuItems) {
      String itemName = item['name'];
      DocumentSnapshot imageDoc = await FirebaseFirestore.instance.collection('menu_images').doc(itemName).get();
      if (imageDoc.exists) {
        imageUrls[itemName] = imageDoc['imageUrl'];
      }
    }
    setState(() {
      _menuImageUrls = imageUrls;
    });
    return imageUrls;
  }

  @override
  Widget build(BuildContext context) {
    String executiveName = widget.vendorData['name'] ?? 'N/A';
    String phoneNumber = widget.vendorData['phoneNumber'] ?? 'N/A';
    GeoPoint? executiveLocation = widget.vendorData['location'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildDetailRow(context, executiveName),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${widget.distance.toStringAsFixed(2)} km away',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (phoneNumber.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => widget.makePhoneCall(phoneNumber),
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (executiveLocation != null)
                        ElevatedButton.icon(
                          onPressed: () => widget.launchGoogleMaps(executiveLocation),
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text('Map'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
            child: Text(
              'Menu:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Theme.of(context).primaryColorDark),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.menuItems.length,
            itemBuilder: (context, index) {
              var item = widget.menuItems[index];
              String itemName = item['name'] ?? 'N/A';
              int currentQuantity = widget.selectedQuantities[itemName] ?? 0;
              String? imageUrl = _menuImageUrls[itemName];

              return MenuItemCard(
                item: item,
                initialQuantity: currentQuantity,
                onQuantityChanged: (name, quantity) {
                  widget.updateQuantity(name, quantity);
                },
                imageUrl: imageUrl,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.isBlocking ? null : widget.handleBlockItems,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: widget.isBlocking ? const CircularProgressIndicator(color: Colors.white) : const Text('Block Items'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        value,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColorDark,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}