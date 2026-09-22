import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A step-by-step manual for connecting a GPS service provider (AppFlow
/// §2.3) — reachable both from Settings' "Learn" section and from the
/// Connect GPS screen itself, since a company might land on either one
/// first. One tab per provider (ConnectGpsScreen's own GpsProviderOption
/// list), since each authenticates differently — see
/// TracksolidGpsProvider/TraccarGpsProvider/WialonGpsProvider on the
/// backend for what each step below is actually asking for.
class GpsConnectionGuideScreen extends StatelessWidget {
  const GpsConnectionGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Connect your GPS provider'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Wialon'),
              Tab(text: 'Traccar'),
              Tab(text: 'Tracksolid Pro'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ProviderGuide(
              intro:
                  'Wialon issues one long-lived API token per account — paste it straight into Cargo Motives.',
              steps: [
                (
                  title: 'Log in to Wialon',
                  body:
                      "Open your Wialon Hosting account in a browser and sign in with your usual username and password.",
                ),
                (
                  title: 'Open your account page',
                  body:
                      'Click your username in the top right corner, then choose your account or profile settings.',
                ),
                (
                  title: 'Create an API token',
                  body:
                      "Find the token / API access section and generate a new token. Choose the longest available duration so the connection doesn't expire unexpectedly.",
                ),
                (
                  title: 'Copy the token',
                  body:
                      "Copy the full token — it's a long string of letters and numbers.",
                ),
                (
                  title: 'Paste it into Cargo Motives',
                  body:
                      'Go to Fleet → Connect GPS, choose Wialon, paste the token, and tap Connect.',
                ),
              ],
              goodToKnow: [
                "If your token expires, just repeat these steps and reconnect — your trucks and their history stay in place.",
                "After connecting, you'll be asked to match each vehicle Wialon reports to a truck already in your fleet, or add it as a new one.",
              ],
            ),
            _ProviderGuide(
              intro:
                  'Traccar also uses a single API token, generated from your own Traccar server.',
              steps: [
                (
                  title: 'Log in to your Traccar server',
                  body:
                      "Open your Traccar server's web address in a browser and sign in.",
                ),
                (
                  title: 'Open your user page',
                  body:
                      'Click your name or avatar in the top right to open your own account page.',
                ),
                (
                  title: 'Generate a token',
                  body:
                      'Find the "Token" field on your account page and generate a new one.',
                ),
                (title: 'Copy the token', body: 'Copy the token text shown.'),
                (
                  title: 'Paste it into Cargo Motives',
                  body:
                      'Go to Fleet → Connect GPS, choose Traccar, paste the token, and tap Connect.',
                ),
              ],
              goodToKnow: [
                "If your token expires or is revoked, generate a new one and reconnect — your trucks and their history stay in place.",
                "After connecting, you'll be asked to match each vehicle Traccar reports to a truck already in your fleet, or add it as a new one.",
              ],
            ),
            _ProviderGuide(
              intro:
                  'Tracksolid Pro needs four pieces of information joined together with colons, since it authenticates differently from the other two providers. This one is more technical — ask your Tracksolid reseller if you get stuck.',
              steps: [
                (
                  title: 'Get API access',
                  body:
                      "Ask Tracksolid or your JIMI IoT reseller for API access to your account, if you don't already have it. They will give you an App Key and an App Secret.",
                ),
                (
                  title: 'Find your login details',
                  body:
                      "You'll also need the account ID (user ID) and password you normally use to log in to Tracksolid Pro.",
                ),
                (
                  title: "Get your password's MD5 hash",
                  body:
                      "Cargo Motives needs your password as an MD5 hash, not as plain text. If you're not sure how to generate this, ask your IT support or your Tracksolid reseller — they can usually do it for you.",
                ),
                (
                  title: 'Combine all four with colons',
                  body:
                      'Type them in this exact order, separated by colons, with nothing else in between: appKey:appSecret:account:passwordMD5Hash',
                ),
                (
                  title: 'Paste it into Cargo Motives',
                  body:
                      'Go to Fleet → Connect GPS, choose Tracksolid Pro, paste the combined text, and tap Connect.',
                ),
              ],
              goodToKnow: [
                'This is the most technical of the three providers to set up — your Tracksolid reseller can usually generate all four pieces for you directly.',
                "After connecting, you'll be asked to match each vehicle to a truck already in your fleet, or add it as a new one.",
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderGuide extends StatelessWidget {
  const _ProviderGuide({
    required this.intro,
    required this.steps,
    required this.goodToKnow,
  });

  final String intro;
  final List<({String title, String body})> steps;
  final List<String> goodToKnow;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(intro, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 22),
        for (var i = 0; i < steps.length; i++)
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
                      if (i != steps.length - 1)
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
                      bottom: i == steps.length - 1 ? 0 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: TextStyle(
                            fontFamily: 'Barlow Condensed',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          steps[i].body,
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
              for (var i = 0; i < goodToKnow.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  decoration: i == goodToKnow.length - 1
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
                          goodToKnow[i],
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
      ],
    );
  }
}
