import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:proyectoreservasihc/LoginPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa Firebase Auth
import 'package:proyectoreservasihc/VisualReserva.dart';
import 'package:intl/intl.dart'; // Importa el paquete intl

class AulasPage extends StatelessWidget {
  final String pisoId;

  AulasPage({required this.pisoId});

  Future<List<String>> obtenerAulas(String pisoId) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentReference pisoRef = firestore.collection('pisos').doc(pisoId);
    CollectionReference horariosRef = pisoRef.collection('horarios');
    QuerySnapshot snapshot = await horariosRef.get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<Map<String, String>> obtenerHorariosDisponibles(
      String pisoId, String aulaId) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference horariosRef =
        firestore.collection('pisos').doc(pisoId).collection('horarios');
    DocumentSnapshot aulaDoc = await horariosRef.doc(aulaId).get();

    if (!aulaDoc.exists) {
      return {};
    }

    Map<String, dynamic> aulaData = aulaDoc.data() as Map<String, dynamic>;
    Map<String, String> horariosDisponibles = {};
    aulaData.forEach((key, value) {
      if (value is String && value == 'Disponible') {
        horariosDisponibles[key] = value;
      }
    });

    return horariosDisponibles;
  }

  Future<void> actualizarEstadoHorario(
      String pisoId, String aulaId, String horario, String nuevoEstado) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentReference horarioRef = firestore
        .collection('pisos')
        .doc(pisoId)
        .collection('horarios')
        .doc(aulaId);

    await horarioRef.update({horario: nuevoEstado});
  }

  // Mapa que asocia el aula con el piso
  Map<String, String> aulaPisoMap = {
    "Aula 101": "piso1",
    "Aula 102": "piso1",
    "Aula 201": "piso2",
    "Aula 202": "piso2",
    "Aula 301": "piso3",
    "Aula 302": "piso3",
    // Agrega más aulas según corresponda
  };

// Función para guardar la reserva en Firestore
  Future<void> guardarReservaEnFirestore(
      String aula, String horario, DateTime fechaSeleccionada) async {
    FirebaseAuth auth = FirebaseAuth.instance;
    User? currentUser = auth.currentUser;

    if (currentUser != null) {
      String userEmail = currentUser.email ?? '';

      FirebaseFirestore firestore = FirebaseFirestore.instance;
      await firestore.collection('reservas').add({
        'usuario': userEmail,
        'aula': aula,
        'horario': horario,
        'fecha_reserva':
            fechaSeleccionada, // Fecha seleccionada en formato DateTime
        'calificacion': null, // Inicializa calificación en null
        'comentario': '', // Inicializa comentario vacío
        'fecha_creacion': FieldValue.serverTimestamp(), // Fecha de creación
      });
    }
  }

// Función para guardar la reserva y también almacenar la información localmente
  Future<void> guardarReserva(
      String aula, String horario, DateTime fechaSeleccionada) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedAula', aula);
    await prefs.setString('selectedHorario', horario);

    // Guardar la reserva en Firestore con la fecha seleccionada
    await guardarReservaEnFirestore(aula, horario, fechaSeleccionada);
  }

// Función para mostrar los detalles de la reserva
// Función para mostrar los detalles de la reserva
  void mostrarDetallesReserva(BuildContext context, String aula, String horario,
      DateTime fechaSeleccionada) {
    // Obtener el piso correspondiente
    String piso = aulaPisoMap[aula] ?? "Desconocido";

    // Formatear la fecha de la reserva seleccionada
    String fechaReserva = DateFormat('dd/MM/yyyy').format(fechaSeleccionada);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Reserva Exitosa"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Detalles de tu reserva:"),
            SizedBox(height: 10),
            Text("Aula: $aula"),
            Text("Piso: $piso"),
            Text("Horario: $horario"),
            Text(
                "Fecha de reserva: $fechaReserva"), // Mostrar la fecha seleccionada
            SizedBox(height: 20),
            Text("¿Qué te gustaría hacer ahora?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CalendarWithReservationsPage(
                    reservaId: '',
                  ),
                ),
              );
            },
            child: Text("Continuar reservando"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
            child: Text("Cerrar sesión"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Aulas Disponibles',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF1565C0),
      ),
      body: FutureBuilder<List<String>>(
        future: obtenerAulas(pisoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          List<String> aulas = snapshot.data ?? [];
          if (aulas.isEmpty) {
            return Center(child: Text('No hay aulas disponibles en este piso'));
          }

          return ListView.builder(
            itemCount: aulas.length,
            itemBuilder: (context, index) {
              String aulaId = aulas[index];
              return ExpansionTile(
                title: Text(
                  aulaId,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
                children: [
                  FutureBuilder<Map<String, String>>(
                    future: obtenerHorariosDisponibles(pisoId, aulaId),
                    builder: (context, horariosSnapshot) {
                      if (horariosSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (horariosSnapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                              child: Text(
                                  'Error al cargar horarios: ${horariosSnapshot.error}')),
                        );
                      }

                      Map<String, String> horarios =
                          horariosSnapshot.data ?? {};
                      if (horarios.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                              child: Text('No hay horarios disponibles')),
                        );
                      }

                      return Column(
                        children: horarios.entries.map((entry) {
                          return ListTile(
                            title: Text(
                              'Horario: ${entry.key}',
                              style: TextStyle(fontSize: 16),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                DateTime fechaSeleccionada =
                                    DateTime.now(); // Obtén la fecha actual
                                await guardarReserva(aulaId, entry.key,
                                    fechaSeleccionada); // Pasa la fecha seleccionada
                                await actualizarEstadoHorario(
                                    pisoId, aulaId, entry.key, 'Ocupado');
                                mostrarDetallesReserva(
                                    context,
                                    aulaId,
                                    entry.key,
                                    fechaSeleccionada); // Pasa la fecha seleccionada
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF1E88E5),
                              ),
                              child: Text(
                                'Reservar',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
