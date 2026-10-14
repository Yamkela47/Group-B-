import 'package:flutter/material.dart';

class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const GoldButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label.toUpperCase()),
            if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 16)],
          ],
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GhostButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(label.toUpperCase()),
      ),
    );
  }
}