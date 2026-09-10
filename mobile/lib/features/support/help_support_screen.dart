import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'how_it_works_screen.dart';

/// "Help & Support" (mockup) — shared by both roles. The FAQ answers are
/// real, accurate statements about how this app actually works (not
/// fabricated). "Start a chat"/"Call" have no real support channel wired
/// up yet (no phone number is provisioned, and chat in this app is always
/// scoped to a specific job's transporter, not a general help line) —
/// tapping them explains that honestly rather than dialing a placeholder
/// number or opening a channel that doesn't exist. "Your tickets" is a
/// real, empty section: a customer's disputes can only be created (via
/// Report a Problem on a delivered shipment), there is no listing
/// endpoint yet, so nothing fabricated is shown here.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    (
      'When is my transporter paid?',
      'You pay the transporter directly through mobile money or bank transfer when you book. Cargo Motives does not hold your money at any point.',
    ),
    (
      'What if the truck does not arrive?',
      'Message the transporter from the shipment first. If it stays unresolved after pickup, use Report a Problem on the shipment once it reaches "delivered" to raise it with our team.',
    ),
    (
      'Is my cargo insured?',
      'Cargo Motives does not provide cargo insurance directly — check with your chosen transporter about their own coverage before accepting an offer.',
    ),
    (
      'How do I cancel a booking?',
      'Open the shipment from My Shipments — a job can be cancelled while it is still open or assigned, before pickup.',
    ),
    (
      'Why can\'t I see the driver\'s location?',
      'Live tracking needs the assigned truck\'s GPS connected. If it shows "GPS Tracking Not Available", the transporter hasn\'t connected that truck\'s GPS yet.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need help with a shipment?',
                  style: TextStyle(fontFamily: 'Barlow Condensed', fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Open the shipment in question and use its Messages button to reach the transporter directly.',
                  style: TextStyle(fontSize: 13, color: AppColors.lightBlue, height: 1.5),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Open a shipment from My Shipments, then tap the chat icon to message that transporter.'),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0x29FFFFFF)),
                          backgroundColor: const Color(0x17FFFFFF),
                        ),
                        child: const Text('Start a chat'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('A support phone line isn\'t set up yet — use in-app chat for now.'))),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0x29FFFFFF)),
                          backgroundColor: const Color(0x17FFFFFF),
                        ),
                        child: const Text('Call support'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'COMMON QUESTIONS',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLabel, letterSpacing: 0.7),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: AppColors.background),
              child: Column(
                children: [
                  for (final faq in _faqs)
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 13),
                      childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
                      expandedAlignment: Alignment.centerLeft,
                      title: Text(faq.$1, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                      children: [Text(faq.$2, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.55))],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LEARN',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLabel, letterSpacing: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HowItWorksScreen())),
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
                alignment: Alignment.center,
                child: const Icon(Icons.menu_book_outlined, size: 15),
              ),
              title: const Text('How Cargo Motives works', style: TextStyle(fontSize: 14.5)),
              subtitle: const Text('The four-step guide, any time', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'YOUR TICKETS',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLabel, letterSpacing: 0.7),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'No tickets yet. Reporting a problem on a delivered shipment opens one for our team to review.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
