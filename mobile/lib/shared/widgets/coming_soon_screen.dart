import 'package:flutter/material.dart';

/// Stand-in for a role's home shell until its real screens are built.
/// Used by the Customer and Transporter Company routes today; each gets
/// replaced by its actual bottom-nav shell (Customer: Jobs/Post/Profile;
/// Company: Jobs/Fleet/Earnings/Profile — UI/UX Brief §3) starting Phase 1.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_shipping_outlined, size: 48, color: Color(0xFF9E9E9E)),
              const SizedBox(height: 16),
              Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
