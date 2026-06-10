import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RotatingSyncButton extends StatefulWidget {
  final Future<void> Function() onSync;

  const RotatingSyncButton({super.key, required this.onSync});

  @override
  State<RotatingSyncButton> createState() => _RotatingSyncButtonState();
}

class _RotatingSyncButtonState extends State<RotatingSyncButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
    });
    _controller.repeat();
    try {
      await widget.onSync();
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: IconButton(
        icon: const Icon(CupertinoIcons.refresh),
        onPressed: _handleSync,
        tooltip: 'Sync',
      ),
    );
  }
}
