import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Essenza Store"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              Navigator.pushReplacementNamed(context, "/");
            },
          )
        ],
      ),
      body: const Center(
        child: Text(
          "Bienvenido al Dashboard",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
