// lib/pages/sheet_viewer_page.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class SheetViewerPage extends StatelessWidget {
  /// If non-null: show these in-memory bytes.
  final List<Uint8List>? localPages;

  /// If non-null: fetch pages from the server.
  final int? sheetId;

  /// Only used in "remote" mode.
  final int? pageCount;

  /// AppBar title
  final String title;

  const SheetViewerPage._({
    Key? key,
    this.localPages,
    this.sheetId,
    this.pageCount,
    required this.title,
  }) : assert(
         // either localPages OR (sheetId+pageCount)
         (localPages != null && sheetId == null && pageCount == null) ||
             (localPages == null && sheetId != null && pageCount != null),
         'Either provide localPages, or sheetId + pageCount, not both',
       ),
       super(key: key);

  /// Constructor for in-memory pages
  factory SheetViewerPage.local({
    Key? key,
    required List<Uint8List> pages,
    String? title,
  }) {
    return SheetViewerPage._(
      key: key,
      localPages: pages,
      title: title ?? 'Sheet Music',
    );
  }

  /// Constructor for remote-loaded pages
  factory SheetViewerPage.remote({
    Key? key,
    required int sheetId,
    required int pageCount,
    required String title,
  }) {
    return SheetViewerPage._(
      key: key,
      sheetId: sheetId,
      pageCount: pageCount,
      title: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRemote = localPages == null;
    final int count = isRemote ? pageCount! : localPages!.length;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PageView.builder(
        itemCount: count,
        itemBuilder: (_, idx) {
          Widget imageWidget;
          if (isRemote) {
            // URL for remote page
            final uri = Uri(
              scheme: 'http',
              host: Platform.isAndroid ? '10.0.2.2' : 'localhost',
              port: 5000,
            ).replace(path: '/sheets/$sheetId/pages/$idx');

            imageWidget = Image.network(
              uri.toString(),
              fit: BoxFit.contain,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (ctx, err, st) =>
                  const Center(child: Text('Failed to load page')),
            );
          } else {
            imageWidget = Image.memory(localPages![idx], fit: BoxFit.contain);
          }

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              // ensure a white background behind the sheet
              child: Container(color: Colors.white, child: imageWidget),
            ),
          );
        },
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }
}
