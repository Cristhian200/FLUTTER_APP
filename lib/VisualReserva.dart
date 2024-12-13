import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth
import 'package:proyectoreservasihc/About.dart';
import 'package:proyectoreservasihc/LoginPage.dart';
import 'package:proyectoreservasihc/MisReservas.dart';
import 'package:table_calendar/table_calendar.dart'; // Calendario
import 'Pisos.dart'; // Página de Pisos

class CalendarWithReservationsPage extends StatefulWidget {
  final String reservaId;

  const CalendarWithReservationsPage({super.key, required this.reservaId});

  @override
  _CalendarWithReservationsPageState createState() =>
      _CalendarWithReservationsPageState();
}

class _CalendarWithReservationsPageState
    extends State<CalendarWithReservationsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, String>>> _reservations = {};
  DateTime? _lastTappedDate;
  final _doubleTapThreshold = const Duration(milliseconds: 300);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _profileImage = 'lib/pictures/default.png';

  @override
  void initState() {
    super.initState();
    _loadReservations(); // Cargar las reservas al iniciar
    _loadUserProfile(); // Cargar el perfil del usuario
  }

  // Función para cargar el perfil del usuario desde Firebase
  Future<void> _loadUserProfile() async {
    User? currentUser = _auth.currentUser; // Usuario autenticado
    if (currentUser != null) {
      String userEmail = currentUser.email ?? '';

      try {
        // Consulta Firestore para obtener el género del usuario
        DocumentSnapshot userDoc =
            await _firestore.collection('usuarios').doc(userEmail).get();

        if (userDoc.exists) {
          String genero = userDoc['genero'] ?? 'hombre'; // Valor predeterminado

          setState(() {
            _profileImage = genero == 'hombre'
                ? 'lib/pictures/hombre.png'
                : (genero == 'mujer'
                    ? 'lib/pictures/mujer.png'
                    : 'lib/pictures/default.png');
          });
        }
      } catch (e) {
        print('Error cargando el perfil del usuario: $e');
      }
    }
  }

  // Método para cargar las reservas desde Firestore
  Future<void> _loadReservations() async {
    try {
      // Obtén las reservas desde Firestore
      QuerySnapshot snapshot = await _firestore.collection('reservas').get();

      Map<DateTime, List<Map<String, String>>> loadedReservations = {};

      for (var doc in snapshot.docs) {
        try {
          // Verifica si el campo 'fecha_reserva' existe y es un Timestamp
          if (doc['fecha_reserva'] != null &&
              doc['fecha_reserva'] is Timestamp) {
            // Convierte el Timestamp a DateTime
            DateTime fecha = (doc['fecha_reserva'] as Timestamp).toDate();

            // Otros campos
            String aula = doc['aula'] ??
                'Aula no especificada'; // Manejo de valores nulos
            String horario = doc['horario'] ?? 'Horario no especificado';
            String usuario = doc['usuario'] ?? 'Usuario no especificado';

            // Agrega la reserva al mapa, usando la fecha como clave
            if (loadedReservations[fecha] == null) {
              loadedReservations[fecha] = [];
            }
            loadedReservations[fecha]!.add({
              'aula': aula,
              'horario': horario,
              'usuario': usuario,
            });
          } else {
            print(
                'El campo "fecha_reserva" no existe o no es un Timestamp en el documento con ID: ${doc.id}');
          }
        } catch (e) {
          print('Error procesando el documento: ${e.toString()}');
        }
      }

      setState(() {
        _reservations = loadedReservations;
      });
    } catch (e) {
      print('Error al cargar las reservas: $e');
    }
  }

  // Función para manejar la selección de una fecha en el calendario
  // Función para manejar la selección de una fecha en el calendario
void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
  // Bloquear la selección de fechas anteriores a la fecha actual
  if (selectedDay.isBefore(DateTime.now())) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No puedes seleccionar ni el día de hoy ni fechas anteriores.'),
      ),
    );
    return; // No permite seleccionar una fecha anterior a hoy
  }

  // Manejo de doble clic
  if (_lastTappedDate != null &&
      DateTime.now().difference(_lastTappedDate!) < _doubleTapThreshold &&
      isSameDay(selectedDay, _lastTappedDate!)) {
    _navigateToPisosPage(); // Navegar a la página de Pisos
  } else {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _lastTappedDate =
          selectedDay; // Actualizar la última fecha seleccionada
    });
  }
}


  // Navegar a la página de Pisos
  void _navigateToPisosPage() {
    if (_selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor selecciona una fecha antes de continuar')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PisosPage(
          selectedDate: _selectedDay!,
        ),
      ),
    );
  }

  // Construir el Drawer con el menú
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text('Usuario'),
            accountEmail: Text(_auth.currentUser?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundImage: AssetImage(_profileImage), // Imagen de perfil
            ),
            decoration: BoxDecoration(color: Colors.blue[900]),
          ),
          ListTile(
            leading: Icon(Icons.bookmark, color: Colors.blue[900]),
            title: const Text('Mis Reservas'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const MisReservasPage()), // Navegar a Mis Reservas
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.info, color: Colors.blue[900]),
            title: const Text('About'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AboutPage()), // Navegar a About
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Cerrar Sesión'),
            onTap: () {
              _auth.signOut(); // Cerrar sesión
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const LoginPage()), // Navegar a LoginPage
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario de Reservas'),
        centerTitle: true,
      ),
      drawer: _buildDrawer(), // Añadir el Drawer al Scaffold
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2020, 01, 01),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              onDaySelected: _onDaySelected,
              calendarFormat:
                  CalendarFormat.month, // Se mantiene solo en formato mensual
              availableGestures:
                  AvailableGestures.all, // Habilita gestos de deslizamiento
              headerStyle: const HeaderStyle(
                formatButtonVisible:
                    false, // Quita el botón de formato de "2 weeks"
                titleCentered: true, // Centra el título del mes/año
                leftChevronVisible:
                    true, // Habilita el botón para ir al mes anterior
                rightChevronVisible:
                    true, // Habilita el botón para ir al siguiente mes
                headerMargin:
                    EdgeInsets.only(bottom: 8), // Márgenes para el header
                titleTextStyle:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay; // Actualiza el mes mostrado
                });
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (_reservations.containsKey(date)) {
                    return const Positioned(
                      bottom: 1,
                      right: 1,
                      child: Icon(
                        Icons.circle,
                        color: Colors.blue,
                        size: 12,
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            const SizedBox(height: 10),
            // Mensaje bajo el calendario
            const Text(
              'Por favor haz doble tap en la fecha que deseas. Como recordatorio, no debe ser la misma de hoy.',
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
