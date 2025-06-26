import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class SheetViewerPage extends StatelessWidget {
  final List<Uint8List>? localPages;

  final int? sheetId;

  final int? pageCount;

  final String title;

  const SheetViewerPage._({
    Key? key,
    this.localPages,
    this.sheetId,
    this.pageCount,
    required this.title,
  }) : assert(
         (localPages != null && sheetId == null && pageCount == null) ||
             (localPages == null && sheetId != null && pageCount != null),
         'Either provide localPages, or sheetId + pageCount, not both',
       ),
       super(key: key);

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
              child: Container(color: Colors.white, child: imageWidget),
            ),
          );
        },
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }
}
