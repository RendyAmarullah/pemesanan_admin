import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';

final client = Client()
  ..setEndpoint('https://fra.cloud.appwrite.io/v1')
  ..setProject('681aa0b70002469fc157')
  ..setSelfSigned(status: true);

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Databases _databases;
  bool _isLoading = true;
  int _totalCustomers = 0;
  int _totalBarang = 0;

  static const String databaseId = '681aa33a0023a8c7eb1f';
  static const String usersCollectionId = 'users_collection_id';
  static const String productsCollectionId = 'product_collection_id';

  @override
  void initState() {
    super.initState();
    _databases = Databases(client);
    _fetchCustomerCount();
    _fetchTotalBarang();
  }

  Future<void> _fetchCustomerCount() async {
    setState(() => _isLoading = true);
    try {
      final result = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        queries: [Query.equal('role', 'pelanggan')],
      );
      setState(() {
        _totalCustomers = result.documents.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching customer count: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTotalBarang() async {
    try {
      final result = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
      );
      setState(() {
        _totalBarang = result.documents.length;
      });
    } catch (e) {
      print('Error fetching total barang: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingIndicator() : _buildDashboardContent(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0072BC),
      elevation: 0,
      title: const Text(
        'Dashboard',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildDashboardContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = [
      _buildStatsCard(
          'Total Pelanggan', '$_totalCustomers', Icons.people, Colors.blue),
      _buildStatsCard(
          'Total Barang', '$_totalBarang', Icons.inventory, Colors.green),
    ];

    return Row(
      children: stats
          .map((card) => Expanded(
              child: Padding(
                  padding: const EdgeInsets.only(right: 16), child: card)))
          .toList(),
    );
  }

  Widget _buildStatsCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIconContainer(icon, color),
          const SizedBox(height: 16),
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800])),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
      String title, String time, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          _buildIconContainer(icon, color, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800])),
                const SizedBox(height: 4),
                Text(time,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconContainer(IconData icon, Color color, {double size = 24}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
