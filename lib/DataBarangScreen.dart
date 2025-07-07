import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appwrite/appwrite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class DataBarangScreen extends StatefulWidget {
  @override
  _DataBarangScreenState createState() => _DataBarangScreenState();
}

class _DataBarangScreenState extends State<DataBarangScreen> {
  late Client client;
  late Databases databases;
  late Storage _storage;

  final String projectId = '681aa0b70002469fc157';
  final String databaseId = '681aa33a0023a8c7eb1f';
  final String productsCollectionId = '68407bab00235ecda20d';
  final String bucketId = '681aa16f003054da8969';

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  File? _imageFile;
  String _productImageUrl = '';
  TextEditingController searchController = TextEditingController();

  final List<String> categories = [
    'All',
    'Market',
    'Minuman',
    'Bunsik',
    'Non-halal',
    'Barang',
    'Beauty'
  ];

  final List<String> categoriesForDialog = [
    'Market',
    'Minuman',
    'Bunsik',
    'Non-halal',
    'Barang',
    'Beauty'
  ];

  String selectedCategory = 'All';
  String selectedCategoryForDialog = 'Market';
  final String selectedStatus = 'Aktif';

  final NumberFormat currencyFormatter = NumberFormat('#,###', 'id_ID');

  String formatRupiah(int amount) {
    return currencyFormatter.format(amount);
  }

  int parsePrice(String priceText) {
    String cleanPrice =
        priceText.replaceAll('.', '').replaceAll(',', '').trim();
    if (cleanPrice.isEmpty) {
      throw FormatException('Harga tidak boleh kosong');
    }
    return int.parse(cleanPrice);
  }

  @override
  void initState() {
    super.initState();
    client = Client();
    client.setEndpoint('https://cloud.appwrite.io/v1').setProject(projectId);
    databases = Databases(client);
    _storage = Storage(client);
    _loadProductsData();
  }

