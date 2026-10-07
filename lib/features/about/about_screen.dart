import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniPlayerColors.voidBlack,
      appBar: AppBar(
        backgroundColor: OmniPlayerColors.voidBlack,
        foregroundColor: OmniPlayerColors.cyan,
        title: Text('ABOUT', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 13)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: [
          Text(
            'Guru Morgan made OmniPlayer. AllTechGuru is the company behind it.',
            style: OmniPlayerTextStyles.rajdhaniSemi.copyWith(color: Colors.white.withOpacity(0.92), fontSize: 16),
          ),
          const SizedBox(height: 22),
          const _Heading('WHY THIS ONE'),
          const _Body(
            'I got tired of music apps that cover a third of the screen with an ad, and of extra features that hardly work. I build tools that have to be useful. An ad sitting in the way fails that test.',
          ),
          const _Body(
            'This is the first app I am putting on the Play Store. Of the tools I am working on, it was the least complicated one to finish. It is free. It stays free. No ads. No paywall.',
          ),
          const _Heading('THE DRIVE'),
          const _Body(
            'Once a year I drive to Missouri. It takes about eleven and a half hours. Long stretches of that road have no service. When the signal drops, the only music left is the radio, and most of that is commercials. I wanted my own songs on the phone, playing whether or not the road has a signal.',
          ),
          const _Heading('MUSIC YOU CAN KEEP'),
          const _Body(
            'I believe that listening to music, when you are not using it commercially, should be free. Music is a way of communicating. I know artists put a lot of time and money into the work, and for many of them it is the job. I still think those same artists can let some songs out for free.',
          ),
          const _Body(
            'Free Music in this app is that idea, kept legal. It lists recordings under a Creative Commons or public-domain license. You can hear a song before you save it. Nothing is stored until you choose to download it.',
          ),
          const _Heading('SONGS I RELEASED'),
          const _Link(label: 'The Frequency', url: 'https://atguru.xyz/the-frequency/'),
          const _Link(label: 'Rising Anyway', url: 'https://atguru.xyz/rising-anyway/'),
          const _Heading('ALLTECHGURU'),
          const _Body(
            'AllTechGuru is my company. The site is a think tank that ships. You bring a problem or a half-formed idea. I help you think it through, then build the thing: a leaner way to run a business, a resume that gets a callback, a custom app, automation for work you are still doing by hand, or a website.',
          ),
          const _Body('I build with a development system of my own. I have spent more than ten thousand hours on it.'),
          const _Link(label: 'atguru.xyz', url: 'https://atguru.xyz'),
          const _Link(label: 'guru_morgan@atguru.xyz', url: 'mailto:guru_morgan@atguru.xyz'),
          const _Heading('PRIVACY'),
          const _Link(label: 'Privacy policy', url: 'https://atguru.github.io/omniplayer-privacy/'),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Text(text, style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 11, letterSpacing: 2)),
    );
  }
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white.withOpacity(0.86), fontSize: 16, height: 1.35),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  final String label;
  final String url;
  const _Link({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => _open(context, Uri.parse(url)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label, style: OmniPlayerTextStyles.rajdhaniSemi.copyWith(color: OmniPlayerColors.cyan, fontSize: 16)),
      ),
    );
  }
}

Future<void> _open(BuildContext context, Uri uri) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that link.')));
  }
}
