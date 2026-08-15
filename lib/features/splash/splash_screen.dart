import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const _splashAsset = 'assets/splash-1080x1920.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SizedBox(
          width: 80,
          height: 80,
          child: Image.asset('assets/app-icon-1024.png'),
        ),
      ),
    );

  }
}