  Future<void> _addProduct(
      String name, String price, String category, String deskripsi) async {
    try {
      if (name.trim().isEmpty) {
        _showErrorSnackBar('Nama produk tidak boleh kosong');
        return;
      }

      if (price.trim().isEmpty) {
        _showErrorSnackBar('Harga tidak boleh kosong');
        return;
      }

      final parsedPrice = parsePrice(price.trim());
      if (parsedPrice < 0) {
        _showErrorSnackBar('Masukkan harga yang valid (angka positif)');
        return;
      }

      if (category.trim().isEmpty) {
        _showErrorSnackBar('Kategori tidak boleh kosong');
        return;
      }

      final productData = {
        'name': name.trim(),
        'price': parsedPrice,
        'category': category,
        'deskripsi': deskripsi.trim(),
        'status': selectedStatus,
        'createdAt': DateTime.now().toIso8601String(),
      };

      if (_productImageUrl.isNotEmpty) {
        productData['productImageUrl'] = _productImageUrl;
      }

      await databases.createDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: ID.unique(),
        data: productData,
      );

      _resetImageState();
      await _loadProductsData();
      _showSuccessSnackBar('Produk berhasil ditambahkan!');
    } catch (e) {
      _showErrorSnackBar('Gagal menambahkan produk: ${e.toString()}');
    }
  }

  Future<void> _editProduct(String productId, String name, String price,
      String category, String deskripsi, String currentImageUrl) async {
    try {
      if (name.trim().isEmpty) {
        _showErrorSnackBar('Nama produk tidak boleh kosong');
        return;
      }

      if (price.trim().isEmpty) {
        _showErrorSnackBar('Harga tidak boleh kosong');
        return;
      }

      final parsedPrice = parsePrice(price.trim());
      if (parsedPrice < 0) {
        _showErrorSnackBar('Masukkan harga yang valid (angka positif)');
        return;
      }

      if (productId.isEmpty) {
        _showErrorSnackBar('ID produk tidak valid');
        return;
      }

      String finalImageUrl =
          _productImageUrl.isNotEmpty ? _productImageUrl : currentImageUrl;

      final updateData = {
        'name': name.trim(),
        'price': parsedPrice,
        'category': category,
        'deskripsi': deskripsi.trim(),
      };

      if (finalImageUrl.isNotEmpty) {
        updateData['productImageUrl'] = finalImageUrl;
      }

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: productId,
        data: updateData,
      );

      _resetImageState();
      await _loadProductsData();
      _showSuccessSnackBar('Produk berhasil diperbarui!');
    } catch (e) {
      _showErrorSnackBar('Gagal memperbarui produk: ${e.toString()}');
    }
  }

  Future<void> _deleteProduct(String productId, String productName) async {
    try {
      if (productId.isEmpty) {
        _showErrorSnackBar('ID produk tidak valid');
        return;
      }

      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: productId,
      );

      await _loadProductsData();
      _showSuccessSnackBar('Produk "$productName" berhasil dihapus!');
    } catch (e) {
      _showErrorSnackBar('Gagal menghapus produk: ${e.toString()}');
    }
  }

  Future<void> _showDeleteConfirmationDialog(
      String productId, String productName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi Hapus'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Apakah Anda yakin ingin menghapus produk ini?'),
                SizedBox(height: 10),
                Text(
                  '"$productName"',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Tindakan ini tidak dapat dibatalkan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Batal',
                style: TextStyle(color: Colors.grey[600]),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Hapus',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteProduct(productId, productName);
              },
            ),
          ],
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _imageFile = File(result.files.single.path!);
        });
        await _uploadImage();
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memilih gambar: ${e.toString()}');
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    try {
      final fileId = 'product_${DateTime.now().millisecondsSinceEpoch}';
      final inputFile = InputFile.fromPath(path: _imageFile!.path);

      final result = await _storage.createFile(
        bucketId: bucketId,
        file: inputFile,
        fileId: fileId,
      );

      final fileViewUrl =
          'https://cloud.appwrite.io/v1/storage/buckets/$bucketId/files/${result.$id}/view?project=$projectId';

      setState(() {
        _productImageUrl = fileViewUrl;
      });
    } catch (e) {
      _showErrorSnackBar('Gagal mengupload gambar: ${e.toString()}');
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
            'price': (doc.data['price'] != null)
                ? formatRupiah(doc.data['price'])
                : '0',
            'rawPrice': doc.data['price'] ?? 0,
            'category': doc.data['category'] ?? 'No category',
            'status': doc.data['status'] ?? 'Aktif',
            'productId': doc.$id,
            'imageUrl': doc.data['productImageUrl'] ?? '',
            'deskripsi': doc.data['deskripsi'] ?? '',
          };
        }).toList();

        filteredProducts = List.from(products);
      });
    } catch (e) {
      _showErrorSnackBar('Gagal memuat data produk: ${e.toString()}');
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

      if (selectedCategory != 'All') {
        filteredProducts = filteredProducts.where((product) {
          return product['category'] == selectedCategory;
        }).toList();
      }
    });
  }

  void _resetImageState() {
    _imageFile = null;
    _productImageUrl = '';
  }

  Widget _buildImageContainer(String imageUrl, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: size * 0.5,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              )
            : Container(
                color: Colors.grey.shade200,
                child: Icon(
                  Icons.image,
                  color: Colors.grey,
                  size: size * 0.5,
                ),
              ),
      ),
    );
  }

  Future<void> _showProductDialog({Map<String, dynamic>? product}) async {
    final TextEditingController nameController =
        TextEditingController(text: product?['productName'] ?? '');
    final TextEditingController priceController = TextEditingController(
        text: product != null ? product['rawPrice'].toString() : '');
    final TextEditingController deskripsiController =
        TextEditingController(text: product?['deskripsi'] ?? '');

    _resetImageState();

    String currentImageUrl = product?['imageUrl'] ?? '';

    if (product != null &&
        product['category'] != null &&
        categoriesForDialog.contains(product['category'])) {
      selectedCategoryForDialog = product['category'];
    } else {
      selectedCategoryForDialog = categoriesForDialog.first;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.all(20),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.5,
                height: MediaQuery.of(context).size.height * 0.8,
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product == null ? 'Tambah Produk' : 'Edit Produk',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: 'Nama Produk *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: priceController,
                              decoration: InputDecoration(
                                labelText: 'Harga *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                prefixText: 'Rp ',
                                hintText: 'Contoh: 15000 atau 15.000',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: deskripsiController,
                              decoration: InputDecoration(
                                labelText: 'Deskripsi',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                              maxLines: 3,
                            ),
                            SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButton<String>(
                                value: selectedCategoryForDialog,
                                isExpanded: true,
                                underline: SizedBox(),
                                onChanged: (String? newValue) {
                                  setDialogState(() {
                                    selectedCategoryForDialog = newValue!;
                                  });
                                },
                                items: categoriesForDialog
                                    .map<DropdownMenuItem<String>>(
                                        (String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                              ),
                            ),
                            SizedBox(height: 20),
                            if (product != null &&
                                currentImageUrl.isNotEmpty &&
                                _imageFile == null)
                              Column(
                                children: [
                                  Text(
                                    'Gambar Saat Ini:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  _buildImageContainer(currentImageUrl, 100),
                                  SizedBox(height: 16),
                                ],
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await _pickImage();
                                  setDialogState(() {});
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  product == null
                                      ? 'Pilih Gambar'
                                      : 'Ganti Gambar',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            if (_imageFile != null)
                              Column(
                                children: [
                                  Text(
                                    'Gambar Baru:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.green),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _imageFile!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            SizedBox(height: 16),
                            Text(
                              '* Field wajib diisi',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: Text(
                            'Batal',
                            style: TextStyle(fontSize: 16),
                          ),
                          onPressed: () {
                            _resetImageState();
                            Navigator.of(context).pop();
                          },
                        ),
                        SizedBox(width: 12),
                        ElevatedButton(
                          child: Text(
                            'Simpan',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 15, vertical: 12),
                          ),
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty ||
                                priceController.text.trim().isEmpty) {
                              _showErrorSnackBar(
                                  'Nama produk dan harga wajib diisi');
                              return;
                            }

                            try {
                              parsePrice(priceController.text.trim());
                            } catch (e) {
                              _showErrorSnackBar('Format harga tidak valid');
                              return;
                            }

                            if (product == null) {
                              await _addProduct(
                                nameController.text,
                                priceController.text,
                                selectedCategoryForDialog,
                                deskripsiController.text,
                              );
                            } else {
                              await _editProduct(
                                product['productId'],
                                nameController.text,
                                priceController.text,
                                selectedCategoryForDialog,
                                deskripsiController.text,
                                currentImageUrl,
                              );
                            }

                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width),
                        child: DataTable(
                          columnSpacing: 20.0,
                          dataRowHeight: 80,
                          columns: const [
                            DataColumn(label: Text('Gambar')),
                            DataColumn(label: Text('Nama Barang')),
                            DataColumn(label: Text('Harga')),
                            DataColumn(label: Text('Kategori')),
                            DataColumn(label: Text('Aksi')),
                          ],
                          rows: filteredProducts.map((product) {
                            return DataRow(cells: [
                              DataCell(
                                Container(
                                  padding: EdgeInsets.all(4),
                                  child: _buildImageContainer(
                                      product['imageUrl'], 60),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    product['productName'],
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    'Rp ${product['price']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    product['category'],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit,
                                            color: Color(0xFF0072BC)),
                                        tooltip: 'Edit Produk',
                                        onPressed: () => _showProductDialog(
                                            product: product),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete,
                                            color: Colors.red),
                                        tooltip: 'Hapus Produk',
                                        onPressed: () =>
                                            _showDeleteConfirmationDialog(
                                          product['productId'],
                                          product['productName'],
                                        ),
                                      ),
                                    ],
                                  ),
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
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Color(0xFF0072BC),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
