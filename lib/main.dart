import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:login_app/session_manager.dart';
import 'package:login_app/whatsapp_service.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Necessário para a classe de máscara do telefone dinamica usando o "extends TextInputFormatter"

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

class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String maskedText = '';

    // Aplica a máscara conforme o tamanho do texto
    if (text.isNotEmpty) {
      maskedText = '(${text.substring(0, text.length > 2 ? 2 : text.length)}';

      if (text.length > 2) {
        maskedText += ') ';

        // Verifica se é celular (11 dígitos) ou fixo (10 dígitos)
        final isCelular = text.length == 11;
        final firstPartEnd = isCelular ? 7 : 6;

        if (text.length > (isCelular ? 2 : 2)) {
          maskedText += text.substring(2, text.length > firstPartEnd ? firstPartEnd : text.length);
        }

        if (text.length > firstPartEnd) {
          maskedText += '-${text.substring(firstPartEnd, text.length > (firstPartEnd + 4) ? firstPartEnd + 4 : text.length)}';
        }
      }
    }

    return TextEditingValue(
      text: maskedText,
      selection: TextSelection.collapsed(offset: maskedText.length),
    );
  }
}

class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String maskedText = '';

    if (text.isNotEmpty) {
      maskedText = text.substring(0, text.length > 5 ? 5 : text.length);

      if (text.length > 5) {
        maskedText += '-${text.substring(5, text.length > 8 ? 8 : text.length)}';
      }
    }

    return TextEditingValue(
      text: maskedText,
      selection: TextSelection.collapsed(offset: maskedText.length),
    );
  }
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
        '/cadastroBarbearia': (context) => const PartnerSingUpScreen(),
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
  bool _obscureText = true; //variavel bool para o ícone de "olho" no campo de senha
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Dados do usuário não encontrados no banco de dados.')),
          );
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
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Muitas tentativas. Tente novamente mais tarde.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Erro de conexão. Verifique sua internet.';
      } else {
        errorMessage = 'Erro ao tentar fazer login: ${e.code}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro inesperado: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu e-mail';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'E-mail inválido';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submitForm(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText; // Alterna a visibilidade
                      });
                    },
                  ),
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

                onFieldSubmitted: (_) => _submitForm(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6bc2d3),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFF202A44), width: 2),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
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

              // BOTÃO DE CADASTRO DE CLIENTE NA TELA INICIAL
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

              // BOTÃO DE LEMBRETE DE SENHA NA TELA INICIAL
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

              // BOTÃO DE CADASTRO DE BARBEARIA PARCEIRA NA TELA INICIAL
              const SizedBox(width: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/cadastroBarbearia');
                },
                child: const Text(
                  'Clique para cadastrar sua barbearia',
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
  bool _isLoading = false;
  bool _obscureText = true; //variavel bool para o ícone de "olho" no campo de senha

  Future<bool> _cadastrarUsuario() async {
    setState(() {
      _isLoading = true;
    });

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
        'tipo_usuario': '4', // Tipo padrão para cliente
        'data_criacao': FieldValue.serverTimestamp(),
      });

      await SessionManager.saveUserSession(
        userId: user.uid,
        userRole: '4', // Define como cliente por padrão
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
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'Operação não permitida.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Erro de conexão. Verifique sua internet.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return false;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro inesperado: ${e.toString()}')),
      );
      return false;
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu e-mail';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'E-mail inválido';
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
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu nome completo';
                  }
                  if (value.length < 3) {
                    return 'Nome muito curto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText; // Alterna a visibilidade
                      });
                    },
                  ),
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
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Confirme sua Senha',
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText; // Alterna a visibilidade
                      });
                    },
                  ),
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
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11), // Limita a 11 dígitos (DDD + 9 dígitos)
                  TelefoneInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Telefone de contato',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  final digits = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                  if (digits.isEmpty) return 'Informe o telefone';
                  if (digits.length < 10) return 'Telefone incompleto';
                  if (digits.length > 11) return 'Telefone inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6bc2d3),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFF202A44), width: 2),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
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
  bool _isLoading = false;

  Future<void> _recuperarSenha() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de recuperação enviado com sucesso!')),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = 'Nenhum usuário encontrado com este e-mail.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'E-mail inválido.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Erro de conexão. Verifique sua internet.';
      } else {
        errorMessage = 'Erro ao tentar enviar o e-mail: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro desconhecido: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu e-mail';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'E-mail inválido';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submitForm(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6bc2d3),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFF202A44), width: 2),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
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

