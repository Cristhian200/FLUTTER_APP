import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Page'),
        centerTitle: true,
        backgroundColor: Colors.blue[900],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reservas Registradas:',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('reservas').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text(
                      'No hay reservas registradas.',
                      style: TextStyle(fontSize: 16),
                    );
                  }
                  final reservas = snapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: reservas.length,
                    itemBuilder: (context, index) {
                      final reserva = reservas[index];
                      final usuarioEmail = reserva['usuario']; // El campo 'usuario' en la reserva
                      final fechaReserva = reserva['fecha_reserva'].toDate(); // Campo 'fecha_reserva'
                      final fechaCreacion = reserva['fecha_creacion'].toDate(); // Campo 'fecha_creacion'
                      final aula = reserva['aula']; // Campo 'aula'
                      final horario = reserva['horario']; // Campo 'horario'
                      final calificacion = reserva['calificacion']; // Campo 'calificacion'
                      final comentario = reserva['comentario']; // Campo 'comentario'

                      return FutureBuilder<QuerySnapshot>(
                        future: _firestore
                            .collection('usuarios')
                            .where('email', isEqualTo: usuarioEmail) // Buscar por email
                            .limit(1)
                            .get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          // Check if the document exists
                          if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
                            return Card(
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ListTile(
                                title: Text(
                                  'Reserva en $aula',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                subtitle: const Text(
                                  'Usuario no encontrado.',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                tileColor: Colors.white,
                              ),
                            );
                          }

                          final usuario = userSnapshot.data!.docs.first;
                          return Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              title: Text(
                                'Reserva en $aula',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Usuario: ${usuario['nombre']} (${usuario['email']})',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Fecha de Creación: ${fechaCreacion.toLocal()}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      'Fecha de Reserva: ${fechaReserva.toLocal()}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      'Horario: $horario',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      'Comentario: ${comentario.isEmpty ? "Ningún comentario" : comentario}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      'Calificación: ${calificacion ?? "No calificada"}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                              tileColor: Colors.white,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
