import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Sk Bags',
              style: textTheme.headlineLarge?.copyWith(
                color: primaryColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 40,
              ),
            ),
            SizedBox(height: 10,),
            Text(
              'Staff',
              style: textTheme.headlineLarge?.copyWith(
                color: primaryColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

