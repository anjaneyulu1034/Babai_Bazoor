import 'package:babai_bazor_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class BbPrimaryButton extends StatelessWidget {
  const BbPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
    this.backgroundColor = AppColors.primaryOrange,
    this.foregroundColor = Colors.white,
    this.height = 50,
  });

  final String label;
  final VoidCallback onPressed;
  final bool expanded;
  final Color backgroundColor;
  final Color foregroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final child = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: Size.fromHeight(height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed,
      child: Text(label),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}
