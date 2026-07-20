import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'injection_container.dart' as di;
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart'; // Jalankan 'flutterfire configure' untuk generate file ini

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.initDependencies();
  
  // Setup Firebase (Uncomment setelah mengonfigurasi Firebase via Flutterfire CLI)
  /*
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }
  */


  // Memaksa status bar hitam secara global
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light, 
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniByte Demo App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Menyesuaikan dengan setelan mode perangkat (Light/Dark)
      home: const HomePage(),
    );
  }
}
