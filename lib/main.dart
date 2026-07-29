import 'package:ayosuruh/navbar.dart';
import 'package:flutter/material.dart';
import 'customer_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/.env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANONKEY']!,
  );

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('GLOBAL ERROR ➜ ${details.exception}');
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AyoSuruh', 
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B5A2B)),
      ),
      
      home: const MainNavigation(), 
    );
  }
}

