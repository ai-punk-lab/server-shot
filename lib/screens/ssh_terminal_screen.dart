import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../models/server_profile.dart';
import '../theme/app_theme.dart';

class SSHTerminalScreen extends StatefulWidget {
  final ServerProfile profile;

  const SSHTerminalScreen({super.key, required this.profile});

  @override
  State<SSHTerminalScreen> createState() => _SSHTerminalScreenState();
}

class _SSHTerminalScreenState extends State<SSHTerminalScreen>
    with WidgetsBindingObserver {
  late final Terminal _terminal;
  final _terminalKey = GlobalKey();
  SSHClient? _client;
  SSHSession? _session;
  bool _connected = false;
  bool _connecting = true;
  String _title = '';
  Timer? _keepAliveTimer;
  bool _autoReconnect = true;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;

  // Virtual keyboard modifier states
  bool _ctrlActive = false;
  bool _altActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _title = '${widget.profile.username}@${widget.profile.host}';
    _terminal = Terminal(maxLines: 10000);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSSH();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_connected && !_connecting) {
      // App came back to foreground — try reconnect
      _terminal.write('\r\n\x1B[33m--- App resumed, reconnecting... ---\x1B[0m\r\n');
      _reconnectAttempts = 0;
      _doReconnect();
    }
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
        _reconnectAttempts = 0;
      });

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
        try {
          _session?.stdin.add(utf8.encode(data));
        } catch (_) {
          _onDisconnect();
        }
      };

      _session!.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .listen(
        _terminal.write,
        onDone: _onDisconnect,
        onError: (e) {
          _onDisconnect();
        },
      );

      _session!.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .listen(_terminal.write);

      // Keep-alive: lightweight ping every 10s
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        if (!_connected || _client == null) return;
        try {
          await _client!.execute('echo ok').timeout(
            const Duration(seconds: 5),
          );
        } catch (_) {
          _onDisconnect();
        }
      });
    } catch (e) {
      setState(() {
        _connecting = false;
        _connected = false;
      });
      _terminal.write('\x1B[31mConnection failed: $e\x1B[0m\r\n');

      // Auto-reconnect
      if (_autoReconnect && _reconnectAttempts < _maxReconnectAttempts) {
        final delay = _reconnectDelay();
        _terminal.write('\x1B[90mRetrying in ${delay.inSeconds}s (${_reconnectAttempts + 1}/$_maxReconnectAttempts)...\x1B[0m\r\n');
        await Future.delayed(delay);
        if (mounted && !_connected) {
          _reconnectAttempts++;
          _initSSH();
        }
      } else if (_reconnectAttempts >= _maxReconnectAttempts) {
        _terminal.write('\x1B[90mMax reconnect attempts reached. Tap Reconnect to try manually.\x1B[0m\r\n');
      }
    }
  }

  Duration _reconnectDelay() {
    // Exponential backoff: 2s, 4s, 8s, 16s, 30s
    final seconds = [2, 4, 8, 16, 30];
    final idx = _reconnectAttempts.clamp(0, seconds.length - 1);
    return Duration(seconds: seconds[idx]);
  }

  void _onDisconnect() {
    _keepAliveTimer?.cancel();
    if (!mounted) return;

    final wasConnected = _connected;
    setState(() => _connected = false);

    if (wasConnected) {
      _terminal.write('\r\n\x1B[33m--- Disconnected ---\x1B[0m\r\n');

      // Auto-reconnect if was previously connected
      if (_autoReconnect && _reconnectAttempts < _maxReconnectAttempts) {
        final delay = _reconnectDelay();
        _terminal.write('\x1B[90mReconnecting in ${delay.inSeconds}s...\x1B[0m\r\n');
        Future.delayed(delay, () {
          if (mounted && !_connected) {
            _reconnectAttempts++;
            _doReconnect();
          }
        });
      }
    }
  }

  Future<void> _doReconnect() async {
    _keepAliveTimer?.cancel();
    try { _session?.close(); } catch (_) {}
    try { _client?.close(); } catch (_) {}
    setState(() {
      _connecting = true;
      _connected = false;
    });
    await _initSSH();
  }

  Future<void> _manualReconnect() async {
    _reconnectAttempts = 0;
    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);
    await _doReconnect();
  }

  void _sendCtrl(String char) {
    if (_session == null || !_connected) return;
    final code = char.codeUnitAt(0) - 64;
    _session!.stdin.add(Uint8List.fromList([code]));
    HapticFeedback.lightImpact();
    setState(() => _ctrlActive = false);
  }

  Future<void> _pasteFromClipboard() async {
    if (_session == null || !_connected) return;

    try {
      // Use super_clipboard for native access
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) return;

      final reader = await clipboard.read();

      // Try plain text first
      if (reader.canProvide(Formats.plainText)) {
        final text = await reader.readValue(Formats.plainText);
        if (text != null && text.isNotEmpty) {
          _session!.stdin.add(utf8.encode(text));
          HapticFeedback.lightImpact();
          return;
        }
      }
    } catch (_) {}

    // Fallback to Flutter's built-in clipboard
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        _session!.stdin.add(utf8.encode(data.text!));
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  void _sendSpecialKey(List<int> bytes) {
    if (_session == null || !_connected) return;
    _session!.stdin.add(Uint8List.fromList(bytes));
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepAliveTimer?.cancel();
    _autoReconnect = false;
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
            _buildHeader(),
            Expanded(
              child: TerminalView(
                _terminal,
                key: _terminalKey,
                hardwareKeyboardOnly: false,
                keyboardType: TextInputType.text,
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  final ctrl = HardwareKeyboard.instance.isControlPressed;
                  // Ctrl+V or Ctrl+Shift+V — paste
                  if (ctrl &&
                      event.logicalKey == LogicalKeyboardKey.keyV) {
                    _pasteFromClipboard();
                    return KeyEventResult.handled;
                  }
                  // Enter
                  if (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter) {
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
              onPressed: _manualReconnect,
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
            _vkey('Paste', _pasteFromClipboard),
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
