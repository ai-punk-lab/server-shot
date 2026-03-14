import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/server_profile.dart';
import '../theme/app_theme.dart';

class SftpScreen extends StatefulWidget {
  final ServerProfile profile;

  const SftpScreen({super.key, required this.profile});

  @override
  State<SftpScreen> createState() => _SftpScreenState();
}

class _SftpScreenState extends State<SftpScreen> {
  SSHClient? _client;
  SftpClient? _sftp;
  bool _connecting = true;
  String? _error;
  String _currentPath = '/';
  List<SftpName> _files = [];
  bool _loading = false;
  final Set<String> _selectedFiles = {};
  bool _selectionMode = false;
  double? _transferProgress;
  String? _transferName;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      setState(() {
        _connecting = true;
        _error = null;
      });

      final socket = await SSHSocket.connect(
        widget.profile.host,
        widget.profile.port,
        timeout: const Duration(seconds: 15),
      );

      _client = SSHClient(
        socket,
        username: widget.profile.username,
        onPasswordRequest: widget.profile.password.isNotEmpty
            ? () => widget.profile.password
            : null,
        identities: widget.profile.privateKey != null
            ? [...SSHKeyPair.fromPem(widget.profile.privateKey!)]
            : null,
      );

      await _client!.authenticated;
      _sftp = await _client!.sftp();

      // Get home directory
      final home = await _client!.run('echo \$HOME');
      final homePath = String.fromCharCodes(home).trim();
      _currentPath = homePath.isNotEmpty ? homePath : '/root';

