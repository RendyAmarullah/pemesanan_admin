
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:image_picker/image_picker.dart';
import 'package:pemesanan_web/DataBarangScreen.dart';
import 'package:pemesanan_web/DataPelanggan.dart';
import 'package:pemesanan_web/RiwayatPesanan.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  HomeScreen({required this.userId});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Account? account;
  Client client = Client();
  Databases? databases;
  String? _userName;
  String? _userEmail;
  String selectedPage = 'Dashboard';
  String? _profileImageUrl;
  File? _imageFile;
  final String profil = '684083800031dfaaecad';
  final String collectionId = '681aa352000e7e9b76b5';
  final String projectId = '681aa0b70002469fc157';
  final String databaseId = '681aa33a0023a8c7eb1f';
  final String bucketId = '681aa16f003054da8969';
  late Client _client;
  late Storage _storage;
  late Account _account;
  late Databases _databases;
  bool _isLoading = true;
  models.Session? _session;
  models.User? _currentUser;
  final String usersCollectionId = '684083800031dfaaecad';



  @override
  void initState() {
    super.initState();
    _client = Client();
    _client
        .setEndpoint('https://fra.cloud.appwrite.io/v1')
        .setProject(projectId)
        .setSelfSigned(status: true);

    _storage = Storage(_client);
    _account = Account(_client);
    _databases = Databases(_client);
    client.setEndpoint('https://cloud.appwrite.io/v1').setProject('681aa0b70002469fc157');
    account = Account(client);
    databases = Databases(client);
    _loadProfileData();
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _uploadImage();
    }
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print("🔄 Starting to load profile data...");

      
      try {
        _session = await _account.getSession(sessionId: 'current');
        print("✅ Session loaded successfully");
      } catch (e) {
        print("❌ Error loading session: $e");
        setState(() {
          _isLoading = false;
        });
        return;
      }

     
      try {
        _currentUser = await _account.get();
        print("✅ Current user loaded: ${_currentUser?.$id}");
        print("📧 User email: ${_currentUser?.email}");
        print("👤 User name from auth: ${_currentUser?.name}");

        
        setState(() {
          _userEmail = _currentUser?.email;
          if (_currentUser?.name != null && _currentUser!.name.isNotEmpty) {
            _userName = _currentUser!.name;
          }
        });
      } catch (e) {
        print("❌ Error loading current user: $e");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final userId = _currentUser?.$id;
      if (userId != null) {
      
        try {
          print(
              "🖼️ Trying to load profile image from collection: $collectionId");
          final profileDoc = await _databases.getDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: userId,
          );

          final profileImageId = profileDoc.data['profile_image'];
          if (profileImageId != null) {
            final fileViewUrl =
                'https://fra.cloud.appwrite.io/v1/storage/buckets/$bucketId/files/$profileImageId/view?project=$projectId';
            setState(() {
              _profileImageUrl = fileViewUrl;
            });
            print("✅ Profile image loaded successfully");
          } else {
            print("ℹ️ No profile image found in document");
          }
        } catch (e) {
          print("❌ Error loading profile image: $e");
          
          if (e.toString().contains('document_not_found')) {
            try {
              await _databases.createDocument(
                databaseId: databaseId,
                collectionId: collectionId,
                documentId: userId,
                data: {'profile_image': null},
              );
              print("✅ Created empty profile document");
            } catch (createError) {
              print("❌ Error creating profile document: $createError");
            }
          }
        }

        
        try {
          print(
              "👤 Trying to load user name from collection: $usersCollectionId");
          final userNameDoc = await _databases.getDocument(
            databaseId: databaseId,
            collectionId: usersCollectionId,
            documentId: userId,
          );

          final name = userNameDoc.data['name'];
          if (name != null && name.toString().isNotEmpty) {
            setState(() {
              _userName = name.toString();
            });
            print("✅ User name loaded from database: $name");
          } else {
            print("ℹ️ Name field is empty in users collection");
          }
        } catch (e) {
          print("❌ Error loading user name from database: $e");

          
          if (e.toString().contains('document_not_found')) {
            try {
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

              setState(() {
                _userName = userData['name'];
              });

              print("✅ Created user document with name: ${userData['name']}");
            } catch (createError) {
              print("❌ Error creating user document: $createError");
            }
          }
        }
      }

      setState(() {
        _isLoading = false;
      });

      print("🎉 Profile data loading completed");
      print("Final state - Name: $_userName, Email: $_userEmail");
    } catch (e) {
      print('❌ General error loading profile data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    try {
      final fileId = DateTime.now().millisecondsSinceEpoch.toString();
      final bucketId = '681aa16f003054da8969';

      final inputFile = InputFile.fromPath(path: _imageFile!.path);

      final result = await _storage.createFile(
        bucketId: bucketId,
        file: inputFile,
        fileId: fileId,
      );

      final fileViewUrl =
          'https://fra.cloud.appwrite.io/v1/storage/buckets/$bucketId/files/${result.$id}/view?project=$projectId';

      setState(() {
        _profileImageUrl = fileViewUrl;
      });

      await _saveProfileImage(result.$id);
    } catch (e) {
      print('Error uploading image: $e');
    }
  }

  Future<void> _saveProfileImage(String fileId) async {
    final user = await _account.get();
    if (user != null) {
      try {
        final document = await _databases.getDocument(
          databaseId: databaseId,
          collectionId: collectionId,
          documentId: user.$id,
        );

        await _databases.updateDocument(
          databaseId: databaseId,
          collectionId: collectionId,
          documentId: user.$id,
          data: {'profile_image': fileId},
        );
        print("Profile image updated in the database successfully.");
      } catch (e) {
        if (e.toString().contains('document_not_found')) {
          await _databases.createDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: user.$id,
            data: {'profile_image': fileId},
          );
          print("Profile image saved to the database successfully.");
        } else {
          print('Error: $e');
        }
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        backgroundColor: Colors.blue,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: Icon(Icons.exit_to_app),
              onPressed: () {
              
              },
            ),
          )
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildBody(),
    );
  }

  
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
         
          UserAccountsDrawerHeader(
            accountName: Text(_userName ?? 'Guest'),
            accountEmail: Text(_userEmail ?? 'No email'),
            currentAccountPicture: CircleAvatar(
                radius: 60,
                          child: _profileImageUrl != null
                              ? CircleAvatar(
                                  radius: 60,
                                  backgroundImage:
                                      NetworkImage(_profileImageUrl!))
                              : const CircleAvatar(
                                  radius: 60, child: Icon(Icons.person)),
            ),
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
          ),
         
          ListTile(
            leading: Icon(Icons.dashboard),
            title: Text('Dashboard'),
            onTap: () {
              setState(() {
                selectedPage = 'Dashboard';
              });
              Navigator.pop(context); 
            },
          ),
          ListTile(
            leading: Icon(Icons.people),
            title: Text('Data Pelanggan'),
            onTap: () {
              setState(() {
                selectedPage = 'Data Pelanggan';
              });
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DataPelangganScreen(),
                  ),
                );

            },
          ),
          ListTile(
            leading: Icon(Icons.shopping_cart),
            title: Text('Data Barang'),
            onTap: () {
              setState(() {
                selectedPage = 'Data Barang';
              });
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DataBarangScreen(),  
                  ),
                );  
            },
          ),
          ListTile(
            leading: Icon(Icons.history),
            title: Text('Riwayat Penjualan'),
            onTap: () {
              setState(() {
                selectedPage = 'Riwayat Penjualan';
              });
             Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RiwayatPesanan(userId: widget.userId,),
                  ),
                );
            },
          ),
        ],
      ),
    );
  }

  
  Widget _buildBody() {
    switch (selectedPage) {
      case 'Dashboard':
        return _buildDashboard();
      case 'Data Pelanggan':
        return _buildDataPelanggan();
      case 'Data Barang':
        return _buildDataBarang();
      case 'Riwayat Penjualan':
        return _buildRiwayatPenjualan();
      default:
        return _buildDashboard();
    }
  }


  Widget _buildDashboard() {
    return Center(
      child: Text(
        'Welcome to the Dashboard!',
        style: TextStyle(fontSize: 24),
      ),
    );
  }

 
  Widget _buildDataPelanggan() {
    return Center(
      child: Text(
        'Data Pelanggan Content Goes Here',
        style: TextStyle(fontSize: 24),
      ),
    );
  }


  Widget _buildDataBarang() {
    return Center(
      child: Text(
        'Data Barang Content Goes Here',
        style: TextStyle(fontSize: 24),
      ),
    );
  }


  Widget _buildRiwayatPenjualan() {
    return Center(
      child: Text(
        'Riwayat Penjualan Content Goes Here',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}
