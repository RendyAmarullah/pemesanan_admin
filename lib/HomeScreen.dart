import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:convert';

final client = Client()
  ..setEndpoint('https://fra.cloud.appwrite.io/v1')
  ..setProject('681aa0b70002469fc157')
  ..setSelfSigned(status: true);

class HomeScreen extends StatefulWidget {
  final String userId;

  HomeScreen({required this.userId});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Databases _databases;
  bool _isLoading = true;
  int _totalCustomers = 0;
  final String databaseId = '681aa33a0023a8c7eb1f';
  final String usersCollectionId = 'users_collection_id';
  @override
  void initState() {
    super.initState();
    _initAppwrite();
    _fetchCustomerCount();
  }

  void _initAppwrite() {
    _databases = Databases(client);
  }

  Future<void> _fetchCustomerCount() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Menambahkan filter untuk role pelanggan
      final result = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        queries: [
          Query.equal('role', 'pelanggan'), // Filter role pelanggan
        ],
      );
      setState(() {
        _totalCustomers = result.documents.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching customer count: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0072BC),
        elevation: 0,
        title: Text(
          'Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF1976D2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.dashboard,
                            color: Color(0xFF1976D2),
                            size: 32,
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selamat Datang di Dashboard!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Kelola data pelanggan, barang, dan penjualan Anda dengan mudah',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  // Stats Cards
                  Text(
                    'Ringkasan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),

                  SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatsCard(
                          title: 'Total Pelanggan',
                          value: '$_totalCustomers',
                          icon: Icons.people,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatsCard(
                          title: 'Total Barang',
                          value: '89',
                          icon: Icons.inventory,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatsCard(
                          title: 'Penjualan Hari Ini',
                          value: '25',
                          icon: Icons.shopping_cart,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatsCard(
                          title: 'Total Revenue',
                          value: 'Rp 2.5M',
                          icon: Icons.attach_money,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aktivitas Terkini',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 20),
                          Expanded(
                            child: ListView(
                              children: [
                                _buildActivityItem(
                                  'Pelanggan baru "John dom" telah ditambahkan',
                                  '2 menit yang lalu',
                                  Icons.person_add,
                                  Colors.green,
                                ),
                                _buildActivityItem(
                                  'Barang "Laptop ASUS" stok diperbarui',
                                  '15 menit yang lalu',
                                  Icons.update,
                                  Colors.blue,
                                ),
                                _buildActivityItem(
                                  'Penjualan baru sebesar Rp 1.200.000',
                                  '1 jam yang lalu',
                                  Icons.shopping_bag,
                                  Colors.orange,
                                ),
                                _buildActivityItem(
                                  'Laporan bulanan telah dibuat',
                                  '2 jam yang lalu',
                                  Icons.report,
                                  Colors.purple,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String activity,
    String time,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
