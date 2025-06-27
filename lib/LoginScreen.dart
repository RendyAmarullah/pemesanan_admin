import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:pemesanan_web/main.dart';
import 'HomeScreen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
   
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final Client client = Client();
  late Account account;
  late Databases database;

  final String projectId = '681aa0b70002469fc157';
  final String endpoint = 'https://cloud.appwrite.io/v1';
  final String databaseId = '681aa33a0023a8c7eb1f';
  final String collectionId = '684083800031dfaaecad';

  @override
  void initState() {
    super.initState();

    client.setEndpoint(endpoint).setProject(projectId);
    account = Account(client);
    database = Databases(client);
  }
  Future<void> _login() async {
    if (_isLoading) return;
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email dan password harus diisi')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final session = await account.createEmailPasswordSession(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      print("Login berhasil, session ID: ${session.$id}");
      final user = await account.get();
      print("User info: ${user.email}");
      final response = await database.getDocument(
        databaseId: databaseId,
        collectionId: collectionId,
        documentId: user.$id,
      );
      final roles = List<String>.from(response.data['roles'] ?? []);

      if (roles.contains('admin')) {
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainLayout(userId: user.$id),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Akses ditolak: Anda bukan admin')),
        );
      }
    } on AppwriteException catch (e) {
      print("Login error: ${e.message} (Code: ${e.code})");
      String errorMessage;
      switch (e.code) {
        case 401:
          errorMessage = 'Email atau password salah';
          break;
        case 429:
          errorMessage = 'Terlalu banyak percobaan login. Coba lagi nanti';
          break;
        default:
          errorMessage = 'Login gagal: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      print("Unexpected error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan tidak terduga')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Image.asset(
                "images/logosignup.png",
                height: 200,
              ),
              SizedBox(height: 40),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: Colors.black),
                decoration: _inputDecoration("Email"),
                enabled: !_isLoading,
              ),
              SizedBox(height: 20),

              TextFormField(
                obscureText: true,
                controller: _passwordController,
                style: TextStyle(color: Colors.black),
                decoration: _inputDecoration("Password"),
                enabled: !_isLoading,
              ),
              SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: StadiumBorder(),
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "MASUK",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.black54),
      filled: true,
      fillColor: Colors.grey[300],
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: Colors.blue, width: 2),
      ),
    );
  }
}
