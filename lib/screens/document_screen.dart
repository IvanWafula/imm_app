import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/document.dart';
import 'document_viewer_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late Future<List<Document>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _documentsFuture = fetchDocuments();
  }

  Future<List<Document>> fetchDocuments() async {
  try {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      throw Exception('No Internet Connection');
    }

    final response = await http.get(Uri.parse(Config.documentEndpoint));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Document.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load documents');
    }
  } catch (e) {
    throw Exception(e.toString());
  }
}


  void openDocument(Document doc) {
    if (doc.fileUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: doc.title,
          filePath: doc.fileUrl,
          fileType: 'pdf', // we always convert to PDF
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📄 Documents')),
      body: FutureBuilder<List<Document>>(
        future: _documentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString() == 'Exception: No Internet Connection'
                    ? 'No Internet Connection'
                    : 'No Internet: Failed to load data',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }


          final documents = snapshot.data!;
          if (documents.isEmpty) {
            return const Center(child: Text('No documents available.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];

              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.picture_as_pdf,
                    color: Colors.red,
                    size: 32,
                  ),
                  title: Text(
                    doc.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text('Type: ${doc.fileType.toUpperCase()}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () => openDocument(doc),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
