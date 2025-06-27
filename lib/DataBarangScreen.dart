import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class DataBarangScreen extends StatefulWidget {
  @override
  _DataBarangScreenState createState() => _DataBarangScreenState();
}

class _DataBarangScreenState extends State<DataBarangScreen> {
  late Client client;
  late Databases databases;
  late Account account;
  late Storage _storage;
  String userId = '';
  String projectId = '681aa0b70002469fc157';
  String databaseId = '681aa33a0023a8c7eb1f';
  String productsCollectionId = '68407bab00235ecda20d';
  final String bucketId = '681aa16f003054da8969';
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  File? _imageFile;
  String _productImageUrl = '';
  TextEditingController searchController = TextEditingController();

  List<String> categories = [
    'Makanan',
    'Minuman',
    'Bunsik',
    'Non-halal',
    'Barang',
    'Beauty',
    'Snack',
    'Frozen',
    'Mie'
  ];
  List<String> status = ['Aktif', 'Nonaktif'];

  String selectedCategory = 'Makanan';
  String selectedStatus = 'Aktif';

  @override
  void initState() {
    super.initState();
    client = Client();
    client.setEndpoint('https://cloud.appwrite.io/v1').setProject(projectId);
    databases = Databases(client);
    account = Account(client);
    _storage = Storage(client);
    _loadProductsData();
  }

  Future<void> _addProduct(
      String name, String price, String category, String deskripsi) async {
    try {
      final parsedPrice = int.tryParse(price);
      if (parsedPrice == null) {
        print("Masukkan harga yang valid");
        return;
      }

      await databases.createDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: 'unique()',
        data: {
          'name': name,
          'price': parsedPrice,
          'productImageUrl': _productImageUrl,
          'deskripsi': deskripsi,
          'status': selectedStatus,
          'category': category,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      _loadProductsData();
    } catch (e) {
      print("Error adding product: $e");
    }
  }

  Future<void> _editProduct(String productId, String name, String price,
      String category, String deskripsi) async {
    try {
      final parsedPrice = int.tryParse(price);
      if (parsedPrice == null) {
        print("Invalid price input. Please enter a valid number.");
        return;
      }

      String validProductId = productId.isNotEmpty && productId.length <= 36
          ? productId
          : ID.unique();

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: validProductId,
        data: {
          'name': name,
          'price': parsedPrice,
          'category': category,
          'deskripsi': deskripsi,
          'productImageUrl': _productImageUrl,
        },
      );
      _loadProductsData();
    } catch (e) {
      print("Error editing product: $e");
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

      setState(() {
        _productImageUrl = fileViewUrl;
      });
    } catch (e) {
      print("Error uploading image: $e");
    }
  }

  Future<void> _loadProductsData() async {
    try {
      final response = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
      );

      setState(() {
        products = response.documents.map((doc) {
          return {
            'productName': doc.data['name'] ?? 'No name',
            'price': (doc.data['price'] != null && doc.data['price'] is int)
                ? doc.data['price'].toString()
                : 'No price',
            'category': doc.data['category'] ?? 'No category',
            'status': doc.data['status'] ?? 'Aktif',
            'productId': doc.$id,
            'imageUrl': doc.data['productImageUrl'] ?? '',
          };
        }).toList();

        filteredProducts = List.from(products);
      });
    } catch (e) {
      print("Error loading products data: $e");
    }
  }

  void _filterData() {
    setState(() {
      filteredProducts = products
          .where((product) =>
              product['productName']!
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase()) ||
              product['category']!
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase()) ||
              product['price']!
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase()))
          .toList();

      filteredProducts = filteredProducts.where((product) {
        return product['category'] == selectedCategory;
      }).toList();
    });
  }

  Future<void> _showProductDialog({Map<String, dynamic>? product}) async {
    final TextEditingController nameController =
        TextEditingController(text: product?['productName']);
    final TextEditingController priceController =
        TextEditingController(text: product?['price']);
    final TextEditingController categoryController =
        TextEditingController(text: product?['category']);
    final TextEditingController deskripsiController =
        TextEditingController(text: product?['deskripsi']);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(product == null ? 'Tambah Produk' : 'Edit Produk'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Nama Produk'),
                ),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(labelText: 'Harga'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: deskripsiController,
                  decoration: InputDecoration(labelText: 'Deskripsi'),
                ),
                DropdownButton<String>(
                  value: selectedCategory,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedCategory = newValue!;
                    });
                  },
                  items:
                      categories.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _pickImage,
                  child:
                      Text(product == null ? 'Pilih Gambar' : 'Ganti Gambar'),
                ),
                _imageFile != null
                    ? Image.file(_imageFile!,
                        width: 150, height: 150, fit: BoxFit.cover)
                    : SizedBox(),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Simpan'),
              onPressed: () {
                if (product == null) {
                  _addProduct(
                    nameController.text,
                    priceController.text,
                    selectedCategory,
                    deskripsiController.text,
                  );
                } else {
                  _editProduct(
                    product['productId'],
                    nameController.text,
                    priceController.text,
                    selectedCategory,
                    deskripsiController.text,
                  );
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Cari Data',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _filterData(),
            ),
            SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedCategory,
              onChanged: (String? newValue) {
                setState(() {
                  selectedCategory = newValue!;
                });
                _filterData();
              },
              items: categories.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 1.0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width),
                        child: DataTable(
                          columnSpacing: 30.0,
                          columns: const [
                            DataColumn(label: Text('Gambar')),
                            DataColumn(label: Text('Nama Barang')),
                            DataColumn(label: Text('Harga')),
                            DataColumn(label: Text('Kategori')),
                            DataColumn(label: Text('Ubah')),
                          ],
                          rows: filteredProducts.map((product) {
                            return DataRow(cells: [
                              DataCell(product['imageUrl'] != ''
                                  ? Image.network(product['imageUrl'],
                                      width: 150, height: 150)
                                  : const Icon(Icons.image, size: 50)),
                              DataCell(Text(product['productName'])),
                              DataCell(Text(product['price'])),
                              DataCell(Text(product['category'])),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _showProductDialog(product: product),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
