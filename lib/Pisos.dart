import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Aulas.dart'; // Firestore

class PisosPage extends StatelessWidget {
  final DateTime selectedDate;

  // Constructor para recibir la fecha seleccionada
  const PisosPage({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seleccionar Piso',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[900], // Azul en la barra
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('pisos').get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Error al cargar los pisos',
                    style: TextStyle(color: Colors.blue[900])));
          }

          final pisos = snapshot.data?.docs ?? [];

          if (pisos.isEmpty) {
            return Center(
                child: Text('No hay pisos disponibles',
                    style: TextStyle(color: Colors.blue[900])));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: pisos.length,
            itemBuilder: (context, index) {
              final piso = pisos[index];
              final pisoNombre = piso['nombre'];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 5,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    pisoNombre,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900]),
                  ),
                  trailing:
                      Icon(Icons.arrow_forward_ios, color: Colors.blue[900]),
                  onTap: () {
                    // Navegar a AulasPage pasando pisoId y selectedDate
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AulasPage(
                          pisoId: piso.id,
                          selectedDate: selectedDate,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
