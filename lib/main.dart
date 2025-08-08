import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'login_loading_screen.dart'; // BU SATIRI EKLE
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('tr_TR', null);
  await Supabase.initialize(
    url: "https://rprxugnzyglgmrsubekc.supabase.co",
    anonKey:
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJwcnh1Z256eWdsZ21yc3ViZWtjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgyODY4MzMsImV4cCI6MjA2Mzg2MjgzM30.JLUshxRgPcyvvU_OQsdj-jou8CAlZXBwCJ0Hg-XO9xo",
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 2), () {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Kullanıcının oturumu açık → login yükleme ekranına git
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginLoadingScreen(user: user),
          ),
        );
      } else {
        // Oturum yok → login ekranına git
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image(
              image: AssetImage('assets/images/pp.png'),
              width: 150,
              height: 150,
            ),
            SizedBox(height: 24),

            // Yazı
            Text(
              "Uygulama Yükleniyor...",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
