import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:login_app/session_manager.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final session = await SessionManager.getSession();
  print('Dados da sessão: $session');

  runApp(MyApp(
    initialRoute: session != null ? '/home' : '/',
    initialUserRole: session?['userRole'] ?? '',
  ));
}

class MyApp extends StatelessWidget {
  final String? initialRoute;
  final String? initialUserRole;

  const MyApp({
    Key? key,
    required this.initialRoute,
    this.initialUserRole,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tela de Login',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const LoginPage(),
        '/home': (context) => IndexPage(
          user: FirebaseAuth.instance.currentUser!,
          initialUserRole: initialUserRole ?? '',
        ),
        '/cadastro': (context) => const SingUpScreen(),
        '/recuperarSenha': (context) => const RecoveryPass(),
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  Future<void> _login() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text,
        password: _senhaController.text,
      );

      if (userCredential.user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists) {
          String userRole = userDoc.get('tipo_usuario') ?? '';

          await SessionManager.saveUserSession(
            userId: userCredential.user!.uid,
            userRole: userRole,
          );

          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = 'Nenhum usuário encontrado para este e-mail.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Senha incorreta.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'E-mail inválido.';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Credenciais inválidas.';
      } else {
        errorMessage = 'Erro ao tentar fazer login: ${e.code}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _login();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEEEE9),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Image.asset('assets/images/logo.png', width: 250),
              const SizedBox(height: 10),
              Text(
                'iBarber',
                style: GoogleFonts.iceberg(
                  textStyle: const TextStyle(
                    fontSize: 44,
                    color: Color(0xFF6bc2d3),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 100),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu e-mail';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submitForm(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira sua senha';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submitForm(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6bc2d3),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFF202A44), width: 2),
                    ),
                  ),
                  child: const Text(
                    'Entrar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF6bc2d3),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/cadastro');
                },
                child: const Text(
                  'Clique para cadastrar',
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/recuperarSenha');
                },
                child: const Text(
                  'Esqueceu sua senha?',
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SingUpScreen extends StatefulWidget {
  const SingUpScreen({Key? key}) : super(key: key);

  @override
  State<SingUpScreen> createState() => _SingUpScreenState();
}

class _SingUpScreenState extends State<SingUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _senhaController = TextEditingController();
  final _senhaConfirmController = TextEditingController();
  final _telefoneController = TextEditingController();

  Future<bool> _cadastrarUsuario() async {
    try {
      if (_senhaController.text.trim().length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A senha deve ter pelo menos 6 caracteres.')));
        return false;
      }

      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _senhaController.text.trim());

      final user = userCredential.user;
      if (user == null) {
        throw Exception("Usuário não encontrado após o cadastro.");
      }

      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
        'nome': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'telefone': _telefoneController.text.trim(),
        'empresa_id': 0,
        'data_criacao': FieldValue.serverTimestamp(),
      });

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      String userRole = userDoc.get('tipo_usuario') ?? '';

      await SessionManager.saveUserSession(
        userId: user.uid,
        userRole: userRole,
      );

      return true;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erro ao cadastrar usuário.';
      if (e.code == 'weak-password') {
        errorMessage = 'A senha deve ter pelo menos 6 caracteres.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'E-mail já está em uso.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'E-mail inválido.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return false;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocorreu um erro inesperado. Tente novamente.')),
      );
      return false;
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final sucesso = await _cadastrarUsuario();
      if (sucesso) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEEEE9),
      appBar: AppBar(
        title: const Text(
          'Cadastro',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6bc2d3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu e-mail';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu nome completo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira sua senha';
                  }
                  if (value.length < 6) {
                    return 'A senha deve ter pelo menos 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaConfirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirme sua Senha',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, confirme sua senha';
                  }
                  if (value != _senhaController.text) {
                    return 'As senhas não coincidem';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone de contato',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu telefone de contato';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6bc2d3),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFF202A44), width: 2),
                  ),
                ),
                child: const Text(
                  'Cadastrar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecoveryPass extends StatefulWidget {
  const RecoveryPass({Key? key}) : super(key: key);

  @override
  State<RecoveryPass> createState() => _RecoveryPassState();
}

