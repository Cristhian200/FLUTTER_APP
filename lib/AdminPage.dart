import 'package:flutter/material.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Page'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Bienvenido a la página de administración',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
