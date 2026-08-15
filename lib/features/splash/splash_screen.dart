import 'package:flutter/material.dart';

import '../../utill/app_constants.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const _splashAsset = 'assets/splash-1080x1920.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      backgroundColor: AppConstants.primary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(_splashAsset, fit: BoxFit.cover),
          const Align(
            alignment: Alignment(0, 0.75),
            child: SizedBox(
              height: 26,
              width: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
