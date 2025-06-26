// lib/pages/library_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/sheet_metadata.dart';
import '../services/api_service.dart';
import 'sheet_viewer_page.dart';

class LibraryPage extends StatefulWidget {
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late Future<List<SheetMetadata>> _sheetsFut;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _sheetsFut = ApiService.listSheets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Sheet Music')),
      body: SafeArea(
        child: FutureBuilder<List<SheetMetadata>>(
          future: _sheetsFut,
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }

            final sheets = snap.data!;
            if (sheets.isEmpty) {
              return const Center(child: Text('No saved sheet music.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sheets.length,
              itemBuilder: (c, i) {
                final s = sheets[i];
                final prettyDate = DateFormat.yMd().add_jm().format(
                  s.createdAt,
                );

                return Dismissible(
                  key: ValueKey(s.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: const Text('Delete this sheet?'),
                      content: Text('“${s.filename}”'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ).then((v) => v ?? false),
                  onDismissed: (_) async {
                    try {
                      await ApiService.deleteSheet(s.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Deleted “${s.filename}”')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Delete failed: $e')),
                      );
                    } finally {
                      _reload();
                    }
                  },
                  child: ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(s.filename),
                    subtitle: Text(prettyDate),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SheetViewerPage.remote(
                            sheetId: s.id,
                            pageCount: s.pageCount,
                            title: s.filename,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
