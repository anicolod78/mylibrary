import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/book_repository.dart';
import 'providers/library_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BookRepository.init();
  final repo = BookRepository();
  runApp(MyLibraryApp(repository: repo));
}

class MyLibraryApp extends StatelessWidget {
  final BookRepository repository;
  const MyLibraryApp({super.key, required this.repository});

  // Teal coerente con l'interfaccia dell'app di riferimento.
  static const Color seed = Color(0xFF3E7C88);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LibraryProvider(repository),
      child: MaterialApp(
        title: 'La mia libreria',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          appBarTheme: const AppBarTheme(
            backgroundColor: seed,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