class PartnerSingUpScreen extends StatefulWidget {
  const PartnerSingUpScreen({Key? key}) : super(key: key);

  @override
  State<PartnerSingUpScreen> createState() => _PartnerSingUpScreenState();
}

class _PartnerSingUpScreenState extends State<PartnerSingUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _senhaController = TextEditingController();
  final _senhaConfirmController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _cepController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();

  bool _obscureText = true; //variavel bool para o ícone de "olho" no campo de senha
  bool _isLoading = false;

  Future<bool> _cadastrarEmpresa() async {
    setState(() {
      _isLoading = true;
    });

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

      await FirebaseFirestore.instance.collection('empresas').doc(user.uid).set({
        'nome': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'telefone': _telefoneController.text.trim(),
        'cep':_cepController.text.trim(),
        'endereco':_enderecoController.text.trim(),
        'numero':_numeroController.text.trim(),
        'complemento': _complementoController.text.trim(),
        'tipo_usuario': '2', // Tipo padrão para empresa, usuário "admin"
        'data_criacao': FieldValue.serverTimestamp(),
      });

      await SessionManager.saveUserSession(
        userId: user.uid,
        userRole: '2', // Define como admin por padrão
      );

      return true;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erro ao cadastrar empresa.';
      if (e.code == 'weak-password') {
        errorMessage = 'A senha deve ter pelo menos 6 caracteres.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'E-mail já está em uso.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'E-mail inválido.';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'Operação não permitida.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Erro de conexão. Verifique sua internet.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return false;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro inesperado: ${e.toString()}')),
      );
      return false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final sucesso = await _cadastrarEmpresa();
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
          'Cadastro da Barbearia',
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
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu e-mail';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'E-mail inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da barbearia',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome da barbearia';
                  }
                  if (value.length < 3) {
                    return 'Nome muito curto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText; // Alterna a visibilidade
                      });
                    },
                  ),
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
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Confirme sua Senha',
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText; // Alterna a visibilidade
                      });
                    },
                  ),
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
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11), // Limita a 11 dígitos (DDD + 9 dígitos)
                  TelefoneInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Telefone de contato',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  final digits = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                  if (digits.isEmpty) return 'Informe o telefone';
                  if (digits.length < 10) return 'Telefone incompleto';
                  if (digits.length > 11) return 'Telefone inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cepController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'CEP',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8), // 5 + (hífen) + 3
                  CepInputFormatter(),
                ],
                validator: (value) {
                  final digits = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                  if (digits.isEmpty) return 'Por favor, informe o CEP';
                  if (digits.length < 8) return 'CEP incompleto';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _enderecoController,
                decoration: const InputDecoration(
                  labelText: 'Endereço',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o endereço da barbearia';
                  }
                  if (value.length < 5) {
                    return 'Endereço muito curto';
                  }
                  if (value.contains('.')) {
                    return 'Insira o endereço sem abreviaçoes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numeroController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(5),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, informe o número do endereço';
                    }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _complementoController,
                decoration: const InputDecoration(
                  labelText: 'Complemento',
                  hintText: "Não obrigatório",
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6bc2d3),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFF202A44), width: 2),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Cadastrar barbearia',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar tipo de usuário: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEEEE9),
      appBar: AppBar(
        title: Text(
          'iBarber',
          style: GoogleFonts.iceberg(
            textStyle: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF6bc2d3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF6bc2d3),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.user.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: Color(0xFF6bc2d3),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.user.email ?? 'Usuário',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            //ListTile padrão para todos usuários
            ListTile(
              leading: const Icon(Icons.home, color: Color(0xFF6bc2d3)),
              title: const Text('Início'),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            // Construção dos demais ListTiles por usuário logado, sendo separado por lists auxiliares
            if (userRole == '1')  // Master
              ..._buildMasterTiles(), // Retorna uma lista de ListTile

            if (userRole == '2')  // Master
              ..._buildAdminTiles(),

            if (userRole == '3') // Barbeiro
              ..._buildBarberTiles(),

            if (userRole == '4') // Cliente
              ..._buildClientTiles(),

            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFF6bc2d3)),
              title: const Text('Sair'),
              onTap: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  await SessionManager.clearSession();
                  Navigator.pushReplacementNamed(context, '/');
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao sair: ${e.toString()}')),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bem-vindo ao iBarber!',
              style: GoogleFonts.iceberg(
                textStyle: const TextStyle(
                  fontSize: 32,
                  color: Color(0xFF6bc2d3),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Image.asset('assets/images/logo.png', width: 200),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(158, 158, 158, 0.3), // Corrigido para Color.fromRGBO
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Informações do Usuário',
                    style: GoogleFonts.roboto(
                      textStyle: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF6bc2d3),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.user.email ?? 'Não informado',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tipo: ${_getUserRoleText(userRole)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Criando a listTile do usuário MASTER
  List<ListTile> _buildMasterTiles() {
    return [
      ListTile(
        leading: const Icon(Icons.edit_calendar_sharp, color: Color(0xFF6bc2d3)),
        title: const Text('Agendar um Serviço'),
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
        leading: const Icon(Icons.list_alt, color: Color(0xFF6bc2d3)),
        title: const Text('Meus Agendamentos'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppointmentsListPage(
                user: widget.user,
                userRole: userRole,
              ),
            ),
          );
        },
      ),
    ];
  }

  //Criando a listTile do usuário ADMIN
  List<ListTile> _buildAdminTiles() {
    return [
      ListTile(
        leading: const Icon(Icons.assignment_ind, color: Color(0xFF6bc2d3)),
        title: const Text('Cadastrar barbeiro(a)'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegisterBarberPage(
                user: widget.user,
                userRole: userRole,
              ),
            ),
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.list_alt, color: Color(0xFF6bc2d3)),
        title: const Text('Criar um Serviço'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateService(
                user: widget.user,
                userRole: userRole,
              ),
            ),
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.list_alt, color: Color(0xFF6bc2d3)),
        title: const Text('Agendamentos'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppointmentsListPage(
                user: widget.user,
                userRole: userRole,
              ),
            ),
          );
        },
      ),
    ];
  }

  //Criando a listTile do usuário BARBEIRO
  List<ListTile> _buildBarberTiles() {
    return [
      ListTile(
        leading: const Icon(Icons.list_alt, color: Color(0xFF6bc2d3)),
        title: const Text('Meus Agendamentos'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppointmentsListPage(
                user: widget.user,
                userRole: userRole,
              ),
            ),
          );
        },
      ),

      ListTile(
        leading: const Icon(Icons.assignment_ind, color: Color(0xFF6bc2d3)),
        title: const Text('Meus Clientes'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppointmentsListPage(
                user: widget.user,
                userRole: userRole,
              ),
            ),
          );
        },
      ),
    ];
  }

  //Criando a listTile do usuário CLIENTE
  List<ListTile> _buildClientTiles() {
    return [
      ListTile(
        leading: const Icon(Icons.edit_calendar_sharp, color: Color(0xFF6bc2d3)),
        title: const Text('Agendar um Serviço'),
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
        leading: const Icon(Icons.list_alt, color: Color(0xFF6bc2d3)),
        title: const Text('Meus Agendamentos'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppointmentsListPage(
                user: widget.user,
                userRole: userRole,
              ),
            ),
          );
        },
      ),
    ];
  }


  String _getUserRoleText(String role) {
    switch (role) {
      case '1':
        return 'Usuário Master';
      case '2':
        return 'Administrador';
      case '3':
        return 'Barbeiro';
      case '4':
        return 'Cliente';
      default:
        return 'Tipo desconhecido';
    }
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
  bool _isLoading = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar tipo de usuário: ${e.toString()}')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 30)),
      );
      if (picked != null && picked != _selectedDate) {
        setState(() {
          _selectedDate = picked;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao selecionar data: ${e.toString()}')),
      );
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    try {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked != null && picked != _selectedTime) {
        setState(() {
          _selectedTime = picked;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao selecionar horário: ${e.toString()}')),
      );
    }
  }

  Future<void> _submitAppointment() async {
    if (_formKey.currentState!.validate() &&
        _selectedDate != null &&
        _selectedTime != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final appointmentDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );

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
          const SnackBar(content: Text('Agendamento realizado com sucesso!')),
        );

        _serviceController.clear();
        _barberController.clear();
        setState(() {
          _selectedDate = null;
          _selectedTime = null;
        });
      } on FirebaseException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no Firebase: ${e.message}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao agendar: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEEEE9),
      appBar: AppBar(
        title: Text(
          'Agendar Serviço',
          style: GoogleFonts.iceberg(
            textStyle: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF6bc2d3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Preencha os dados do agendamento',
                        style: GoogleFonts.roboto(
                          textStyle: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF6bc2d3),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _serviceController,
                        decoration: const InputDecoration(
                          labelText: 'Serviço',
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black54),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe o serviço desejado';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _barberController,
                        decoration: const InputDecoration(
                          labelText: 'Barbeiro',
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black54),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe o barbeiro';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: Text(
                          _selectedDate == null
                              ? 'Selecione a data'
                              : 'Data: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                        ),
                        trailing: const Icon(Icons.calendar_today, color: Color(0xFF6bc2d3)),
                        onTap: () => _selectDate(context),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: Text(
                          _selectedTime == null
                              ? 'Selecione o horário'
                              : 'Horário: ${_selectedTime!.format(context)}',
                        ),
                        trailing: const Icon(Icons.access_time, color: Color(0xFF6bc2d3)),
                        onTap: () => _selectTime(context),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitAppointment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6bc2d3),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(color: Color(0xFF202A44), width: 2),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                            'Agendar',
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
            ],
          ),
        ),
      ),
    );
  }
}

