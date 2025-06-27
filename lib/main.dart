import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:pemesanan_web/LoginScreen.dart';
import 'package:pemesanan_web/DataBarangScreen.dart';
import 'package:pemesanan_web/DataPelanggan.dart';
import 'package:pemesanan_web/RiwayatPesanan.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

Client client = Client()
  ..setEndpoint('https://cloud.appwrite.io/v1')
  ..setProject('681aa0b70002469fc157')
  ..setSelfSigned(status: true);
Account account = Account(client);
final Databases databases = Databases(client);

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Login',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
  }

  Future<Map<String, dynamic>?> checkLoginStatus() async {
    try {
      final session = await account.getSession(sessionId: 'current');
      if (session != null) {
        final user = await account.get();
        final userId = user.$id;

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userId);

        final response = await databases.getDocument(
          databaseId: '681aa33a0023a8c7eb1f',
          collectionId: '684083800031dfaaecad',
          documentId: userId,
        );

        final roles = List<String>.from(response.data['roles'] ?? []);

        return {'user': user, 'isKaryawan': roles.contains('karyawan')};
      }
      return null;
    } catch (e) {
      print('Error checking login status: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: checkLoginStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          final userData = snapshot.data!;
          final user = userData['user'] as models.User;

          return MainLayout(userId: user.$id);
        } else {
          return LoginScreen();
        }
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  final String userId;

  MainLayout({required this.userId});

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  String selectedPage = 'Dashboard';
  String? _userName;
  String? _userEmail;
  String? _profileImageUrl;
  File? _imageFile;
  bool _isLoading = true;
  int _totalCustomers = 0;
  int _totalBarang = 0;
  int _totalPenjualan = 0;
  double _totalPendapatan = 0;
  final String userCollectionId = '681aa352000e7e9b76b5';
  final String projectId = '681aa0b70002469fc157';
  final String databaseId = '681aa33a0023a8c7eb1f';
  final String bucketId = '681aa16f003054da8969';
  final String usersCollectionId = '684083800031dfaaecad';
  final String productKoleksiId = '68407bab00235ecda20d';
  int _selectedYear = DateTime.now().year;
  Map<int, int> _penjualanPerBulan = {};
  Map<int, double> _pendapatanPerBulan = {};
  late Client _client;
  late Storage _storage;
  late Account _account;
  late Databases _databases;
  models.Session? _session;
  models.User? _currentUser;
  bool _showSalesChart = true;

  final List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des'
  ];

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _ambilPenjualan(_selectedYear),
      _ambilPendapatan(_selectedYear),
    ]);
    setState(() => _isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    _initializeAppwrite();
    _loadProfileData();
    _fetchCustomerCount();
    _ambilTotalBarang();
    _ambilPenjualan(2025);
    _ambilPendapatan(2025);
  }

  void _initializeAppwrite() {
    _client = Client();
    _client
        .setEndpoint('https://fra.cloud.appwrite.io/v1')
        .setProject(projectId)
        .setSelfSigned(status: true);

    _storage = Storage(_client);
    _account = Account(_client);
    _databases = Databases(_client);
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });
    try {
      _session = await _account.getSession(sessionId: 'current');
      _currentUser = await _account.get();

      if (!mounted) return;

      setState(() {
        _userEmail = _currentUser?.email;
        if (_currentUser?.name != null && _currentUser!.name.isNotEmpty) {
          _userName = _currentUser!.name;
        }
      });
      final userId = _currentUser?.$id;
      if (userId != null) {
        try {
          final profileDoc = await _databases.getDocument(
            databaseId: databaseId,
            collectionId: userCollectionId,
            documentId: userId,
          );
          final profileImageId = profileDoc.data['profile_image'];
          if (profileImageId != null && mounted) {
            final fileViewUrl =
                'https://fra.cloud.appwrite.io/v1/storage/buckets/$bucketId/files/$profileImageId/view?project=$projectId';
            setState(() {
              _profileImageUrl = fileViewUrl;
            });
          }
        } catch (e) {
          if (e.toString().contains('document_not_found')) {
            await _databases.createDocument(
              databaseId: databaseId,
              collectionId: userCollectionId,
              documentId: userId,
              data: {'profile_image': null},
            );
          }
        }
        try {
          final userNameDoc = await _databases.getDocument(
            databaseId: databaseId,
            collectionId: usersCollectionId,
            documentId: userId,
          );

          final name = userNameDoc.data['name'];
          if (name != null && name.toString().isNotEmpty && mounted) {
            setState(() {
              _userName = name.toString();
            });
          }
        } catch (e) {
          if (e.toString().contains('document_not_found')) {
            final userData = {
              'name': _currentUser?.name ??
                  _currentUser?.email?.split('@')[0] ??
                  'User',
              'email': _currentUser?.email ?? '',
              'userId': userId,
            };
            await _databases.createDocument(
              databaseId: databaseId,
              collectionId: usersCollectionId,
              documentId: userId,
              data: userData,
            );

            if (mounted) {
              setState(() {
                _userName = userData['name'];
              });
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _ambilPenjualan(int tahun) async {
    setState(() {
      _isLoading = true;
      _penjualanPerBulan.clear();
    });
    try {
      int totalPenjualan = 0;
      for (int bulan = 1; bulan <= 12; bulan++) {
        final result = await _databases.listDocuments(
          databaseId: databaseId,
          collectionId: '684b33e80033b767b024',
          queries: [
            Query.greaterThanEqual(
                'tanggal', DateTime(tahun, bulan, 1).toIso8601String()),
            Query.lessThan(
                'tanggal', DateTime(tahun, bulan + 1, 1).toIso8601String()),
          ],
        );
        int jumlahPenjualan = result.documents.length;
        totalPenjualan += jumlahPenjualan;
        _penjualanPerBulan[bulan] = jumlahPenjualan;
      }

      setState(() {
        _totalPenjualan = totalPenjualan;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching penjualan per tahun: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _ambilPendapatan(int tahun) async {
    setState(() {
      _isLoading = true;
    });

    try {
      double totalpendapatan = 0;
      for (int bulan = 1; bulan <= 12; bulan++) {
        final result = await _databases.listDocuments(
          databaseId: databaseId,
          collectionId: '684b33e80033b767b024',
          queries: [
            Query.equal('status', 'selesai'),
            Query.greaterThanEqual(
                'tanggal', DateTime(tahun, bulan, 1).toIso8601String()),
            Query.lessThan(
                'tanggal', DateTime(tahun, bulan + 1, 1).toIso8601String()),
          ],
        );

        double totalRevenue = 0;
        for (var doc in result.documents) {
          totalpendapatan += doc.data['total'] ?? 0.0;
        }
      }

      setState(() {
        _totalPendapatan = totalpendapatan;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching pendapatan count: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _ambilTotalBarang() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: productKoleksiId,
      );

      setState(() {
        _totalBarang = result.documents.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching barang count: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCustomerCount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        queries: [
          Query.equal('roles', 'pelanggan'),
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

  Future<void> _pickImage() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _imageFile = File(result.files.single.path!);
      });
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    try {
      final fileId = DateTime.now().millisecondsSinceEpoch.toString();
      final inputFile = InputFile.fromPath(path: _imageFile!.path);

      final result = await _storage.createFile(
        bucketId: bucketId,
        file: inputFile,
        fileId: fileId,
      );

      final fileViewUrl =
          'https://fra.cloud.appwrite.io/v1/storage/buckets/$bucketId/files/${result.$id}/view?project=$projectId';

      if (mounted) {
        setState(() {
          _profileImageUrl = fileViewUrl;
        });
      }

      await _saveProfileImage(result.$id);
    } catch (e) {
      print('Error uploading image: $e');
    }
  }

  Future<void> _saveProfileImage(String fileId) async {
    final user = await _account.get();
    if (user != null) {
      try {
        await _databases.updateDocument(
          databaseId: databaseId,
          collectionId: userCollectionId,
          documentId: user.$id,
          data: {'profile_image': fileId},
        );
      } catch (e) {
        if (e.toString().contains('document_not_found')) {
          await _databases.createDocument(
            databaseId: databaseId,
            collectionId: userCollectionId,
            documentId: user.$id,
            data: {'profile_image': fileId},
          );
        }
      }
    }
  }

  Widget _buildSalesBarChart() {
    List<BarChartGroupData> barGroups = List.generate(12, (index) {
      int month = index + 1;
      return BarChartGroupData(
        x: month,
        barRods: [
          BarChartRodData(
            toY: (_penjualanPerBulan[month] ?? 0).toDouble(),
            color: Colors.blue,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (_penjualanPerBulan.values.isEmpty
                ? 10
                : _penjualanPerBulan.values
                    .reduce((a, b) => a > b ? a : b)
                    .toDouble()) *
            1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String monthName = _monthNames[group.x.toInt() - 1];
              return BarTooltipItem(
                '$monthName\n${rod.toY.round()}',
                TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt() - 1;
                if (index >= 0 && index < _monthNames.length) {
                  return Text(_monthNames[index],
                      style: TextStyle(fontSize: 12));
                }
                return Text('');
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildRevenueLineChart() {
    List<FlSpot> spots = List.generate(12, (index) {
      int month = index + 1;
      return FlSpot(month.toDouble(), _pendapatanPerBulan[month] ?? 0);
    });

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(_formatCurrency(value),
                    style: TextStyle(fontSize: 10));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt() - 1;
                if (index >= 0 && index < _monthNames.length) {
                  return Text(_monthNames[index],
                      style: TextStyle(fontSize: 12));
                }
                return Text('');
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minX: 1,
        maxX: 12,
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.green,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                int monthIndex = touchedSpot.x.toInt() - 1;
                String monthName = _monthNames[monthIndex];
                return LineTooltipItem(
                  '$monthName\nRp ${_formatCurrency(touchedSpot.y)}',
                  TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  void _logout() async {
    try {
      await _account.deleteSession(sessionId: 'current');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('Error logging out: $e');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            color: Color(0xFF1976D2),
            child: Column(
              children: [
                // Profile Section
                Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            child: _profileImageUrl != null
                                ? CircleAvatar(
                                    radius: 38,
                                    backgroundImage:
                                        NetworkImage(_profileImageUrl!),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Color(0xFF1976D2),
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.camera_alt,
                                  color: Color(0xFF1976D2),
                                  size: 20,
                                ),
                                onPressed: _pickImage,
                                padding: EdgeInsets.all(4),
                                constraints: BoxConstraints(
                                  minWidth: 30,
                                  minHeight: 30,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      Text(
                        _userName ?? 'Guest',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        _userEmail ?? 'No email',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        _buildMenuTile(
                          icon: Icons.dashboard,
                          title: 'Dashboard',
                          isSelected: selectedPage == 'Dashboard',
                          onTap: () {
                            setState(() {
                              selectedPage = 'Dashboard';
                            });
                          },
                        ),
                        _buildMenuTile(
                          icon: Icons.people,
                          title: 'Data Pelanggan',
                          isSelected: selectedPage == 'Data Pelanggan',
                          onTap: () {
                            setState(() {
                              selectedPage = 'Data Pelanggan';
                            });
                          },
                        ),
                        _buildMenuTile(
                          icon: Icons.shopping_cart,
                          title: 'Data Barang',
                          isSelected: selectedPage == 'Data Barang',
                          onTap: () {
                            setState(() {
                              selectedPage = 'Data Barang';
                            });
                          },
                        ),
                        _buildMenuTile(
                          icon: Icons.history,
                          title: 'Riwayat Penjualan',
                          isSelected: selectedPage == 'Riwayat Penjualan',
                          onTap: () {
                            setState(() {
                              selectedPage = 'Riwayat Penjualan';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Color(0xFF1976D2),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.exit_to_app, size: 18),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  color: Colors.grey[100],
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        selectedPage,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Spacer(),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.grey[50],
                    child: _buildPageContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
                SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPageTitle() {
    return selectedPage;
  }

  Widget _buildPageContent() {
    switch (selectedPage) {
      case 'Dashboard':
        return _buildDashboardContent();
      case 'Data Pelanggan':
        return DataPelangganScreen();
      case 'Data Barang':
        return DataBarangScreen();
      case 'Riwayat Penjualan':
        return RiwayatPesanan(userId: widget.userId);
      default:
        return _buildDashboardContent();
    }
  }

  @override
  Widget _buildDashboardContent() {
    return Scaffold(
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: Padding(
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
                            value: '$_totalBarang',
                            icon: Icons.inventory,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 16,
                    ),
                    Card(
                      margin: EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tahun: $_selectedYear',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.chevron_left),
                                  onPressed: () {
                                    setState(() => _selectedYear--);
                                    _loadData();
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.chevron_right),
                                  onPressed: () {
                                    setState(() => _selectedYear++);
                                    _loadData();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 5),
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _selectedYear =
                              int.tryParse(value) ?? DateTime.now().year;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Masukkan Tahun',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        _ambilPenjualan(_selectedYear);
                      },
                      child: Text('Pilih Tahun'),
                    ),
                    SizedBox(height: 10),
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
                      child: Column(
                        children: [
                          Card(
                            margin: EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => setState(
                                          () => _showSalesChart = true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _showSalesChart
                                            ? Colors.blue
                                            : Colors.grey[300],
                                        foregroundColor: _showSalesChart
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      child: Text('Penjualan'),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => setState(
                                          () => _showSalesChart = false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: !_showSalesChart
                                            ? Colors.green
                                            : Colors.grey[300],
                                        foregroundColor: !_showSalesChart
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      child: Text('Pendapatan'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Card(
                                  color: Colors.blue[50],
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Icon(Icons.shopping_cart,
                                            size: 32, color: Colors.blue),
                                        SizedBox(height: 8),
                                        Text(
                                          'Total Penjualan',
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12),
                                        ),
                                        Text(
                                          '$_totalPenjualan',
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Card(
                                  color: Colors.green[50],
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Icon(Icons.attach_money,
                                            size: 32, color: Colors.green),
                                        SizedBox(height: 8),
                                        Text(
                                          'Total Pendapatan',
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12),
                                        ),
                                        Text(
                                          'Rp ${_formatCurrency(_totalPendapatan)}',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _showSalesChart
                                        ? 'Grafik Penjualan per Bulan'
                                        : 'Grafik Pendapatan per Bulan',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 16),
                                  Container(
                                    height: 300,
                                    child: _isLoading
                                        ? Center(
                                            child: CircularProgressIndicator())
                                        : _showSalesChart
                                            ? _buildSalesBarChart()
                                            : _buildRevenueLineChart(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
