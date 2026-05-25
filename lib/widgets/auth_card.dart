import 'dart:ui';
import 'package:flutter/material.dart';

class AuthCard extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget child;

  const AuthCard({
    super.key,
    this.title,
    this.titleWidget,
    required this.child,
  }) : assert(
          title != null || titleWidget != null,
          'Either title or titleWidget must be provided',
        );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER (text OR custom widget)
              if (titleWidget != null)
                titleWidget!
              else
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              const SizedBox(height: 24),

              // CONTENT
              child,
            ],
          ),
        ),
      ),
    );
  }
}
