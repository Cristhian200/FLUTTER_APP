import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MisReservasPage extends StatefulWidget {
  @override
  _MisReservasPageState createState() => _MisReservasPageState();
}

class _MisReservasPageState extends State<MisReservasPage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Mis Reservas'),
          centerTitle: true,
        ),
        body: Center(
          child: Text('Debes iniciar sesión para ver tus reservas.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Mis Reservas'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reservas') // Colección de reservas
            .where('usuario',
                isEqualTo:
                    user.email) // Filtra por el correo electrónico del usuario
            .snapshots(),
        builder: (context, snapshot) {
          // Si los datos están cargando, muestra un indicador de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          // Si no hay datos o la consulta no devuelve resultados, muestra un mensaje
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No tienes reservas.'));
          }

          // Extrae las reservas del snapshot de Firestore
          final reservas = snapshot.data!.docs;

          // Muestra las reservas en una lista
          return ListView.builder(
            itemCount: reservas.length,
            itemBuilder: (context, index) {
              var reserva = reservas[index];
              var fechaReserva =
                  (reserva['fecha_reserva'] as Timestamp).toDate();
              var formattedDate =
                  DateFormat('dd/MM/yyyy HH:mm').format(fechaReserva);

              return ListTile(
                title: Text(reserva['aula']),
                subtitle: Text(
                    'Fecha: $formattedDate - Horario: ${reserva['horario']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue[900]),
                      onPressed: () {
                        _editarReserva(context,
                            reserva.id); // Llamada para editar la reserva
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.blue[900]),
                      onPressed: () {
                        _cancelarReserva(context,
                            reserva.id); // Llamada para cancelar la reserva
                      },
                    ),
                    // Agregar icono para calificar
                    IconButton(
                      icon: Icon(Icons.star_border, color: Colors.yellow[700]),
                      onPressed: () {
                        _calificarReserva(
                            context,
                            reserva.id,
                            reserva[
                                'calificacion']); // Llamada para calificar la reserva
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _editarReserva(BuildContext context, String reservaId) {
    if (reservaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ID de reserva inválido.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditReservationPage(
          reservationId: reservaId, // Página para editar el horario
        ),
      ),
    );
  }

  Map<String, String> aulaPisoMap = {
    "Aula 101": "piso1",
    "Aula 102": "piso1",
    "Aula 201": "piso2",
    "Aula 202": "piso2",
    "Aula 301": "piso3",
    "Aula 302": "piso3",
    // Continúa agregando las aulas y pisos según sea necesario
  };

  // Función para cancelar la reserva
  void _cancelarReserva(BuildContext context, String reservaId) async {
    try {
      // Obtener los datos de la reserva desde Firestore
      final reservaSnapshot = await FirebaseFirestore.instance
          .collection('reservas')
          .doc(reservaId)
          .get();

      if (!reservaSnapshot.exists) {
        throw Exception('La reserva no existe.');
      }

      final reservaData = reservaSnapshot.data();
      if (reservaData == null ||
          !reservaData.containsKey('aula') ||
          !reservaData.containsKey('horario')) {
        throw Exception('La reserva no contiene los datos necesarios.');
      }

      String aula = reservaData['aula'];
      String horario = reservaData['horario'];
      String? piso = aulaPisoMap[aula]; // Usamos el mapa de aulas a pisos

      if (piso == null) {
        throw Exception('El aula no está asociada a un piso.');
      }

      // Referencia al documento de la subcolección de horarios para el aula en el piso correspondiente
      final aulaDocRef = FirebaseFirestore.instance
          .collection('pisos')
          .doc(piso)
          .collection('horarios')
          .doc(aula);

      // Cargar los horarios del aula
      final aulaSnapshot = await aulaDocRef.get();
      if (!aulaSnapshot.exists) {
        throw Exception('El aula no existe en los horarios.');
      }

      // Obtener los horarios actuales
      Map<String, dynamic> horarios =
          Map<String, dynamic>.from(aulaSnapshot.data()!);

      // Liberar el horario ocupado
      if (horarios.containsKey(horario)) {
        horarios[horario] = "Disponible"; // Liberar el horario
        await aulaDocRef.update(horarios); // Actualizar en Firestore
      } else {
        throw Exception('El horario no está registrado en el aula.');
      }

      // Eliminar la reserva de la colección 'reservas'
      await FirebaseFirestore.instance
          .collection('reservas')
          .doc(reservaId)
          .delete();

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reserva cancelada y horario liberado.')),
      );
    } catch (e) {
      print('Error al cancelar la reserva: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar la reserva.')),
      );
    }
  }

  // Función para calificar la reserva
  void _calificarReserva(
      BuildContext context, String reservaId, int? currentRating) {
    TextEditingController comentarioController =
        TextEditingController(); // Controlador para el comentario

    showDialog(
      context: context,
      builder: (BuildContext context) {
        int rating = currentRating ??
            0; // Si ya existe una calificación, usarla; si no, usar 0.

        return StatefulBuilder(
          // Para manejar el estado dentro del diálogo.
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Calificar Reserva'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Por favor, califica la reserva'),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating
                              ? Icons.star
                              : Icons
                                  .star_border, // Estrella llena o borde según la calificación.
                          color: Colors.yellow[700],
                        ),
                        onPressed: () {
                          setState(() {
                            rating = index +
                                1; // Actualiza la calificación al hacer clic en una estrella.
                          });
                        },
                      );
                    }),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: comentarioController,
                    decoration: InputDecoration(
                      labelText: 'Deja un comentario',
                      hintText: 'Escribe aquí tu comentario...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    String comentario = comentarioController.text;

                    // Actualizar la calificación y comentario en Firestore.
                    await FirebaseFirestore.instance
                        .collection('reservas')
                        .doc(reservaId)
                        .update({
                      'calificacion': rating,
                      'comentario': comentario,
                    });

                    // Mostrar mensaje de éxito.
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Reserva calificada y comentada!')));
                    Navigator.pop(context);
                  },
                  child: Text('Calificar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class EditReservationPage extends StatefulWidget {
  final String reservationId;

  EditReservationPage({required this.reservationId});

  @override
  _EditReservationPageState createState() => _EditReservationPageState();
}

class _EditReservationPageState extends State<EditReservationPage> {
  final TextEditingController _horarioController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _piso;
  String? _aula;
  String? _oldHorario;
  List<String> _horariosDisponibles = []; // Lista de horarios disponibles
  String? _selectedHorario; // Horario seleccionado

  // Mapeo de aulas a pisos
  static const Map<String, String> aulaPisoMap = {
    "Aula 101": "piso1",
    "Aula 102": "piso1",
    "Aula 201": "piso2",
    "Aula 202": "piso2",
    "Aula 301": "piso3",
    "Aula 302": "piso3",

    // Agrega más aulas aquí
  };

  @override
  void initState() {
    super.initState();
    _loadReservationData();
  }

  Future<void> _loadReservationData() async {
    try {
      final docSnapshot = await _firestore
          .collection('reservas')
          .doc(widget.reservationId)
          .get();

      if (!docSnapshot.exists) {
        throw Exception('La reserva no existe.');
      }

      final data = docSnapshot.data();
      if (data == null ||
          !data.containsKey('aula') ||
          !data.containsKey('horario')) {
        throw Exception('El documento no contiene los campos requeridos.');
      }

      setState(() {
        _aula = data['aula'];
        _oldHorario = data['horario'];
        _horarioController.text = _oldHorario ?? '';

        // Obtener el piso asociado al aula desde el mapa
        _piso = aulaPisoMap[_aula!] ?? 'piso desconocido';
      });
    } catch (e) {
      print('Error al cargar los datos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar la reserva: $e')),
      );
    }
  }

  Future<void> _updateReservation() async {
    try {
      String newHorario = _horarioController.text.trim();

      if (newHorario.isEmpty || !_isValidHorario(newHorario)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Por favor ingresa un horario válido (formato: 10:00 - 11:00).')),
        );
        return;
      }

      if (_piso == null || _aula == null || _oldHorario == null) {
        throw Exception(
            'Datos incompletos. No se puede actualizar la reserva.');
      }

      // Referencia al documento del aula en la subcolección `/horarios`
      final aulaDocRef = _firestore
          .collection('pisos')
          .doc(_piso!) // Uso dinámico del piso
          .collection('horarios')
          .doc(_aula!);

      // Cargar los horarios actuales del aula
      final aulaSnapshot = await aulaDocRef.get();
      if (!aulaSnapshot.exists) {
        throw Exception('El aula no existe en los horarios.');
      }

      Map<String, dynamic> horarios =
          Map<String, dynamic>.from(aulaSnapshot.data()!);

      // Verificar si el nuevo horario ya está ocupado
      if (horarios.containsKey(newHorario) &&
          horarios[newHorario] == "Ocupado") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El horario seleccionado ya está ocupado.')),
        );
        return;
      }

      // Actualizar los horarios
      horarios[_oldHorario!] = "Disponible"; // Liberar el horario antiguo
      horarios[newHorario] = "Ocupado"; // Ocupamos el nuevo horario

      // Actualizar en Firebase
      await aulaDocRef.update(horarios);

      // Actualizar la colección de reservas
      await _firestore.collection('reservas').doc(widget.reservationId).update({
        'horario': newHorario,
      });

      // Notificar éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reserva actualizada con éxito.')),
      );

      // Regresar a la página anterior
      Navigator.pop(context);
    } catch (e) {
      print('Error al actualizar la reserva: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la reserva.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar Reserva')),
      body: _aula == null || _oldHorario == null || _piso == null
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editar horario para el $_aula en el  $_piso',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _horarioController,
                    decoration: InputDecoration(
                      labelText: 'Nuevo horario',
                      hintText: 'Ejemplo: 10:00 - 11:00',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _updateReservation,
                    child: Text('Actualizar Horario'),
                  ),
                ],
              ),
            ),
    );
  }

  bool _isValidHorario(String text) {
    // Verificar el formato
    final regex =
        RegExp(r'^([0-9]{1,2}):([0-9]{2}) - ([0-9]{1,2}):([0-9]{2})$');
    final match = regex.firstMatch(text);
    if (match == null) {
      return false; // Formato inválido
    }

    // Extraer las horas y minutos del horario ingresado
    int startHour = int.parse(match.group(1)!);
    int startMinute = int.parse(match.group(2)!);
    int endHour = int.parse(match.group(3)!);
    int endMinute = int.parse(match.group(4)!);

    // Verificar que los minutos sean 00 (en este caso no se permite 30 ni otros valores)
    if (startMinute != 0 || endMinute != 0) {
      return false; // Minutos inválidos
    }

    // Verificar que las horas estén dentro del rango permitido (7:00 a 13:00)
    if (startHour < 7 || startHour > 12 || endHour < 8 || endHour > 13) {
      return false; // Horas fuera de rango
    }

    // Verificar que el horario sea exactamente de una hora
    if (endHour - startHour != 1) {
      return false; // Duración inválida
    }

    return true; // Horario válido
  }
}
