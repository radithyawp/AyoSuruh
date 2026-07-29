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
      title: 'Ayo Suruh', // Anda bisa mengubah judul aplikasinya
      debugShowCheckedModeBanner: false, // Opsional: Menghilangkan pita "DEBUG" di kanan atas
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B5A2B)),
      ),
      // 2. Ubah properti 'home' ini agar mengarah ke halaman yang baru kita buat
      home: const DashboardPage(), 
    );
  }
}

// Catatan: Anda bisa menghapus kelas MyHomePage dan _MyHomePageState 
// dari file main.dart karena kode bawaan *counter app* tersebut sudah 
// tidak kita gunakan lagi.