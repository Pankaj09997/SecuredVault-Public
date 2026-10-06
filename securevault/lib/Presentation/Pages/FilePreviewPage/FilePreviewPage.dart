import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FilePreviewPage extends StatefulWidget {
  final Uint8List fileBytes;
  final String fileExtension;
  final String fileName;

  const FilePreviewPage({
    super.key,
    required this.fileBytes,
    required this.fileExtension,
    required this.fileName,
  });

  @override
  State<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends State<FilePreviewPage> {
  late PdfViewerController _pdfController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _validateAndLoadPdf();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _validateAndLoadPdf() async {
    _logPdfInfo();

    if (widget.fileBytes.isEmpty) {
      _showError('File content is empty');
      return;
    }

    if (!_isValidPdf(widget.fileBytes)) {
      _showError('Invalid PDF format');
      return;
    }

    setState(() => _isLoading = false);
  }

  void _logPdfInfo() {
    debugPrint('--- PDF DEBUG INFO ---');
    debugPrint('File name: ${widget.fileName}');
    debugPrint('Extension: ${widget.fileExtension}');
    debugPrint('Size: ${widget.fileBytes.length} bytes');
    
    if (widget.fileBytes.isNotEmpty) {
      debugPrint('Header: ${_bytesToHex(widget.fileBytes.sublist(0, min(8, widget.fileBytes.length)))}');
    }
  }

  String _bytesToHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  bool _isValidPdf(Uint8List bytes) {
    if (bytes.length < 4) return false;
    final header = String.fromCharCodes(bytes.sublist(0, 4));
    return header == '%PDF';
  }

  void _showError(String message) {
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  Future<void> _openWithSystemViewer() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.fileName}');
      await file.writeAsBytes(widget.fileBytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      _showError('Failed to open with system viewer: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _openWithSystemViewer(),
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _ErrorWidget(
        message: _errorMessage!,
        fileSize: widget.fileBytes.length,
        onRetry: _validateAndLoadPdf,
      );
    }

    return SfPdfViewer.memory(
      widget.fileBytes,
      controller: _pdfController,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      onDocumentLoaded: (_) => debugPrint('PDF loaded successfully'),
      onDocumentLoadFailed: (details) {
        debugPrint('PDF load failed: ${details.error}');
        _showError('Failed to load PDF: ${details.error}');
      },
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final int fileSize;
  final VoidCallback onRetry;

  const _ErrorWidget({
    required this.message,
    required this.fileSize,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'File size: $fileSize bytes',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}