class AppointmentsListPage extends StatefulWidget {
  final User user;
  final String userRole;

  const AppointmentsListPage({
    Key? key,
    required this.user,
    required this.userRole,
  }) : super(key: key);

  @override
  _AppointmentsListPageState createState() => _AppointmentsListPageState();
}

class _AppointmentsListPageState extends State<AppointmentsListPage> {
  String _statusFilter = 'all';
  bool _showUpcomingOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEEEE9),
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Meus Agendamentos',
              style: GoogleFonts.iceberg(
                textStyle: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_statusFilter != 'all' || _showUpcomingOnly)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Chip(
                  label: Text(
                    _showUpcomingOnly
                        ? 'Próximos 2 dias'
                        : _statusFilter == 'pending'
                        ? 'Pendentes'
                        : _statusFilter == 'confirmed'
                        ? 'Confirmados'
                        : 'Cancelados',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF6bc2d3),
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF6bc2d3),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _statusFilter = value;
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'all',
                child: Text('Todos', style: TextStyle(color: Color(0xFF6bc2d3))),
              ),
              const PopupMenuItem<String>(
                value: 'pending',
                child: Text('Pendentes', style: TextStyle(color: Color(0xFF6bc2d3))),
              ),
              const PopupMenuItem<String>(
                value: 'confirmed',
                child: Text('Confirmados', style: TextStyle(color: Color(0xFF6bc2d3))),
              ),
              const PopupMenuItem<String>(
                value: 'canceled',
                child: Text('Cancelados', style: TextStyle(color: Color(0xFF6bc2d3))),
              ),
            ],
            icon: const Icon(Icons.filter_list, color: Colors.white),
          ),
          IconButton(
            icon: Icon(
              _showUpcomingOnly ? Icons.calendar_today : Icons.calendar_view_day,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showUpcomingOnly = !_showUpcomingOnly;
              });
            },
            tooltip: _showUpcomingOnly ? 'Mostrar todos' : 'Mostrar próximos 2 dias',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildQuery(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar agendamentos: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: const Color(0xFF6bc2d3)),
            );
          }

          final appointments = snapshot.data!.docs.where(_filterAppointments).toList();

          if (appointments.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _showUpcomingOnly
                      ? 'Nenhum agendamento confirmado nos próximos 2 dias'
                      : 'Nenhum agendamento encontrado',
                  style: const TextStyle(fontSize: 16, color: Color(0xFF6bc2d3)),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
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
                final userEmail = data['userEmail'] ?? 'Não informado';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFF6bc2d3), width: 1),
                  ),
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(data['userId'])
                        .get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return ListTile(
                          title: Text(service),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Barbeiro: $barber'),
                              const SizedBox(height: 4),
                              CircularProgressIndicator(
                                strokeWidth: 2,
                                color: const Color(0xFF6bc2d3),
                              ),
                            ],
                          ),
                        );
                      }

                      String clienteNome = userEmail;
                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        clienteNome = userSnapshot.data!.get('nome') ?? userEmail;
                      }

                      return ListTile(
                        title: Text(
                          service,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Barbeiro: $barber'),
                            if (widget.userRole != '4')
                              Text('Cliente: $clienteNome'),
                            Text('Data: ${DateFormat('dd/MM/yyyy').format(dateTime)}'),
                            Text('Hora: ${DateFormat('HH:mm').format(dateTime)}'),
                            Row(
                              children: [
                                const Text('Status: '),
                                Text(
                                  _getStatusText(status),
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: status != 'canceled'
                            ? _buildActionButtons(
                          context: context,
                          status: status,
                          appointmentId: appointmentId,
                          userRole: widget.userRole,
                        )
                            : null,
                      );
                    },
                  ),
                );
              } catch (e) {
                return ListTile(
                  title: const Text('Erro ao carregar agendamento'),
                  subtitle: Text('Detalhes: ${e.toString()}'),
                );
              }
            },
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('agendamentos')
        .orderBy('dateTime');

    if (widget.userRole == '4') {
      query = query.where('userId', isEqualTo: widget.user.uid);
    }

    return query.snapshots();
  }

  bool _filterAppointments(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'pending';
    final dateTime = (data['dateTime'] as Timestamp).toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final twoDaysLater = today.add(const Duration(days: 2));

    if (_statusFilter != 'all' && status != _statusFilter) {
      return false;
    }

    if (_showUpcomingOnly) {
      final isInNextTwoDays = !dateTime.isBefore(today) && !dateTime.isAfter(twoDaysLater);
      return isInNextTwoDays && status == 'confirmed';
    }

    return true;
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pendente';
      case 'confirmed':
        return 'Confirmado';
      case 'canceled':
        return 'Cancelado';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
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
        if (userRole != '4' && status == 'pending')
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () => _confirmAppointment(context, appointmentId),
          ),
        if (status == 'confirmed')
          IconButton(
            icon: const Icon(Icons.message, color: Colors.green),
            onPressed: () => _sendWhatsAppNotification(appointmentId),
            tooltip: 'Enviar notificação via WhatsApp',
          ),
        if (status != 'canceled')
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showCancelConfirmationDialog(context, appointmentId),
          ),
      ],
    );
  }

  Future<void> _showCancelConfirmationDialog(BuildContext context, String appointmentId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar cancelamento'),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text('Tem certeza que deseja cancelar este agendamento?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Não', style: TextStyle(color: Color(0xFF6bc2d3))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Sim', style: TextStyle(color: Color(0xFF6bc2d3))),
              onPressed: () {
                Navigator.of(context).pop();
                _cancelAppointment(context, appointmentId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAppointment(BuildContext context, String appointmentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('agendamentos')
          .doc(appointmentId)
          .update({'status': 'confirmed'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agendamento confirmado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao confirmar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
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
        const SnackBar(
          content: Text('Agendamento cancelado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao cancelar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _sendWhatsAppNotification(String appointmentId) async {
    try {
      // Busca os dados do agendamento
      final doc = await FirebaseFirestore.instance
          .collection('agendamentos')
          .doc(appointmentId)
          .get();

      if (!doc.exists) return;

      final data = doc.data()!;
      final userId = data['userId'];

      // Busca os dados do usuário
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final phoneNumber = userData['telefone'];
      final service = data['service'];
      final dateTime = (data['dateTime'] as Timestamp).toDate();

      if (phoneNumber == null || phoneNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Número de telefone não cadastrado')),
        );
        return;
      }

      // Formata a mensagem
      final formattedDate = DateFormat('dd/MM/yyyy').format(dateTime);
      final formattedTime = DateFormat('HH:mm').format(dateTime);

      final message = '''
[iBarber] Confirmação de Agendamento
Olá! Seu agendamento foi confirmado.

🔹 Serviço: $service
📅 Data: $formattedDate
⏰ Horário: $formattedTime

Agradecemos pela preferência!
''';

      // Envia via WhatsApp
      await WhatsAppService.sendWhatsAppNotification(
        context: context,
        phoneNumber: phoneNumber,
        message: message,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      );
    }
  }
}

class RegisterBarberPage extends StatefulWidget {

  final User user;
  final String userRole;

  const RegisterBarberPage({
    Key? key,
    required this.user,
    required this.userRole,
  }) : super(key: key);

  @override
  State<RegisterBarberPage> createState() => _RegisterBarberPage();
}

class _RegisterBarberPage extends State<RegisterBarberPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _senhaController = TextEditingController();
  final _senhaConfirmController = TextEditingController();
  final _telefoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true; //variavel bool para o ícone de "olho" no campo de senha
  int? _empresaId;

  Future<void> _carregarEmpresaId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuário não autenticado")),
      );
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();

    setState(() {
      _empresaId = userDoc.data()?['empresa_id'];
    });
  }

  Future<bool> _cadastrarBarbeiro() async {
    setState(() {
      _isLoading = true;
    });

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
        'empresa_id': _empresaId,
        'tipo_usuario': '3', // Tipo padrão para barbeiro
        'data_criacao': FieldValue.serverTimestamp(),
      });

      return true;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erro ao cadastrar usuário.';
      if (e.code == 'weak-password') {
        errorMessage = 'A senha deve ter pelo menos 6 caracteres.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'E-mail já está em uso.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'E-mail inválido.';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'Operação não permitida.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Erro de conexão. Verifique sua internet.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return false;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro inesperado: ${e.toString()}')),
      );
      return false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _carregarEmpresaId();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final sucesso = await _cadastrarBarbeiro();
      if (sucesso) {

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barbeiro cadastrado com sucesso!')),
        );
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
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu e-mail';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'E-mail inválido';
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
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu nome completo';
                  }
                  if (value.length < 3) {
                    return 'Nome muito curto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText; // Alterna a visibilidade
                      });
                    },
                  ),
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
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Confirme sua Senha',
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText; // Alterna a visibilidade
                      });
                    },
                  ),
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
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11), // Limita a 11 dígitos (DDD + 9 dígitos)
                  TelefoneInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Telefone de contato',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  final digits = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                  if (digits.isEmpty) return 'Informe o telefone';
                  if (digits.length < 10) return 'Telefone incompleto';
                  if (digits.length > 11) return 'Telefone inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6bc2d3),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFF202A44), width: 2),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
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

