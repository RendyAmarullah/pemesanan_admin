import 'dart:io';
import 'package:intl/intl.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class RiwayatPesanan extends StatefulWidget {
  final String userId;

  RiwayatPesanan({required this.userId});

  @override
  _RiwayatPesananState createState() => _RiwayatPesananState();
}

class _RiwayatPesananState extends State<RiwayatPesanan> {
  late Client _client;
  late Databases _databases;

  List<Map<String, dynamic>> _allOrders = [];
  bool _isLoading = true;
  String? _errorMessage;

  final String projectId = '681aa0b70002469fc157';
  final String databaseId = '681aa33a0023a8c7eb1f';
  final String ordersCollectionId = '684b33e80033b767b024';
  String _selectedFilter = 'Tahun';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initAppwrite();
    _fetchOrders();
  }

  void _initAppwrite() {
    _client = Client()
      ..setEndpoint('https://fra.cloud.appwrite.io/v1')
      ..setProject(projectId)
      ..setSelfSigned(status: true);

    _databases = Databases(_client);
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ordersResult = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: ordersCollectionId,
        queries: [
          Query.equal('status', ['selesai', 'dibatalkan']),
          Query.orderDesc('\$createdAt'),
        ],
      );

      List<Map<String, dynamic>> orders = ordersResult.documents.map((doc) {
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
          'originalOrderId': doc.data['orderId'],
          'produk': products,
          'nama': doc.data['nama'],
          'total': doc.data['total'] ?? 0,
          'metodePembayaran': doc.data['metodePembayaran'] ?? 'COD',
          'alamat': doc.data['alamat'] ?? 'No Address',
          'createdAt': doc.data['tanggal'] ?? '',
          'status': doc.data['status'] ?? 'Menunggu',
        };
      }).toList();

      if (_selectedFilter != 'Semua') {
        orders = _filterOrders(orders);
      }
      setState(() {
        _allOrders = orders;
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

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _databases.updateDocument(
        databaseId: databaseId,
        collectionId: ordersCollectionId,
        documentId: orderId,
        data: {'status': newStatus},
      );

      setState(() {
        _allOrders = _allOrders.map((order) {
          if (order['orderId'] == orderId) {
            order['status'] = newStatus;
          }
          return order;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Status pesanan telah diperbarui menjadi $newStatus')),
      );
    } catch (e) {
      print('Error updating order status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui status pesanan')),
      );
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

  List<Map<String, dynamic>> _filterOrders(List<Map<String, dynamic>> orders) {
    DateTime startDate;
    DateTime endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    if (_selectedFilter == 'Hari') {
      startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    } else if (_selectedFilter == 'Bulan') {
      startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
    } else if (_selectedFilter == 'Tahun') {
      startDate = DateTime(_selectedDate.year, 1, 1);
    } else {
      return orders; // Jika filter tidak dikenali, return semua data
    }

    return orders.where((order) {
      DateTime createdAt = DateTime.parse(order['createdAt']);
      return createdAt.isAfter(startDate) && createdAt.isBefore(endDate);
    }).toList();
  }

  Future<void> _downloadReport() async {
    String csvData = "Order ID, Nama, Total, Metode Pembayaran, Tanggal, Status\n";

    for (var order in _allOrders) {
      csvData += "${order['originalOrderId']}, ${order['nama']}, ${order['total']}, ${order['metodePembayaran']}, ${order['createdAt']}, ${order['status']}\n";
    }

    // Memilih direktori menggunakan FilePicker
    String? directoryPath = await FilePicker.platform.getDirectoryPath();

    if (directoryPath != null) {
      final file = File('$directoryPath/Laporan Penjualan.csv');
      await file.writeAsString(csvData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Laporan berhasil diunduh: ${file.path}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pemilihan direktori dibatalkan')),
      );
    }
  }


  Widget _buildOrderCard(Map<String, dynamic> order) {
    List<dynamic> products = order['produk'];
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order['originalOrderId'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'Sedang Diantar'
                        ? Colors.green[100]
                        : Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: status == 'Sedang Diantar'
                          ? Colors.green[800]
                          : Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow(Icons.person, 'Nama: ${order['nama']}'),
            SizedBox(height: 12),
            _buildInfoRow(
                Icons.location_on_outlined, 'Alamat: ${order['alamat']}'),
            SizedBox(height: 8),
            _buildProductsList(products),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
            _buildActionButtons(status, order['orderId']),
          ],
        ),
      ),
    );
  }

  
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsList(List<dynamic> products) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey[600]),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order:',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              ...products.map((product) {
       
                bool isNonHalal = product['kategori'] == 'Non-halal';
                
                return Padding(
                  padding: EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    '• ${product['name']} (${product['jumlah']}x)',
                    style: TextStyle(
                      fontSize: 13,
                      color: isNonHalal ? Colors.red : Colors.grey[600],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(String status, String orderId) {
    if (status == 'sedang diproses') {
      return Padding(
        padding: EdgeInsets.only(top: 16),
        child: ElevatedButton(
          onPressed: () => _updateOrderStatus(orderId, 'Sedang Diantar'),
          child: Text('Sedang Diantar'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue,
          ),
        ),
      );
    } else if (status == 'Sedang Diantar') {
      return Padding(
        padding: EdgeInsets.only(top: 16),
        child: ElevatedButton(
          onPressed: () =>
              _updateOrderStatus(orderId, 'Pesanan Telah Diterima'),
          child: Text('Pesanan Telah Diterima'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.green,
          ),
        ),
      );
    }
    return SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Unduh Laporan'),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _downloadReport,
          ),
        ],
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
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            DropdownButton<String>(
                              value: _selectedFilter,
                              items: ['Hari', 'Bulan', 'Tahun'].map((String filter) {
                                return DropdownMenuItem<String>(
                                  value: filter,
                                  child: Text(filter),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedFilter = value!;
                                });
                                _fetchOrders();
                              },
                            ),
                            ElevatedButton(
                              onPressed: () {
                                // Pilih tanggal untuk filter
                                showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2101),
                                ).then((selectedDate) {
                                  if (selectedDate != null) {
                                    setState(() {
                                      _selectedDate = selectedDate;
                                    });
                                    _fetchOrders();
                                  }
                                });
                              },
                              child: Text('Pilih Tanggal'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                         child: _allOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Tidak ada penjualan',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _allOrders.length,
                            itemBuilder: (context, index) {
                              return _buildOrderCard(_allOrders[index]);
                            },
                          ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _allOrders.length,
                          itemBuilder: (context, index) {
                            return _buildOrderCard(_allOrders[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}