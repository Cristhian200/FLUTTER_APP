import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'VisualReserva.dart'; // Asegúrate de tener esta página
import 'package:firebase_auth/firebase_auth.dart';
import 'AdminPage.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isPasswordVisible = false;

  Future<void> _login() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    // Validaciones locales para la contraseña
    if (password.length < 8) {
      setState(() {
        _errorMessage = 'La contraseña debe tener al menos 8 caracteres.';
      });
      return;
    }

    final passwordRegex = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');
    if (!passwordRegex.hasMatch(password)) {
      setState(() {
        _errorMessage =
            'La contraseña debe contener al menos:\n- Una letra mayúscula\n- Una letra minúscula\n- Un número\n- Un carácter especial (@, #, !, etc.)';
      });
      return;
    }

    if (password.contains(' ')) {
      setState(() {
        _errorMessage = 'La contraseña no debe contener espacios.';
      });
      return;
    }

    try {
      // Autenticación con Firebase
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: username + "@domain.com", // Concatenar usuario con dominio ficticio
        password: password,
      );

      // Verifica el tipo de usuario
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (userCredential.user != null) {
        if (userCredential.user!.email == 'admin@domain.com') {
          prefs.setString('role', 'admin');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminPage()),
          );
        } else {
          prefs.setString('role', 'docente');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CalendarWithReservationsPage(reservaId: '',)),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Usuario o contraseña incorrectos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      resizeToAvoidBottomInset: true, // Solución para evitar overflow
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // Ajusta según el teclado
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Column(
                        children: [
                          Text(
                            'RESERVATEC',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Tu aula, el encuentro',
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Image.asset(
                            'lib/pictures/logo.png',
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _login,
                        child: const Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,  // Cambia el color de la letra a blanco
                        ),
                      ),
                      ),
                      const SizedBox(height: 10),
                      if (_errorMessage.isNotEmpty)
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Color.fromARGB(255, 18, 19, 19)),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}