class _RecoveryPassState extends State<RecoveryPass> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  Future<void> _recuperarSenha() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de recuperação enviado com sucesso!')),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erro ao tentar enviar o e-mail: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro desconhecido ao enviar e-mail de recuperação')),
      );
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _recuperarSenha();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEEEE9),
      appBar: AppBar(
        title: const Text(
          'Recuperar Senha',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6bc2d3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu e-mail';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submitForm(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6bc2d3),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFF202A44), width: 2),
                  ),
                ),
                child: const Text(
                  'Recuperar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IndexPage extends StatefulWidget {
  final User user;
  final String initialUserRole;

  const IndexPage({
    Key? key,
    required this.user,
    required this.initialUserRole,
  }) : super(key: key);

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  late String userRole;

  @override
  void initState() {
    super.initState();
    userRole = widget.initialUserRole;
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.user.uid)
          .get();

      if (userDoc.exists) {
        String updatedRole = userDoc.get('tipo_usuario') ?? '';
        if (updatedRole != userRole) {
          setState(() {
            userRole = updatedRole;
          });
          await SessionManager.saveUserSession(
            userId: widget.user.uid,
            userRole: updatedRole,
          );
        }
      }
    } catch (e) {
      print('Erro ao buscar tipo de usuário: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Página de Índice'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Início'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_calendar_sharp),
              title: Text('Agendar um Serviço'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SchedulingPage(
                      user: widget.user,
                      initialUserRole: userRole,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.list_alt),
              title: Text('Meus Agendamentos'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppointmentsListPage(
                      user: widget.user,
                      userRole: userRole, // Passe o userRole aqui
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Sair'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                await SessionManager.clearSession();
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Bem-vindo à Página Inicial!',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            Text(
              'Tipo de Usuário: $userRole',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            if (userRole == '1')
              const Text(
                'Você tem permissões de usuário Master.',
                style: TextStyle(fontSize: 18, color: Colors.green),
              )
            else if (userRole == '2')
              const Text(
                'Você tem permissões de administrador.',
                style: TextStyle(fontSize: 18, color: Colors.green),
              )
            else if (userRole == '3')
                const Text(
                  'Você é um barbeiro.',
                  style: TextStyle(fontSize: 18, color: Colors.blue),
                )
              else if (userRole == '4')
                  const Text(
                    'Você é um cliente.',
                    style: TextStyle(fontSize: 18, color: Colors.blue),
                  )
                else
                  const Text(
                    'Tipo de usuário desconhecido.',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
          ],
        ),
      ),
    );
  }
}

class SchedulingPage extends StatefulWidget {
  final User user;
  final String initialUserRole;

  const SchedulingPage({
    Key? key,
    required this.user,
    required this.initialUserRole,
  }) : super(key: key);

  @override
  State<SchedulingPage> createState() => _SchedulingPageState();
}

