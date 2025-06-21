import 'package:flutter/material.dart';
import 'package:pemesanan_web/LoginScreen.dart';
import 'package:pemesanan_web/HomeScreen.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:shared_preferences/shared_preferences.dart';

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
      final session = await account.getSession(sessionId: 'current'); // Cek sesi aktif
      if (session != null) {
        final user = await account.get();
        final userId = user.$id;

        // Menyimpan userId ke SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userId);

        // Mengambil data roles pengguna
        final response = await databases.getDocument(
          databaseId: '681aa33a0023a8c7eb1f',
          collectionId: '684083800031dfaaecad',
          documentId: userId,
        );

        final roles = List<String>.from(response.data['roles'] ?? []);

        return {'user': user, 'isKaryawan': roles.contains('karyawan')}; // Periksa apakah pengguna memiliki role karyawan
      }
      return null; // Tidak ada sesi aktif
    } catch (e) {
      print('Error checking login status: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>( // FutureBuilder untuk memeriksa status login
      future: checkLoginStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()), // Loading
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          final userData = snapshot.data!;
          final user = userData['user'] as models.User;
          final isKaryawan = userData['isKaryawan'] as bool;

          // Arahkan pengguna ke HomeScreen jika sudah login
          if (isKaryawan) {
            return HomeScreen(userId: user.$id);
          } else {
            return HomeScreen(userId: user.$id); // Atau halaman lain untuk non-karyawan
          }
        } else {
          // Tampilkan LoginScreen jika tidak ada sesi aktif
          return LoginScreen();
        }
      },
    );
  }
}
