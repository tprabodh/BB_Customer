import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart'; // Required for rootBundle

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({Key? key}) : super(key: key);

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String? _currentUserUid;
  String? _customerName;
  String? _customerPhoneNumber;
  String? _customerAddress;
  String? _customerLandmark;
  String? _customerEmail;

  @override
  void initState() {
    super.initState();
    _getCurrentUserUid();
    _loadCustomerInfo();
  }

  void _getCurrentUserUid() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserUid = user.uid;
      });
    }
  }

  Future<void> _loadCustomerInfo() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot customerDoc = await FirebaseFirestore.instance.collection('customers').doc(user.uid).get();
      if (customerDoc.exists) {
        setState(() {
          _customerName = customerDoc['name'];
          _customerPhoneNumber = customerDoc['phone'];
          _customerAddress = customerDoc['address'];
          _customerLandmark = customerDoc['landmark'];
          _customerEmail = customerDoc['email'];
        });
      }
    }
  }

  Future<Uint8List> _generatePdf(DocumentSnapshot invoiceDoc) async {
    final pdf = pw.Document();

    // Load a font that supports Unicode characters (e.g., Roboto)
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    var invoiceData = invoiceDoc.data() as Map<String, dynamic>;
    String vendorBusinessName = "Oxysmart Private Limited";
    String vendorBusinessAddress = "324, 8th cross road, MCECHS Layout, 560077, Bengaluru";
    String gstin = "29AADCJ7541F1ZG";

    List<dynamic> invoiceItems = invoiceData['invoiceItems'] ?? [];
    Timestamp timestamp = invoiceData['timestamp'] ?? Timestamp.now();

    double grandTotal = 0.0;
    for (var item in invoiceItems) {
      grandTotal += (item['sellingPrice'] ?? 0.0) * (item['quantity'] ?? 0);
    }

    double gstAmount = grandTotal - (grandTotal / 1.05);
    double subTotal = grandTotal / 1.05;


    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  vendorBusinessName,
                  style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, font: ttf),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(vendorBusinessAddress, style: pw.TextStyle(font: ttf)),
                    pw.Text('GSTIN: $gstin', style: pw.TextStyle(font: ttf)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer Details:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf)),
                      pw.Text('Name: ${_customerName ?? 'N/A'}', style: pw.TextStyle(font: ttf)),
                      pw.Text('Email: ${_customerEmail ?? 'N/A'}', style: pw.TextStyle(font: ttf)),
                      pw.Text('Address: ${_customerAddress ?? 'N/A'}', style: pw.TextStyle(font: ttf)),
                      pw.Text('Landmark: ${_customerLandmark ?? 'N/A'}', style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                  pw.Text('Invoice Date: ${timestamp.toDate().toLocal().toString().split('.')[0]}', style: pw.TextStyle(font: ttf)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Item', 'Qty', 'MRP', 'Selling Price (excl. GST)', 'Total (excl. GST)'],
                data: invoiceItems.map((item) {
                  double sellingPrice = item['sellingPrice'] ?? 0.0;
                  int quantity = item['quantity'] ?? 0;
                  double exclusiveSellingPrice = sellingPrice / 1.05;
                  double exclusiveTotal = exclusiveSellingPrice * quantity;
                  return [
                    item['itemName'],
                    quantity.toString(),
                    'Rs.${(item['mrp'] ?? 0.0).toStringAsFixed(2)}',
                    'Rs.${exclusiveSellingPrice.toStringAsFixed(2)}',
                    'Rs.${exclusiveTotal.toStringAsFixed(2)}',
                  ];
                }).toList(),
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf),
                cellAlignment: pw.Alignment.centerRight,
                cellAlignments: {0: pw.Alignment.centerLeft},
                cellStyle: pw.TextStyle(font: ttf), // Apply font to table cells
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: Rs.${subTotal.toStringAsFixed(2)}', style: pw.TextStyle(font: ttf)),
                    pw.Text('GST (5%): Rs.${gstAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: ttf)),
                    pw.Text('Grand Total: Rs.${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  void _showInvoicePreview(DocumentSnapshot invoiceDoc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Invoice Preview', style: TextStyle(color: Colors.white)),
            backgroundColor: Theme.of(context).primaryColor,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PdfPreview(
            build: (format) => _generatePdf(invoiceDoc),
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canDebug: false,
            maxPageWidth: 700,
            onShared: (context) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invoice shared successfully!')),
              );
            },
            onPrinted: (context) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invoice printed successfully!')),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final pdfBytes = await _generatePdf(invoiceDoc);
              final String fileName = 'invoice_${invoiceDoc['timestamp'].toDate().millisecondsSinceEpoch}.pdf';
              await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invoice shared/saved successfully!')),
              );
            },
            label: const Text('Share/Save Invoice'),
            icon: const Icon(Icons.share),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Invoices'),
      ),
      body: _currentUserUid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('invoices')
                  .where('customerId', isEqualTo: _currentUserUid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No invoices found.'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var invoice = snapshot.data!.docs[index];
                    Timestamp timestamp = invoice['timestamp'] ?? Timestamp.now();
                    List<dynamic> invoiceItems = invoice['invoiceItems'] ?? [];

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text('Invoice on: ${timestamp.toDate().toLocal().toString().split('.')[0]}'),
                        subtitle: Text(
                          invoiceItems.map((item) => '${item['itemName']} (Qty: ${item['quantity']})').join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _showInvoicePreview(invoice),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

