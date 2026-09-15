import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// "How Cargo Motives works" (mockup) — a real, accurate description of
/// this app's actual flow (not fabricated content): post a load, compare
/// verified transporters' bids, track the truck live, pay the transporter
/// directly. Shared by both roles' Settings screens.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  static const _steps = [
    (
      title: 'Post your cargo',
      body:
          'Say where the load moves, what it is, when it must be collected, and set your budget. Posting is free.',
    ),
    (
      title: 'Compare offers',
      body:
          'Verified transporters bid on your load. You see their rating, verified truck count, and whether GPS is connected before you choose.',
    ),
    (
      title: 'Track the truck',
      body:
          'Follow the load from pickup to delivery, and message the driver in the app. You are notified at every checkpoint.',
    ),
    (
      title: 'Pay and confirm',
      body:
          'You pay the transporter directly by mobile money or bank transfer. Cargo Motives does not hold your money — we record the booking and the delivery note.',
    ),
  ];

  static const _goodToKnow = [
    'Every transporter is checked by our team — licence, TIN and insurance — before they can bid.',
    'Transporters only see your district until you accept an offer, never your exact address.',
    'You can reopen this guide any time from Settings.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How Cargo Motives works')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Four steps from posting cargo to a signed delivery note.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          for (var i = 0; i < _steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 34,
                    child: Column(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.brandChip,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontFamily: 'Barlow Condensed',
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (i != _steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: AppColors.border,
                              margin: const EdgeInsets.only(top: 6),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i == _steps.length - 1 ? 0 : 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _steps[i].title,
                            style: TextStyle(
                              fontFamily: 'Barlow Condensed',
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _steps[i].body,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  color: AppColors.surfaceSubtle,
                  child: Text(
                    'GOOD TO KNOW',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLabel,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                for (var i = 0; i < _goodToKnow.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    decoration: i == _goodToKnow.length - 1
                        ? null
                        : BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.background),
                            ),
                          ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.statusLive,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _goodToKnow[i],
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textLabel,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }
}
