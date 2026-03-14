import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TerminalView extends StatefulWidget {
  final List<String> lines;
  final bool isActive;

  const TerminalView({
    super.key,
    required this.lines,
    this.isActive = true,
  });

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lines.length != oldWidget.lines.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getLineColor(String line) {
    if (line.startsWith('❌') || line.contains('[ERROR]')) {
      return const Color(0xFFFF6B6B);
    }
    if (line.startsWith('✅') || line.startsWith('🎉')) {
      return const Color(0xFF00B894);
    }
    if (line.startsWith('⚠️')) {
      return const Color(0xFFFDAA5E);
    }
    if (line.startsWith('🔌') || line.startsWith('📋') || line.startsWith('📦')) {
      return const Color(0xFF74B9FF);
    }
    if (line.startsWith('━━━')) {
      return const Color(0xFF6C5CE7);
    }
    if (line.startsWith('>>>')) {
      return const Color(0xFF00D2D3);
    }
    if (line.startsWith('<<<')) {
      return const Color(0xFF00B894).withValues(alpha: 0.7);
    }
    return Colors.white.withValues(alpha: 0.7);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          // Terminal header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF12122A),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isActive
                        ? const Color(0xFF00B894)
                        : const Color(0xFF636e72),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'servershot — deployment',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                if (widget.isActive)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          // Terminal body
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: widget.lines.length,
              itemBuilder: (context, index) {
                final line = widget.lines[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0.5),
                  child: Text(
                    line,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      height: 1.5,
                      color: _getLineColor(line),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