class CreateService extends StatefulWidget {

  final User user;
  final String userRole;

  const CreateService({
    Key? key,
    required this.user,
    required this.userRole,
  }) : super(key: key);

  @override
  State<CreateService> createState() => _CreateServiceState();
}

class _CreateServiceState extends State<CreateService> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _timeController = TextEditingController();
  final _iconController = TextEditingController();
  bool _isLoading = false;
  IconData? iconeSelecionado;
  int? _empresaId;

  @override
  void initState() {
    super.initState();
    _carregarEmpresaId();
  }

  Future<void> _carregarEmpresaId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuário não autenticado")),
      );
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();

    setState(() {
      _empresaId = userDoc.data()?['empresa_id'];
    });
  }

  final Map<String, IconData> iconesDisponiveis = {
    'scissors': FontAwesomeIcons.scissors,
    'cut': Icons.cut,
    'face': Icons.face,
    'wash': Icons.wash,
    'color_lens': Icons.color_lens,
  };

  Future<void> _mostrarSeletorDeIcones(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.4,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: iconesDisponiveis.length,
            itemBuilder: (context, index) {
              final nomeIcone = iconesDisponiveis.keys.elementAt(index);
              final icone = iconesDisponiveis[nomeIcone]!;

              return IconButton(
                icon: Icon(icone),
                iconSize: 30,
                color: iconeSelecionado == icone
                    ? const Color(0xFF6bc2d3)
                    : Colors.grey[600],
                onPressed: () {
                  setState(() {
                    iconeSelecionado = icone;
                    _iconController.text = nomeIcone;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<bool> _cadastrarServico() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_empresaId == null) {
        throw Exception('ID da empresa não encontrado');
      }

      await FirebaseFirestore.instance.collection('servicos').add({
        'nome_servico': _nameController.text.trim(),
        'valor_servico': _valueController.text.trim(),
        'tempo_servico': _timeController.text.trim(),
        'empresa_id': _empresaId!,
        'icone_servico': _iconController.text.trim(),
      });

      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro inesperado: ${e.toString()}')),
      );
      return false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final sucesso = await _cadastrarServico();
      if (sucesso) {

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviço cadastrado com sucesso!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEEEE9),
      appBar: AppBar(
        title: const Text(
          'Cadastro de serviço',
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
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do serviço',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome do serviço';
                  }
                  if (value.length < 3) {
                    return 'Nome do serviço muito curto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // Aceita apenas números inteiros
                ],
                decoration: const InputDecoration(
                  labelText: 'Valor do serviço',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o valor do serviço';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _timeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // Aceita apenas números inteiros
                ],
                decoration: const InputDecoration(
                  labelText: 'Tempo do serviço (em minutos)',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o tempo do serviço';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _iconController,
                readOnly: true,
                onTap: () => _mostrarSeletorDeIcones(context),
                decoration: InputDecoration(
                  labelText: "Ícone do Serviço",
                  prefixIcon: Icon(
                    iconeSelecionado ?? Icons.category,
                    color: const Color(0xFF6bc2d3),
                  ),
                  hintText: "Toque para escolher um ícone",
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6bc2d3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black54),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (iconeSelecionado == null) {
                    return 'Por favor, selecione um ícone';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6bc2d3),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFF202A44), width: 2),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
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