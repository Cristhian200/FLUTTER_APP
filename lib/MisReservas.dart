import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MisReservasPage extends StatefulWidget {
  const MisReservasPage({super.key});

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
          title: const Text('Mis Reservas'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('Debes iniciar sesión para ver tus reservas.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reservas'),
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
            return const Center(child: CircularProgressIndicator());
          }

          // Si no hay datos o la consulta no devuelve resultados, muestra un mensaje
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tienes reservas.'));
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
        const SnackBar(content: Text('ID de reserva inválido.')),
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
        const SnackBar(content: Text('Reserva cancelada y horario liberado.')),
      );
    } catch (e) {
      print('Error al cancelar la reserva: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cancelar la reserva.')),
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
              title: const Text('Calificar Reserva'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Por favor, califica la reserva'),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: comentarioController,
                    decoration: const InputDecoration(
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
                  child: const Text('Cancelar'),
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Reserva calificada y comentada!')));
                    Navigator.pop(context);
                  },
                  child: const Text('Calificar'),
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

  const EditReservationPage({super.key, required this.reservationId});

  @override
  _EditReservationPageState createState() => _EditReservationPageState();
}

class _EditReservationPageState extends State<EditReservationPage> {
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
        _selectedHorario = _oldHorario;

        // Obtener el piso asociado al aula desde el mapa
        _piso = aulaPisoMap[_aula!] ?? 'piso desconocido';
        _loadAvailableHorarios();
      });
    } catch (e) {
      print('Error al cargar los datos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar la reserva: $e')),
      );
    }
  }

  // Cargar los horarios disponibles para el aula
  Future<void> _loadAvailableHorarios() async {
    try {
      final aulaDocRef = _firestore
          .collection('pisos')
          .doc(_piso!) // Piso seleccionado
          .collection('horarios')
          .doc(_aula!); // Aula seleccionada

      final aulaSnapshot = await aulaDocRef.get();
      if (!aulaSnapshot.exists) {
        throw Exception('El aula no existe en los horarios.');
      }

      Map<String, dynamic> horarios =
          Map<String, dynamic>.from(aulaSnapshot.data()!);

      // Filtrar los horarios disponibles
      List<String> availableHorarios = [];
      horarios.forEach((key, value) {
        if (value == "Disponible") {
          availableHorarios.add(key); // Agregar el horario disponible
        }
      });

      setState(() {
        _horariosDisponibles =
            availableHorarios; // Actualizar lista de horarios
        _selectedHorario = _horariosDisponibles.isNotEmpty
            ? _horariosDisponibles[0]
            : null; // Preseleccionar el primer horario disponible
      });
    } catch (e) {
      print('Error al cargar los horarios disponibles: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar los horarios disponibles: $e')),
      );
    }
  }

  // Función para actualizar la reserva con el nuevo horario seleccionado
  Future<void> _updateReservation() async {
    try {
      if (_selectedHorario == null ||
          !_horariosDisponibles.contains(_selectedHorario)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Por favor selecciona un horario válido.')),
        );
        return;
      }

      if (_piso == null || _aula == null || _oldHorario == null) {
        throw Exception(
            'Datos incompletos. No se puede actualizar la reserva.');
      }

      // Referencia al documento del aula en la subcolección /horarios
      final aulaDocRef = _firestore
          .collection('pisos')
          .doc(_piso!)
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
      if (horarios.containsKey(_selectedHorario) &&
          horarios[_selectedHorario] == "Ocupado") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('El horario seleccionado ya está ocupado.')),
        );
        return;
      }

      // Actualizar los horarios
      horarios[_oldHorario!] = "Disponible"; // Liberar el horario antiguo
      horarios[_selectedHorario!] = "Ocupado"; // Ocupamos el nuevo horario

      // Actualizar en Firebase
      await aulaDocRef.update(horarios);

      // Actualizar la colección de reservas
      await _firestore.collection('reservas').doc(widget.reservationId).update({
        'horario': _selectedHorario,
      });

      // Notificar éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reserva actualizada con éxito.')),
      );

      // Regresar a la página anterior
      Navigator.pop(context);
    } catch (e) {
      print('Error al actualizar la reserva: $e');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar la reserva.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Reserva')),
      body: _aula == null || _oldHorario == null || _piso == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editar horario para el $_aula en el $_piso',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // Mostrar mensaje si no hay horarios disponibles
                  _horariosDisponibles.isEmpty
                      ? const Center(
                          child: Text('No hay horarios disponibles.',
                              style: TextStyle(color: Colors.red)))
                      : DropdownButton<String>(
                          value: _selectedHorario,
                          hint: const Text('Selecciona un horario'),
                          onChanged: (String? newHorario) {
                            setState(() {
                              _selectedHorario = newHorario;
                            });
                          },
                          items: _horariosDisponibles.map((String horario) {
                            return DropdownMenuItem<String>(
                              value: horario,
                              child: Text(horario),
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _updateReservation,
                    child: const Text('Actualizar Horario'),
                  ),
                ],
              ),
            ),
    );
  }
}
