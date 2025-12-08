import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/judge_import_export_service.dart';
import '../../providers/judge_provider.dart';

class JudgeImportExportScreen extends ConsumerStatefulWidget {
  const JudgeImportExportScreen({super.key});

  @override
  ConsumerState<JudgeImportExportScreen> createState() => _JudgeImportExportScreenState();
}

class _JudgeImportExportScreenState extends ConsumerState<JudgeImportExportScreen> {
  final JudgeImportExportService _importExportService = JudgeImportExportService();
  bool _isProcessing = false;
  String? _lastOperationMessage;
  List<String> _lastErrors = [];

  Future<void> _exportJudges() async {
    setState(() {
      _isProcessing = true;
      _lastOperationMessage = null;
      _lastErrors = [];
    });

    try {
      final file = await _importExportService.exportJudges(includeArchived: false);
      
      if (!mounted) return;
      
      // Update state to stop processing
      setState(() {
        _isProcessing = false;
      });

      // Show save location and offer to share
      if (!mounted) return;
      
      final fileName = file.path.split('/').last;
      final savedLocation = file.path;
      
      setState(() {
        _lastOperationMessage = 'Exported successfully to:\n$savedLocation';
      });
      
      // Offer to share
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Successful'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Judges exported to:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                savedLocation,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tap Share to save to Downloads, Google Drive, or another location.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                final box = context.findRenderObject() as RenderBox?;
                await Share.shareXFiles(
                  [XFile(file.path)],
                  subject: 'Judges Export',
                  sharePositionOrigin: box != null 
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null,
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _lastOperationMessage = 'Export failed: ${e.toString()}';
      });
    }
  }

  Future<void> _importJudges() async {
    try {
      // Pick a JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // User canceled
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to access file')),
        );
        return;
      }

      setState(() {
        _isProcessing = true;
        _lastOperationMessage = null;
        _lastErrors = [];
      });

      final file = File(filePath);
      final importResult = await _importExportService.importJudges(file);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _lastOperationMessage = importResult.message;
        _lastErrors = importResult.errors;
      });

      if (importResult.success) {
        // Refresh judges list
        ref.invalidate(judgesProvider);
        ref.invalidate(filteredJudgesWithLevelsProvider);
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.message),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _lastOperationMessage = 'Import failed: ${e.toString()}';
        _lastErrors = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import/Export Judges'),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Processing...'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      _importExportService.cancelImport();
                      setState(() {
                        _isProcessing = false;
                        _lastOperationMessage = 'Import cancelled';
                      });
                    },
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('Cancel Import'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Export Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.file_upload, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                'Export Judges',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Export all active judges and their certifications to a JSON file. '
                            'This file can be used as a backup or to import judges into another device.',
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _exportJudges,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('Export Judges'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Import Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.file_download, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                'Import Judges',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Import judges from a JSON file. '
                            'Download the template below to see the required format.',
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Import Notes:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '• Judges with matching names will be updated\n'
                                  '• New judges will be created\n'
                                  '• Certifications will be assigned if judge levels exist\n'
                                  '• Judge levels must be created before importing',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _importJudges,
                            icon: const Icon(Icons.file_download),
                            label: const Text('Import from JSON'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Status Message
                  if (_lastOperationMessage != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: _lastErrors.isEmpty ? Colors.green.shade50 : Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _lastErrors.isEmpty ? Icons.check_circle : Icons.warning,
                                  color: _lastErrors.isEmpty ? Colors.green : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _lastOperationMessage!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _lastErrors.isEmpty ? Colors.green.shade900 : Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_lastErrors.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Errors (${_lastErrors.length}):',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _lastErrors.map((error) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '• $error',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