class _SchedulingPageState extends State<SchedulingPage> {
  late String userRole;
  final _formKey = GlobalKey<FormState>();
  final _serviceController = TextEditingController();
  final _barberController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    userRole = widget.initialUserRole;
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.user.uid)
          .get();

      if (userDoc.exists) {
        String updatedRole = userDoc.get('tipo_usuario') ?? '';
        if (updatedRole != userRole) {
          setState(() {
            userRole = updatedRole;
          });
          await SessionManager.saveUserSession(
            userId: widget.user.uid,
            userRole: updatedRole,
          );
        }
      }
    } catch (e) {
      print('Erro ao buscar tipo de usuário: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submitAppointment() async {
    if (_formKey.currentState!.validate() &&
        _selectedDate != null &&
        _selectedTime != null) {

      try {
        // Combina data e hora selecionadas
        final appointmentDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );

        // Salva no Firestore
        await FirebaseFirestore.instance.collection('agendamentos').add({
          'userId': widget.user.uid,
          'userEmail': widget.user.email,
          'service': _serviceController.text,
          'barber': _barberController.text,
          'dateTime': appointmentDateTime,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Agendamento realizado com sucesso!')),
        );

        // Limpa o formulário
        _serviceController.clear();
        _barberController.clear();
        setState(() {
          _selectedDate = null;
          _selectedTime = null;
        });

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao agendar: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preencha todos os campos!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendar Serviço'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _serviceController,
                decoration: InputDecoration(
                  labelText: 'Serviço',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o serviço desejado';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _barberController,
                decoration: InputDecoration(
                  labelText: 'Barbeiro',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o barbeiro';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? 'Selecione a data'
                      : 'Data: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                ),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              SizedBox(height: 8),
              ListTile(
                title: Text(
                  _selectedTime == null
                      ? 'Selecione o horário'
                      : 'Horário: ${_selectedTime!.format(context)}',
                ),
                trailing: Icon(Icons.access_time),
                onTap: () => _selectTime(context),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitAppointment,
                child: Text('Agendar'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppointmentsListPage extends StatelessWidget {
  final User user;
  final String userRole; // Adicione esta linha para receber o userRole

  const AppointmentsListPage({
    Key? key,
    required this.user,
    required this.userRole, // Adicione este parâmetro
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agendamentos'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('agendamentos')
            .orderBy('dateTime')
            .snapshots(),
        builder: (context, snapshot) {
          // ... (mantenha o tratamento de erros e loading igual)

          final appointments = snapshot.data!.docs;

          return ListView.builder(
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              try {
                final appointment = appointments[index];
                final data = appointment.data() as Map<String, dynamic>;
                final appointmentId = appointment.id;
                final service = data['service'] ?? 'Serviço não especificado';
                final barber = data['barber'] ?? 'Barbeiro não especificado';
                final status = data['status'] ?? 'pending';
                final dateTime = (data['dateTime'] as Timestamp).toDate();

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(service),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Barbeiro: $barber'),
                        Text('Cliente: ${data['userEmail'] ?? 'Não informado'}'),
                        Text('Data: ${DateFormat('dd/MM/yyyy').format(dateTime)}'),
                        Text('Hora: ${DateFormat('HH:mm').format(dateTime)}'),
                        Text('Status: ${_getStatusText(status)}'),
                      ],
                    ),
                    trailing: _buildActionButtons(
                      context: context,
                      status: status,
                      appointmentId: appointmentId,
                      userRole: userRole,
                    ),
                  ),
                );
              } catch (e) {
                return ListTile(
                  title: Text('Erro ao carregar agendamento'),
                  subtitle: Text('Detalhes: ${e.toString()}'),
                );
              }
            },
          );
        },
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Pendente';
      case 'confirmed': return 'Confirmado';
      case 'canceled': return 'Cancelado';
      default: return status;
    }
  }

  Widget _buildActionButtons({
    required BuildContext context,
    required String status,
    required String appointmentId,
    required String userRole,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botão de confirmar - visível apenas para userRole != '4' e status pendente
        if (userRole != '4' && status == 'pending')
          IconButton(
            icon: Icon(Icons.check, color: Colors.green),
            onPressed: () => _confirmAppointment(context, appointmentId),
          ),

        // Botão de cancelar
        IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: () => _cancelAppointment(context, appointmentId),
        ),
      ],
    );
  }

  Future<void> _confirmAppointment(BuildContext context, String appointmentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('agendamentos')
          .doc(appointmentId)
          .update({'status': 'confirmed'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Agendamento confirmado com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao confirmar: ${e.toString()}')),
      );
    }
  }

  Future<void> _cancelAppointment(BuildContext context, String appointmentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('agendamentos')
          .doc(appointmentId)
          .update({'status': 'canceled'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Agendamento cancelado com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cancelar: ${e.toString()}')),
      );
    }
  }
}