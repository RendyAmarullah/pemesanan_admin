import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';

class DataPelangganScreen extends StatefulWidget {
  @override
  _DataPelangganScreenState createState() => _DataPelangganScreenState();
}

class _DataPelangganScreenState extends State<DataPelangganScreen> {
  late Client client;
  late Databases databases;
  late Account account;
  String userId = '';
  String projectId = '681aa0b70002469fc157';
  String databaseId = '681aa33a0023a8c7eb1f';
  String usersCollectionId = '684083800031dfaaecad';
  final String addressCollectionId = '68447d3d0007b5f75cc5';
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> filteredCustomers = [];

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    client = Client();
    client.setEndpoint('https://cloud.appwrite.io/v1').setProject(projectId);
    databases = Databases(client);
    account = Account(client);

    _loadPelangganData();
  }

  Future<void> _loadPelangganData() async {
    try {
      final response = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        queries: [
          Query.equal('roles', 'pelanggan'),
        ],
      );

      setState(() {
        customers = response.documents.map((doc) {
          return {
            'username': doc.data['name'] ?? 'No name',
            'email': doc.data['email'] ?? 'No email',
            'noHandphone': doc.data['noHandphone'] ?? 'No phone number',
            'status': doc.data['status'] ?? 'No status',
            'userId': doc.$id,
            'alamat': '-',
          };
        }).toList();

        filteredCustomers = List.from(customers);
        _fetchCustomerAddresses();
      });
    } catch (e) {
      print("Error loading pelanggan data: $e");
    }
  }

  Future<void> _fetchCustomerAddresses() async {
    for (var i = 0; i < customers.length; i++) {
      try {
        final response = await databases.listDocuments(
          databaseId: databaseId,
          collectionId: addressCollectionId,
          queries: [
            Query.equal('user_id', customers[i]['userId']),
          ],
        );

        if (response.documents.isNotEmpty) {
          setState(() {
            customers[i]['alamat'] = response.documents.first.data['address'] ??
                'Alamat tidak tersedia';
          });
        }
      } catch (e) {
        print('Error fetching address: $e');
      }
    }

    setState(() {
      filteredCustomers = List.from(customers);
    });
  }

  void _filterData() {
    setState(() {
      filteredCustomers = customers
          .where((customer) =>
              customer['username']!
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase()) ||
              customer['email']!
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase()) ||
              customer['alamat']!
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase()) ||
              customer['noHandphone']!
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase()) ||
              customer['status']!
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase()))
          .toList();
    });
  }

  Future<void> _updateStatus(String userId, String newStatus) async {
    try {
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: userId,
        data: {'status': newStatus},
      );

      setState(() {
        filteredCustomers = filteredCustomers.map((customer) {
          if (customer['userId'] == userId) {
            customer['status'] = newStatus;
          }
          return customer;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status berhasil diperbarui')),
      );
    } catch (e) {
      print('Error updating status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui status')),
      );
    }
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
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              ),
              onChanged: (value) => _filterData(),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(4.0),
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
                        columnSpacing: 30.0,
                        columns: const [
                          DataColumn(label: Text('Username')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Alamat')),
                          DataColumn(label: Text('No. Handphone')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: filteredCustomers.map((customer) {
                          return DataRow(cells: [
                            DataCell(Text(customer['username']!)),
                            DataCell(Text(customer['email']!)),
                            DataCell(Text(customer['alamat']!)),
                            DataCell(Text(customer['noHandphone']!)),
                            DataCell(Text(customer['status']!)),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      customer['status'] == 'Aktif'
                                          ? Icons.lock
                                          : Icons.lock_open,
                                      color: customer['status'] == 'Aktif'
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                    onPressed: () {
                                      String newStatus =
                                          customer['status'] == 'Aktif'
                                              ? 'Nonaktif'
                                              : 'Aktif';
                                      _updateStatus(
                                          customer['userId'], newStatus);
                                    },
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    title: 'Data Pelanggan',
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: DataPelangganScreen(),
  ));
}
