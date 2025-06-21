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
  List<Map<String, dynamic>> _acceptedOrders = [];
  List<Map<String, dynamic>> _rejectedOrders = [];
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
      // Memuat pesanan yang diterima
      final acceptedResult = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: acceptedOrdersCollectionId,
       
      );

      // Memuat pesanan yang ditolak
      final rejectedResult = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: rejectedOrdersCollectionId,
        
      );

      setState(() {
        // Memasukkan pesanan yang diterima
        _acceptedOrders = acceptedResult.documents.map((doc) {
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
            'produk': products,
            'total': doc.data['total'] ?? 0,
            'metodePembayaran': doc.data['metodePembayaran'] ?? 'Unknown',
            'alamat': doc.data['alamat'] ?? 'No Address',
            'createdAt': doc.data['createdAt'] ?? '',
            'status': doc.data['status'] ?? 'Unknown',
          };
        }).toList();

        // Memasukkan pesanan yang ditolak
        _rejectedOrders = rejectedResult.documents.map((doc) {
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
            'produk': products,
            'total': doc.data['total'] ?? 0,
            'metodePembayaran': doc.data['metodePembayaran'] ?? 'Unknown',
            'alamat': doc.data['alamat'] ?? 'No Address',
            'createdAt': doc.data['createdAt'] ?? '',
            'status': doc.data['status'] ?? 'Unknown',
          };
        }).toList();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Color(0xFF0072BC),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          title: Text(
            'Pesanan Diterima dan Ditolak',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOrders,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat pesanan diterima dan ditolak...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
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
      );
    }

    return ListView(
      children: [
        // Pesanan Diterima
        _buildOrderSection('Pesanan Diterima', _acceptedOrders),

        // Pesanan Ditolak
        _buildOrderSection('Pesanan Ditolak', _rejectedOrders),
      ],
    );
  }

 Widget _buildOrderSection(String title, List<Map<String, dynamic>> orders) {
  if (orders.isEmpty) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        '$title: Tidak ada pesanan.',
        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            var order = orders[index];
            List<dynamic> products = order['produk'];

            return Card(
                margin: EdgeInsets.symmetric(vertical: 10),
                child: ListTile(
                  contentPadding: EdgeInsets.all(10),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order ID: ${order['orderId']}'),
                      Text('Alamat: ${order['alamat']}'),
                      Text('Metode Pembayaran: ${order['metodePembayaran']}'),
                      Text('Total: ${_formatCurrency(order['total'])}'),
                      SizedBox(height: 10),
                      Text('Produk:'),
                      ...products.map((product) {
                        return Text('Nama: ${product['nama']}, Jumlah: ${product['jumlah']}');
                      }).toList(),
                    ],
                  ),
                ),
              );
          },
        ),
      ],
    ),
  );
 }
    }
