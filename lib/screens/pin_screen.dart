import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class PinScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool isSetup; // true = setting new PIN, false = verifying

  final Future<bool> Function(String pin) onSubmit;

  const PinScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.isSetup = false,
    required this.onSubmit,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String? _firstPin; // For setup: store first entry
  String? _error;
  bool _confirming = false;

  String get _currentTitle {
    if (widget.isSetup && _confirming) return 'Confirm PIN';
    return widget.title;
  }

  void _addDigit(String digit) {
    if (_pin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) {
      _handleComplete();
    }
  }

  void _delete() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _handleComplete() async {
    if (widget.isSetup) {
      if (!_confirming) {
        // First entry
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _confirming = true;
        });
        return;
      }
      // Confirm entry
      if (_pin != _firstPin) {
        setState(() {
          _pin = '';
          _error = 'PINs don\'t match. Try again.';
          _confirming = false;
          _firstPin = null;
        });
        return;
      }
    }

    final ok = await widget.onSubmit(_pin);
    if (!ok && mounted) {
      setState(() {
        _pin = '';
        _error = 'Wrong PIN';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Icon(
              Icons.lock_rounded,
              size: 44,
              color: AppTheme.seedColor.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 20),
            Text(
              _currentTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.subtitle != null && !_confirming) ...[
              const SizedBox(height: 6),
              Text(
                widget.subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
            const SizedBox(height: 32),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? AppTheme.seedColor
                        : Colors.transparent,
                    border: Border.all(
                      color: filled
                          ? AppTheme.seedColor
                          : Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 13,
                ),
              ),
            ],
            const Spacer(flex: 1),
            // Numpad
            _buildNumpad(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['1', '2', '3'].map(_numKey).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['4', '5', '6'].map(_numKey).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['7', '8', '9'].map(_numKey).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72),
              _numKey('0'),
              SizedBox(
                width: 72,
                height: 72,
                child: IconButton(
                  onPressed: _delete,
                  icon: Icon(
                    Icons.backspace_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numKey(String digit) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addDigit(digit),
          borderRadius: BorderRadius.circular(36),
          splashColor: AppTheme.seedColor.withValues(alpha: 0.2),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Center(
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
