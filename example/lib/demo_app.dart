import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import 'pages/demo_catalog_page.dart';

class LiquidGlassDemoApp extends StatefulWidget {
  const LiquidGlassDemoApp({super.key});

  @override
  State<LiquidGlassDemoApp> createState() => _LiquidGlassDemoAppState();
}

class _LiquidGlassDemoAppState extends State<LiquidGlassDemoApp> {
  bool _isDarkTheme = false;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [LiquidGlassNavigatorObserver()],
      themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        
      ),
      darkTheme: ThemeData(brightness: Brightness.dark),
      home: DemoCatalogPage(
        onThemeChanged: (value) {
          setState(() {
            _isDarkTheme = value;
          });
        },
      ),
    );
  }
}
