import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'sheet_viewer_page.dart';

class RecordPage extends StatefulWidget {
  @override
  _RecordPageState createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  String? _filePath;
  bool _loading = false;

  Future<void> _pickAndConvert() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'wav',
        'mp3',
        'mid',
        'midi',
        'ogg',
        'flac',
        'aac',
        'aiff',
      ],
    );
    final path = res?.files.single.path;
    if (path == null) return;

    setState(() {
      _filePath = path;
      _loading = true;
    });

    try {
      final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final uri = Uri.parse('http://$host:5000/transcribe');
      final req = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', path));

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode != 200) {
        throw Exception('Server error ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final sheetId = data['id'] as int;
      final pageCount = data['page_count'] as int;
      final fileName = _filePath!.split(Platform.pathSeparator).last;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SheetViewerPage.remote(
            sheetId: sheetId,
            pageCount: pageCount,
            title: fileName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Conversion failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sheet Music Converter')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tap to select a file',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: _pickAndConvert,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.music_note,
                        size: 60,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    'Audio to Sheet',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  if (_filePath != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _filePath!.split(Platform.pathSeparator).last,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
