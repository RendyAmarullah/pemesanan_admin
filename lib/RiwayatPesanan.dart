import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

final client = Client()
  ..setEndpoint('https://fra.cloud.appwrite.io/v1')
  ..setProject('681aa0b70002469fc157')
  ..setSelfSigned(status: true);

class RiwayatPesanan extends StatefulWidget {
  final String userId;

  RiwayatPesanan({required this.userId});

  @override
  _RiwayatPesananState createState() =>
      _RiwayatPesananState();
}

class _RiwayatPesananState
    extends State<RiwayatPesanan> {
  late Client _client;
  late Databases _databases;
  late Account _account;

  List<Map<String, dynamic>> _allOrders = [];
  bool _isLoading = true;
  String? _errorMessage;

  final String projectId = '681aa0b70002469fc157';
  final String databaseId = '681aa33a0023a8c7eb1f';
  final String acceptedOrdersCollectionId = '6854b40600020e4a49aa';
  final String rejectedOrdersCollectionId = '6854ba6e003bad3da579';

  @override
  void initState() {
    super.initState();
    _initAppwrite();
    _fetchOrders();
  }

  void _initAppwrite() {
    _client = Client();
    _client
        .setEndpoint('https://fra.cloud.appwrite.io/v1')
        .setProject(projectId)
        .setSelfSigned(status: true);

    _databases = Databases(_client);
    _account = Account(_client);
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final acceptedResult = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: acceptedOrdersCollectionId,
        queries: [
          // Query.equal('userId', widget.userId),
          // Query.orderDesc('\$createdAt'),
        ],
      );

      final rejectedResult = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: rejectedOrdersCollectionId,
        queries: [
          // Query.equal('userId', widget.userId),
          // Query.orderDesc('\$createdAt'),
        ],
      );

      List<Map<String, dynamic>> acceptedOrders =
          acceptedResult.documents.map((doc) {
        List<dynamic> products = [];
        try {
          if (doc.data['produk'] is String) {
            products = jsonDecode(doc.data['produk']);
          } else if (doc.data['produk'] is List) {
            products = doc.data['produk'];
          }
        } catch (e) {
          print('Error decoding products: $e');
        }

        return {
          'orderId': doc.$id,
          'originalOrderId': doc.data['orderId'] ?? doc.$id,
          'produk': products,
          'total': doc.data['total'] ?? 0,
          'metodePembayaran': doc.data['metodePembayaran'] ?? 'COD',
          'alamat': doc.data['alamat'] ?? 'No Address',
          'createdAt': doc.data['createdAt'] ?? '',
          'status': 'sedang diproses', 
          'isAccepted': true,
        };
      }).toList();

      List<Map<String, dynamic>> rejectedOrders =
          rejectedResult.documents.map((doc) {
        List<dynamic> products = [];
        try {
          if (doc.data['produk'] is String) {
            products = jsonDecode(doc.data['produk']);
          } else if (doc.data['produk'] is List) {
            products = doc.data['produk'];
          }
        } catch (e) {
          print('Error decoding products: $e');
        }

        return {
          'orderId': doc.$id,
          'originalOrderId': doc.data['orderId'] ?? doc.$id,
          'produk': products,
          'total': doc.data['total'] ?? 0,
          'metodePembayaran': doc.data['metodePembayaran'] ?? 'COD',
          'alamat': doc.data['alamat'] ?? 'No Address',
          'createdAt': doc.data['createdAt'] ?? '',
          'status': 'ditolak',
          'isAccepted': false,
        };
      }).toList();

     
      List<Map<String, dynamic>> combinedOrders = [
        ...acceptedOrders,
        ...rejectedOrders
      ];
      combinedOrders.sort((a, b) {
        try {
          DateTime dateA = DateTime.parse(a['createdAt']);
          DateTime dateB = DateTime.parse(b['createdAt']);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      setState(() {
        _allOrders = combinedOrders;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching orders: $e');
      setState(() {
        _errorMessage = 'Gagal memuat pesanan. Silakan coba lagi.';
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatOrderId(String orderId) {
    return '#${orderId.substring(0, 10)}';
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    List<dynamic> products = order['produk'];
    bool isAccepted = order['isAccepted'] ?? false;
    String status = order['status'] ?? 'unknown';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header dengan Order ID dan Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatOrderId(order['originalOrderId']),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isAccepted ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAccepted ? 'Sedang Diproses' : 'Ditolak',
                    style: TextStyle(
                      color: isAccepted ? Colors.green[800] : Colors.red[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Alamat
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Alamat: ${order['alamat']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Produk
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      ...products
                          .map((product) => Padding(
                                padding: EdgeInsets.only(left: 8, top: 4),
                                child: Text(
                                  '• ${product['nama']} (${product['jumlah']}x)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ))
                          .toList(),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Total, COD, dan Tanggal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order['metodePembayaran'].toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _formatDate(order['createdAt']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatCurrency(order['total']),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList() {
    if (_allOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Tidak ada pesanan',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _allOrders.length,
      itemBuilder: (context, index) {
        return _buildOrderCard(_allOrders[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xFF0072BC),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        title: Text(
          'Status Pesanan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat status pesanan...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchOrders,
                        child: Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  child: _buildOrderList(),
                ),
    );
  }
}