      setState(() => _connecting = false);
      await _listDir();
    } catch (e) {
      setState(() {
        _connecting = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _listDir() async {
    if (_sftp == null) return;
    setState(() => _loading = true);
    try {
      final items = await _sftp!.listdir(_currentPath);
      items.sort((a, b) {
        // Directories first
        final aIsDir = a.attr.isDirectory;
        final bIsDir = b.attr.isDirectory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.filename.compareTo(b.filename);
      });
      setState(() {
        _files = items.where((f) => f.filename != '.').toList();
        _loading = false;
        _selectedFiles.clear();
        _selectionMode = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to list directory: $e';
      });
    }
  }

  void _navigateTo(String name) {
    if (name == '..') {
      final parts = _currentPath.split('/');
      parts.removeLast();
      _currentPath = parts.isEmpty ? '/' : parts.join('/');
    } else {
      _currentPath =
          _currentPath.endsWith('/') ? '$_currentPath$name' : '$_currentPath/$name';
    }
    _listDir();
  }

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return;

      for (final file in result.files) {
        if (file.path == null) continue;
        final localFile = File(file.path!);
        final remotePath = '$_currentPath/${file.name}';

        setState(() {
          _transferName = 'Uploading ${file.name}';
          _transferProgress = 0;
        });

        final bytes = await localFile.readAsBytes();
        final remoteFile = await _sftp!.open(
          remotePath,
          mode: SftpFileOpenMode.create |
              SftpFileOpenMode.write |
              SftpFileOpenMode.truncate,
        );

        final total = bytes.length;
        int written = 0;
        const chunkSize = 32768;

        for (int i = 0; i < total; i += chunkSize) {
          final end = (i + chunkSize > total) ? total : i + chunkSize;
          await remoteFile.write(Stream.value(bytes.sublist(i, end)), offset: i);
          written = end;
          setState(() => _transferProgress = written / total);
        }

        await remoteFile.close();
      }

      setState(() {
        _transferName = null;
        _transferProgress = null;
      });

      await _listDir();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${result.files.length} file(s) uploaded')),
        );
      }
    } catch (e) {
      setState(() {
        _transferName = null;
        _transferProgress = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _downloadFile(SftpName file) async {
    try {
      final remotePath = '$_currentPath/${file.filename}';
      final size = file.attr.size ?? 0;

      setState(() {
        _transferName = 'Downloading ${file.filename}';
        _transferProgress = 0;
      });

      final remoteFile = await _sftp!.open(remotePath);
      final chunks = <int>[];
      int received = 0;

      await for (final chunk in remoteFile.read()) {
        chunks.addAll(chunk);
        received += chunk.length;
        if (size > 0) {
          setState(() => _transferProgress = received / size);
        }
      }
      await remoteFile.close();

      // Save to Downloads
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/${file.filename}');
      await localFile.writeAsBytes(Uint8List.fromList(chunks));

      setState(() {
        _transferName = null;
        _transferProgress = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${localFile.path}')),
        );
      }
    } catch (e) {
      setState(() {
        _transferName = null;
        _transferProgress = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _createDir() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Folder'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Folder name',
            prefixIcon: Icon(Icons.folder_rounded, size: 18),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text),
            child: Text('Create', style: TextStyle(color: AppTheme.seedColor)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      try {
        await _sftp!.mkdir('$_currentPath/$name');
        await _listDir();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete'),
        content: Text('Delete ${_selectedFiles.length} item(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (final name in _selectedFiles) {
      try {
        final path = '$_currentPath/$name';
        final file = _files.firstWhere((f) => f.filename == name);
        if (file.attr.isDirectory) {
          // Recursive delete via SSH command
          await _client!.run('rm -rf "$path"');
        } else {
          await _sftp!.remove(path);
        }
      } catch (_) {}
    }
    await _listDir();
  }

  @override
  void dispose() {
    _sftp?.close();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedFiles.length} selected')
            : const Text('Files'),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete_rounded, size: 20),
              onPressed: _selectedFiles.isNotEmpty ? _deleteSelected : null,
              color: AppTheme.errorColor,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selectedFiles.clear();
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.create_new_folder_rounded, size: 20),
              onPressed: _sftp != null ? _createDir : null,
              tooltip: 'New folder',
            ),
            IconButton(
              icon: const Icon(Icons.upload_file_rounded, size: 20),
              onPressed: _sftp != null ? _uploadFile : null,
              tooltip: 'Upload',
            ),
          ],
        ],
      ),
      body: _connecting
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          color: AppTheme.errorColor, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5)),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _connect, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Path bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: const Color(0xFF12122A),
                      child: Row(
                        children: [
                          Icon(Icons.folder_open_rounded,
                              size: 16,
                              color: AppTheme.seedColor.withValues(alpha: 0.6)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentPath,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh_rounded,
                                size: 18,
                                color: Colors.white.withValues(alpha: 0.3)),
                            onPressed: _listDir,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),

                    // Transfer progress
                    if (_transferProgress != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: AppTheme.seedColor.withValues(alpha: 0.1),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                value: _transferProgress,
                                strokeWidth: 2,
                                color: AppTheme.seedColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _transferName ?? 'Transferring...',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              '${(_transferProgress! * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.seedColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // File list
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: _files.length,
                              itemBuilder: (context, index) {
                                final file = _files[index];
                                return _buildFileItem(file);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFileItem(SftpName file) {
    final isDir = file.attr.isDirectory;
    final isSelected = _selectedFiles.contains(file.filename);
    final isHidden = file.filename.startsWith('.');
    final size = file.attr.size ?? 0;

    return Container(
      color: isSelected
          ? AppTheme.seedColor.withValues(alpha: 0.1)
          : Colors.transparent,
      child: ListTile(
        leading: Icon(
          isDir
              ? Icons.folder_rounded
              : _getFileIcon(file.filename),
          color: isDir
              ? AppTheme.warningColor.withValues(alpha: isHidden ? 0.3 : 0.7)
              : Colors.white.withValues(alpha: isHidden ? 0.2 : 0.4),
          size: 24,
        ),
        title: Text(
          file.filename,
          style: TextStyle(
            fontSize: 14,
            color:
                Colors.white.withValues(alpha: isHidden ? 0.3 : 0.8),
          ),
        ),
        subtitle: isDir
            ? null
            : Text(
                _formatSize(size),
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.25)),
              ),
        trailing: !isDir && !_selectionMode
            ? IconButton(
                icon: Icon(Icons.download_rounded,
                    size: 18, color: AppTheme.accentColor.withValues(alpha: 0.5)),
                onPressed: () => _downloadFile(file),
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              )
            : null,
        onTap: () {
          if (_selectionMode) {
            setState(() {
              if (isSelected) {
                _selectedFiles.remove(file.filename);
              } else {
                _selectedFiles.add(file.filename);
              }
              if (_selectedFiles.isEmpty) _selectionMode = false;
            });
          } else if (isDir) {
            _navigateTo(file.filename);
          }
        },
        onLongPress: () {
          if (file.filename == '..') return;
          setState(() {
            _selectionMode = true;
            _selectedFiles.add(file.filename);
          });
        },
      ),
    );
  }

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'rb':
      case 'go':
      case 'rs':
      case 'java':
      case 'kt':
      case 'swift':
      case 'c':
      case 'cpp':
      case 'h':
        return Icons.code_rounded;
      case 'json':
      case 'yaml':
      case 'yml':
      case 'toml':
      case 'xml':
        return Icons.data_object_rounded;
      case 'md':
      case 'txt':
      case 'log':
        return Icons.description_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
      case 'webp':
        return Icons.image_rounded;
      case 'zip':
      case 'tar':
      case 'gz':
      case 'bz2':
      case '7z':
        return Icons.archive_rounded;
      case 'sh':
      case 'bash':
        return Icons.terminal_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
