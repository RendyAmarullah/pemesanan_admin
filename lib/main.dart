import 'package:flutter/material.dart';
import 'package:pemesanan_web/LoginScreen.dart';
import 'package:pemesanan_web/DataBarangScreen.dart';
import 'package:pemesanan_web/DataPelanggan.dart';
import 'package:pemesanan_web/RiwayatPesanan.dart';
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

// AuthWrapper widget yang memeriksa status login pengguna
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

// Main Layout dengan Sidebar yang persisten
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

  // Appwrite configuration
  final String collectionId = '681aa352000e7e9b76b5';
  final String projectId = '681aa0b70002469fc157';
  final String databaseId = '681aa33a0023a8c7eb1f';
  final String bucketId = '681aa16f003054da8969';
  final String usersCollectionId = '684083800031dfaaecad';

  late Client _client;
  late Storage _storage;
  late Account _account;
  late Databases _databases;
  models.Session? _session;
  models.User? _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeAppwrite();
    _loadProfileData();
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
        // Load profile image
        try {
          final profileDoc = await _databases.getDocument(
            databaseId: databaseId,
            collectionId: collectionId,
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
              collectionId: collectionId,
              documentId: userId,
              data: {'profile_image': null},
            );
          }
        }

        // Load user name
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
          collectionId: collectionId,
          documentId: user.$id,
          data: {'profile_image': fileId},
        );
      } catch (e) {
        if (e.toString().contains('document_not_found')) {
          await _databases.createDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: user.$id,
            data: {'profile_image': fileId},
          );
        }
      }
    }
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

                // Navigation Menu
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

                // Logout Button
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

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top App Bar
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
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFF1976D2),
                            child: _profileImageUrl != null
                                ? CircleAvatar(
                                    radius: 16,
                                    backgroundImage:
                                        NetworkImage(_profileImageUrl!),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            _userName ?? 'Guest',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Page Content
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

  Widget _buildDashboardContent() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
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
                  value: '150',
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

          // Recent Activity
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
                          'Pelanggan baru "John Doe" telah ditambahkan',
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
