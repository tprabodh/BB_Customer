import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final int initialQuantity;
  final Function(String itemName, int quantity) onQuantityChanged;
  final String? imageUrl;

  const MenuItemCard({
    Key? key,
    required this.item,
    required this.initialQuantity,
    required this.onQuantityChanged,
    this.imageUrl,
  }) : super(key: key);

  @override
  _MenuItemCardState createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  late int _currentQuantity;

  @override
  void initState() {
    super.initState();
    _currentQuantity = widget.initialQuantity;
  }

  @override
  void didUpdateWidget(covariant MenuItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuantity != oldWidget.initialQuantity) {
      _currentQuantity = widget.initialQuantity;
    }
  }

  void _incrementQuantity() {
    int stock = widget.item['stock'] ?? 0;
    Timestamp? lastUpdated = widget.item['date'];

    bool isStockCurrent = false;
    if (lastUpdated != null) {
      DateTime lastUpdateDate = lastUpdated.toDate();
      DateTime now = DateTime.now();
      if (lastUpdateDate.year == now.year &&
          lastUpdateDate.month == now.month &&
          lastUpdateDate.day == now.day) {
        isStockCurrent = true;
      }
    }
    int displayStock = isStockCurrent ? stock : 0;

    if (_currentQuantity < displayStock) {
      setState(() {
        _currentQuantity++;
      });
      widget.onQuantityChanged(widget.item['name'], _currentQuantity);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add more items than available in stock.')),
      );
    }
  }

  void _decrementQuantity() {
    if (_currentQuantity > 0) {
      setState(() {
        _currentQuantity--;
      });
      widget.onQuantityChanged(widget.item['name'], _currentQuantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    String itemName = widget.item['name'] ?? 'N/A';
    double mrp = (widget.item['mrp'] ?? 0.0).toDouble();
    double sellingPrice = (widget.item['sellingPrice'] ?? 0.0).toDouble();
    String description = widget.item['description'] ?? 'No description available.';
    int stock = widget.item['stock'] ?? 0;
    Timestamp? lastUpdated = widget.item['date'];

    bool isStockCurrent = false;
    if (lastUpdated != null) {
      DateTime lastUpdateDate = lastUpdated.toDate();
      DateTime now = DateTime.now();
      if (lastUpdateDate.year == now.year &&
          lastUpdateDate.month == now.month &&
          lastUpdateDate.day == now.day) {
        isStockCurrent = true;
      }
    }

    int displayStock = isStockCurrent ? stock : 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                  ? Image.network(
                      widget.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.image_not_supported, size: 35, color: Colors.grey[500]),
                    )
                  : Icon(Icons.image, size: 35, color: Colors.grey[500]),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Rs.${mrp.toString()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Rs.${sellingPrice.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            displayStock > 0
                ? Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.primary, size: 24), // Reduced size
                        onPressed: _currentQuantity > 0 ? _decrementQuantity : null,
                      ),
                      Text(
                        '$_currentQuantity',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary, size: 24), // Reduced size
                        onPressed: _currentQuantity < displayStock ? _incrementQuantity : null,
                      ),
                    ],
                  )
                : Expanded(
                    child: Text(
                      'Available on Demand',
                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.end,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
