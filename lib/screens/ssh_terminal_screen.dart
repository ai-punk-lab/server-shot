import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';
import '../models/server_profile.dart';
import '../theme/app_theme.dart';

class SSHTerminalScreen extends StatefulWidget {
  final ServerProfile profile;

  const SSHTerminalScreen({super.key, required this.profile});

  @override
  State<SSHTerminalScreen> createState() => _SSHTerminalScreenState();
}

class _SSHTerminalScreenState extends State<SSHTerminalScreen> {
  late final Terminal _terminal;
  final _terminalKey = GlobalKey();
  SSHClient? _client;
  SSHSession? _session;
  bool _connected = false;
  bool _connecting = true;
  String _title = '';
  Timer? _keepAliveTimer;

  // Virtual keyboard modifier states
  bool _ctrlActive = false;
  bool _altActive = false;

  @override
  void initState() {
    super.initState();
    _title = '${widget.profile.username}@${widget.profile.host}';
    _terminal = Terminal(maxLines: 10000);

    // Wait for first frame so terminal view has real dimensions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSSH();
    });
  }

  Future<void> _initSSH() async {
    _terminal.write('Connecting to ${widget.profile.host}:${widget.profile.port}...\r\n');

    try {
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
      _terminal.write('Connected.\r\n');

      _session = await _client!.shell(
        pty: SSHPtyConfig(
          width: _terminal.viewWidth,
          height: _terminal.viewHeight,
        ),
      );

      _terminal.buffer.clear();
      _terminal.buffer.setCursor(0, 0);

      setState(() {
        _connected = true;
        _connecting = false;
      });

      // Sync PTY size with actual terminal view dimensions after rendering
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_session != null && _terminal.viewWidth > 0) {
          _session!.resizeTerminal(
            _terminal.viewWidth,
            _terminal.viewHeight,
          );
        }
      });

      _terminal.onTitleChange = (title) {
        if (mounted) setState(() => _title = title);
      };

      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        _session?.resizeTerminal(width, height, pixelWidth, pixelHeight);
      };

      _terminal.onOutput = (data) {
        _session?.stdin.add(utf8.encode(data));
      };

      _session!.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .listen(
        _terminal.write,
        onDone: _onDisconnect,
        onError: (e) {
          _onDisconnect();
          _terminal.write('\r\n\x1B[31m--- Error: $e ---\x1B[0m\r\n');
        },
      );

      _session!.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .listen(_terminal.write);

      // Keep-alive every 30s — send empty data to detect broken connection
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (_connected && _client != null) {
          try {
            await _client!.execute('echo');
          } catch (_) {
            _onDisconnect();
          }
        }
      });
    } catch (e) {
      setState(() {
        _connecting = false;
        _connected = false;
      });
      _terminal.write('\x1B[31mConnection failed: $e\x1B[0m\r\n');
      _terminal.write('\x1B[90mTap Reconnect to try again.\x1B[0m\r\n');
    }
  }

  void _onDisconnect() {
    _keepAliveTimer?.cancel();
    if (mounted) {
      setState(() => _connected = false);
      _terminal.write('\r\n\x1B[33m--- Disconnected ---\x1B[0m\r\n');
    }
  }

  Future<void> _reconnect() async {
    _keepAliveTimer?.cancel();
    _session?.close();
    _client?.close();
    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);
    setState(() {
      _connecting = true;
      _connected = false;
    });
    await _initSSH();
  }

  void _sendCtrl(String char) {
    if (_session == null || !_connected) return;
    final code = char.codeUnitAt(0) - 64; // Ctrl+A = 1, Ctrl+C = 3, etc.
    _session!.stdin.add(Uint8List.fromList([code]));
    HapticFeedback.lightImpact();
    setState(() => _ctrlActive = false);
  }

  void _sendSpecialKey(List<int> bytes) {
    if (_session == null || !_connected) return;
    _session!.stdin.add(Uint8List.fromList(bytes));
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    _session?.close();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      body: SafeArea(
        child: Column(
          children: [
            // Header bar
            _buildHeader(),
            // Terminal
            Expanded(
              child: TerminalView(
                _terminal,
                key: _terminalKey,
                hardwareKeyboardOnly: false,
                keyboardType: TextInputType.text,
                onKeyEvent: (node, event) {
                  // Ensure Enter from USB keyboard works
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.enter ||
                       event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                    _terminal.keyInput(TerminalKey.enter);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                theme: const TerminalTheme(
                  cursor: Color(0xFFE8E8F0),
                  selection: Color(0x806C5CE7),
                  foreground: Color(0xFFE8E8F0),
                  background: Color(0xFF0A0A18),
                  black: Color(0xFF0D0D1A),
                  red: Color(0xFFFF6B6B),
                  green: Color(0xFF00B894),
                  yellow: Color(0xFFFDAA5E),
                  blue: Color(0xFF74B9FF),
                  magenta: Color(0xFF6C5CE7),
                  cyan: Color(0xFF00D2D3),
                  white: Color(0xFFE8E8F0),
                  brightBlack: Color(0xFF6B6B80),
                  brightRed: Color(0xFFFF8787),
                  brightGreen: Color(0xFF55EFC4),
                  brightYellow: Color(0xFFFECA57),
                  brightBlue: Color(0xFFA29BFE),
                  brightMagenta: Color(0xFFD980FA),
                  brightCyan: Color(0xFF7EFFF5),
                  brightWhite: Color(0xFFFFFFFF),
                  searchHitBackground: Color(0xFFDAA520),
                  searchHitBackgroundCurrent: Color(0xFFFF6B6B),
                  searchHitForeground: Color(0xFF0D0D1A),
                ),
                autofocus: true,
              ),
            ),
            // Virtual key bar
            if (_connected) _buildVirtualKeyBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _connected
                  ? AppTheme.successColor
                  : _connecting
                      ? AppTheme.warningColor
                      : AppTheme.errorColor,
              boxShadow: [
                BoxShadow(
                  color: (_connected
                          ? AppTheme.successColor
                          : _connecting
                              ? AppTheme.warningColor
                              : AppTheme.errorColor)
                      .withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!_connected && !_connecting)
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  size: 20, color: AppTheme.seedColor),
              onPressed: _reconnect,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
        ],
      ),
    );
  }

  Widget _buildVirtualKeyBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _modKey('Ctrl', _ctrlActive, () {
              setState(() {
                _ctrlActive = !_ctrlActive;
                _altActive = false;
              });
              HapticFeedback.lightImpact();
            }),
            const SizedBox(width: 5),
            _modKey('Alt', _altActive, () {
              setState(() {
                _altActive = !_altActive;
                _ctrlActive = false;
              });
              HapticFeedback.lightImpact();
            }),
            const SizedBox(width: 10),
            _vkey('Esc', () => _sendSpecialKey([27])),
            _vkey('Tab', () => _sendSpecialKey([9])),
            _vkey('↑', () => _sendSpecialKey([27, 91, 65])),
            _vkey('↓', () => _sendSpecialKey([27, 91, 66])),
            _vkey('←', () => _sendSpecialKey([27, 91, 68])),
            _vkey('→', () => _sendSpecialKey([27, 91, 67])),
            _vkey('Home', () => _sendSpecialKey([27, 91, 72])),
            _vkey('End', () => _sendSpecialKey([27, 91, 70])),
            _vkey('PgUp', () => _sendSpecialKey([27, 91, 53, 126])),
            _vkey('PgDn', () => _sendSpecialKey([27, 91, 54, 126])),
            const SizedBox(width: 10),
            _vkey('C-c', () => _sendCtrl('C')),
            _vkey('C-d', () => _sendCtrl('D')),
            _vkey('C-z', () => _sendCtrl('Z')),
            _vkey('C-l', () => _sendCtrl('L')),
            _vkey('C-a', () => _sendCtrl('A')),
            _vkey('C-e', () => _sendCtrl('E')),
            _vkey('C-r', () => _sendCtrl('R')),
            _vkey('C-w', () => _sendCtrl('W')),
          ],
        ),
      ),
    );
  }

  Widget _modKey(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: active
              ? AppTheme.seedColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: active
                ? AppTheme.seedColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active
                ? AppTheme.seedColor
                : Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _vkey(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
