import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../models/meet_import_export_result.dart';
import '../services/meet_import_export_service.dart';
import '../providers/event_provider.dart';

class ImportMeetScreen extends ConsumerStatefulWidget {
  const ImportMeetScreen({super.key});

  @override
  ConsumerState<ImportMeetScreen> createState() => _ImportMeetScreenState();
}

class _ImportMeetScreenState extends ConsumerState<ImportMeetScreen> {
  late final MeetImportExportService _service;
  File? _selectedFile;
  bool _isImporting = false;
  MeetImportResult? _importResult;

  @override
  void initState() {
    super.initState();
    _service = MeetImportExportService();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = File(result.files.first.path!);
      });
    }
  }

  Future<void> _handleImport() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _importResult = null;
    });

    try {
      final result = await _service.importMeet(_selectedFile!);
      setState(() => _importResult = result);

      if (result.success && context.mounted) {
        // Invalidate all event providers to refresh the lists
        ref.invalidate(eventsProvider);
        ref.invalidate(upcomingEventsProvider);
        ref.invalidate(pastEventsProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meet "${result.meetName}" imported successfully!'),
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate back to events list to see the imported meet
        context.go('/events');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Import Meet'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Meet from File',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Select a previously exported meet JSON file to import all event data, including days, sessions, judges, and expenses.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // File Selection
            if (_selectedFile == null)
              OutlinedButton.icon(
                onPressed: _isImporting ? null : _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Choose JSON File'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              )
            else
              Card(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'File Selected',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedFile!.path.split('/').last,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isImporting ? null : _pickFile,
                          child: const Text('Choose Different File'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Import Button
            if (_selectedFile != null && _importResult == null)
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isImporting ? null : _handleImport,
                  icon: _isImporting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _isImporting ? 'Importing...' : 'Import Meet',
                  ),
                ),
              ),

            // Results
            if (_importResult != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: _importResult!.success
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _importResult!.success
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _importResult!.success
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _importResult!.message,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: _importResult!.success
                                            ? Colors.green.shade900
                                            : Colors.red.shade900,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          if (_importResult!.success) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Meet Information',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow('Meet Name', _importResult!.meetName ?? 'Unknown'),
                            _buildInfoRow(
                              'Items Created',
                              '${_importResult!.totalItemsCreated} items',
                            ),
                          ],
                          if (_importResult!.daysCreated > 0) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Import Summary',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow('Days', '${_importResult!.daysCreated}'),
                            _buildInfoRow(
                              'Sessions',
                              '${_importResult!.sessionsCreated}',
                            ),
                            _buildInfoRow('Floors', '${_importResult!.floorsCreated}'),
                            _buildInfoRow('Judges', '${_importResult!.judgesCreated}'),
                            _buildInfoRow(
                              'Expenses',
                              '${_importResult!.expensesCreated}',
                            ),
                          ],
                          if (_importResult!.errors.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Errors',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            ..._importResult!.errors.map(
                              (error) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• $error',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.red.shade700),
                                ),
                              ),
                            ),
                          ],
                          if (_importResult!.warnings.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Warnings',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: Colors.orange),
                            ),
                            const SizedBox(height: 8),
                            ..._importResult!.warnings.map(
                              (warning) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• $warning',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.orange.shade700),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_importResult!.success)
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () =>
                            context.go('/events/${_importResult!.meetId}'),
                        child: const Text('View Imported Meet'),
                      ),
                    )
                  else
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedFile = null;
                            _importResult = null;
                          });
                        },
                        child: const Text('Try Again'),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
