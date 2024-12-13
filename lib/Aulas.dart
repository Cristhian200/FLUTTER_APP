import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:proyectoreservasihc/MisReservas.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proyectoreservasihc/VisualReserva.dart';
import 'package:intl/intl.dart';
import 'package:proyectoreservasihc/LoginPage.dart';

class AulasPage extends StatefulWidget {
  final String pisoId;
  final DateTime selectedDate;

  const AulasPage(
      {super.key, required this.pisoId, required this.selectedDate});

  @override
  _AulasPageState createState() => _AulasPageState();
}

class _AulasPageState extends State<AulasPage> {
  final Map<String, bool> _isProcessing =
      {}; // Estado de carga para cada aula-horario

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

    // Convertir las claves del mapa a una lista y ordenarlas
    List<String> horariosOrdenados = horariosDisponibles.keys.toList();
    horariosOrdenados
        .sort(); // Esto ordenará los horarios de forma ascendente (por ejemplo, '08:00', '09:00', ...)

    // Crear un nuevo mapa con los horarios ordenados
    Map<String, String> horariosOrdenadosMap = {};
    for (String horario in horariosOrdenados) {
      horariosOrdenadosMap[horario] = horariosDisponibles[horario]!;
    }

    return horariosOrdenadosMap;
  }

  Future<void> guardarReservaEnFirestore(
      String aula, String horario, DateTime fechaSeleccionada) async {
    FirebaseAuth auth = FirebaseAuth.instance;
    User? currentUser = auth.currentUser;

    if (currentUser != null) {
      String userEmail = currentUser.email ?? '';

      // Captura la hora exacta del dispositivo
      DateTime fechaReservaConHora = DateTime(
        fechaSeleccionada.year,
        fechaSeleccionada.month,
        fechaSeleccionada.day,
        DateTime.now().hour,
        DateTime.now().minute,
        DateTime.now().second,
      );

      FirebaseFirestore firestore = FirebaseFirestore.instance;
      await firestore.collection('reservas').add({
        'usuario': userEmail,
        'aula': aula,
        'horario': horario,
        'fecha_reserva': fechaReservaConHora, // Guarda la fecha y hora exactas
        'calificacion': null,
        'comentario': '',
        'fecha_creacion': FieldValue.serverTimestamp(), // Hora del servidor
      });
    }
  }

  Future<void> guardarReserva(
      String aula, String horario, DateTime fechaSeleccionada) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedAula', aula);
    await prefs.setString('selectedHorario', horario);

    await guardarReservaEnFirestore(aula, horario, fechaSeleccionada);
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

  void mostrarDetallesReserva(BuildContext context, String aula, String horario,
      DateTime fechaSeleccionada) {
    String fechaReserva = DateFormat('dd/MM/yyyy').format(fechaSeleccionada);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reserva Exitosa"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Detalles de tu reserva:"),
            const SizedBox(height: 10),
            Text("Aula: $aula"),
            Text("Horario: $horario"),
            Text("Fecha de reserva: $fechaReserva"),
            const SizedBox(height: 20),
            const Text("¿Qué te gustaría hacer ahora?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar el diálogo
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CalendarWithReservationsPage(
                    reservaId: '',
                  ),
                ),
              );
            },
            child: const Text("Continuar reservando"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar el diálogo
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text("Cerrar sesión"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar el diálogo
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const MisReservasPage(), // Ir a Mis Reservas
                ),
              );
            },
            child: const Text("Ver mis reservas"),
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
          'Aulas Disponibles (${DateFormat('dd/MM/yyyy').format(widget.selectedDate)})',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: FutureBuilder<List<String>>(
        future: obtenerAulas(widget.pisoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          List<String> aulas = snapshot.data ?? [];
          if (aulas.isEmpty) {
            return const Center(
                child: Text('No hay aulas disponibles en este piso'));
          }

          return ListView.builder(
            itemCount: aulas.length,
            itemBuilder: (context, index) {
              String aulaId = aulas[index];
              return ExpansionTile(
                title: Text(
                  aulaId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
                children: [
                  FutureBuilder<Map<String, String>>(
                    future: obtenerHorariosDisponibles(widget.pisoId, aulaId),
                    builder: (context, horariosSnapshot) {
                      if (horariosSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
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
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                              child: Text('No hay horarios disponibles')),
                        );
                      }

                      return Column(
                        children: horarios.entries.map((entry) {
                          String uniqueKey = '${aulaId}_${entry.key}';
                          return ListTile(
                            title: Text(
                              'Horario: ${entry.key}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            trailing: ElevatedButton(
                              onPressed: _isProcessing[uniqueKey] == true
                                  ? null
                                  : () async {
                                      setState(() {
                                        _isProcessing[uniqueKey] = true;
                                      });
                                      await guardarReserva(aulaId, entry.key,
                                          widget.selectedDate);
                                      await actualizarEstadoHorario(
                                          widget.pisoId,
                                          aulaId,
                                          entry.key,
                                          'Ocupado');
                                      mostrarDetallesReserva(context, aulaId,
                                          entry.key, widget.selectedDate);
                                      setState(() {
                                        _isProcessing[uniqueKey] = false;
                                      });
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                              ),
                              child: _isProcessing[uniqueKey] == true
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
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
