import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/sheet_metadata.dart';

class TranscriptionResult {
  final int id;
  final int pageCount;
  TranscriptionResult({required this.id, required this.pageCount});

  factory TranscriptionResult.fromJson(Map<String, dynamic> js) =>
      TranscriptionResult(
        id: js['id'] as int,
        pageCount: js['page_count'] as int,
      );
}

class ApiService {
  static final _host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
  static Uri _baseUri([String path = '']) =>
      Uri.parse('http://$_host:5000/$path');

  static Future<TranscriptionResult> transcribeFile(File file) async {
    final uri = _baseUri('transcribe');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      throw Exception('Transcription failed: ${resp.statusCode}');
    }
    return TranscriptionResult.fromJson(jsonDecode(resp.body));
  }

  static Future<List<SheetMetadata>> listSheets() async {
    final resp = await http.get(_baseUri('sheets'));
    if (resp.statusCode != 200) {
      throw Exception('List failed: ${resp.statusCode}');
    }
    final List<dynamic> data = jsonDecode(resp.body);
    return data
        .map((m) => SheetMetadata.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  static Future<SheetMetadata> getSheetMetadata(int id) async {
    final resp = await http.get(_baseUri('sheets/$id'));
    if (resp.statusCode != 200) {
      throw Exception('Fetch metadata failed: ${resp.statusCode}');
    }
    return SheetMetadata.fromJson(jsonDecode(resp.body));
  }

  static Future<Uint8List> getSheetPage(int sheetId, int idx) async {
    final resp = await http.get(_baseUri('sheets/$sheetId/pages/$idx'));
    if (resp.statusCode != 200) {
      throw Exception('Get page failed: ${resp.statusCode}');
    }
    return resp.bodyBytes;
  }

  static Future<void> deleteSheet(int id) async {
    final resp = await http.delete(_baseUri('sheets/$id'));
    if (resp.statusCode != 200) {
      throw Exception('Delete failed: ${resp.statusCode}');
    }
  }
}
