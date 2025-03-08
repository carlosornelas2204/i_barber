// ignore_for_file: prefer_const_constructors, avoid_print, use_build_context_synchronously, unnecessary_const

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart'; //Pacote para usar máscaras nos campos de cadastro e/ou de acesso

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,  // Inicialize com as opções específicas para a plataforma
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tela de Login',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
      routes: {
        '/cadastro': (context) => SingUpScreen(),
        '/recuperarSenha': (context) => RecoveryPass(),
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class SingUpScreen extends StatefulWidget {
  const SingUpScreen({Key? key}) : super(key: key);

  @override
  State<SingUpScreen> createState() => _SingUpScreen();
}

class RecoveryPass extends StatefulWidget {
  const RecoveryPass({Key? key}) : super(key: key);

  @override
  State<RecoveryPass> createState() => _RecoveryPass();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();


  bool _obscureText = true; //variavel bool para o ícone de "olho" no campo de senha

  // Função para realizar o login
  Future<void> _login() async {
    try {
      // Realiza a autenticação com Firebase
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text,
        password: _senhaController.text,
      );

      // Verifica se a autenticação foi bem-sucedida
      if (userCredential.user != null) {
        // Verifique o UID do usuário autenticado
        print('Usuário autenticado com sucesso. UID: ${userCredential.user!.uid}');

        // Acessando o Firestore para pegar os dados do usuário
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userCredential.user!.uid) // Usando o UID do usuário autenticado
            .get();

        // Verifica se o documento foi encontrado no Firestore
        if (userDoc.exists) {
          // Recupera o tipo de usuário ou define um valor padrão se não encontrado
          String userRole = userDoc.get('tipo_usuario') ?? 'Desconhecido';

          // Print para ver o tipo de usuário recuperado
          print('Tipo de usuário recuperado do Firestore: $userRole');

          // Redireciona para a IndexPage passando o usuário e seu tipo
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => IndexPage(
                user: userCredential.user!, // Passando o usuário autenticado
                userRole: userRole, // Passando o tipo de usuário
              ),
            ),
          );
        } else {
          // Caso o documento do usuário não exista no Firestore
          print('Documento do usuário não encontrado no Firestore');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuário não encontrado no Firestore')),
          );
        }
      } else {
        // Usuário não autenticado
        print('Usuário não autenticado');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não encontrado')),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Tratar erros específicos de autenticação
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

      print('Erro de autenticação: $errorMessage');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  // Função para submeter o formulário quando pressionar Enter
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
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 100),
              // Campo de e-mail
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
                onFieldSubmitted: (_) {
                  _submitForm();  // Aciona a função de login ao pressionar Enter
                },
              ),
              const SizedBox(height: 16),
              // Campo de senha
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
                  return null;
                },
                onFieldSubmitted: (_) {
                  _submitForm();  // Aciona a função de login ao pressionar Enter
                },

              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  return ElevatedButton(
                    onPressed: _submitForm, // Aciona a função de login ao pressionar o botão
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6bc2d3),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 50),
                      fixedSize: Size(constraints.maxWidth * 0.8, 50),
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
                  );
                },
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
              GestureDetector(
                onTap: () {
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
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
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

//Classe da tela inicial na parte inferior da tela
class _RecoveryPass extends State<RecoveryPass> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  // Função para enviar o e-mail de recuperação de senha
  Future<void> _recuperarSenha() async {
    try {
      // Envia o e-mail de recuperação de senha
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text,
      );

      // Exibe a mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de recuperação enviado com sucesso!')),
      );

      // Retorna para a tela de login
      Navigator.pop(context); // Retorna para a tela de login
    } on FirebaseAuthException catch (e) {
      // Se houver algum erro relacionado ao Firebase Authentication
      String errorMessage = 'Erro ao tentar enviar o e-mail: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      // Qualquer outro erro inesperado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro desconhecido: ${e.toString()}')),
      );
    }
  }

  // Função para submeter o formulário quando pressionado o Enter
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
                onFieldSubmitted: (value) {
                  _submitForm();  // Aciona a recuperação de senha quando pressionar Enter
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  return ElevatedButton(
                    onPressed: () {
                      _submitForm();  // Aciona a recuperação de senha quando pressionado o botão
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6bc2d3),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 50),
                      fixedSize: Size(constraints.maxWidth * 0.8, 50),
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

//Classe da tela de cadastro de cliente
class _SingUpScreen extends State<SingUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _senhaController = TextEditingController();
  final _senhaConfirmController = TextEditingController();
  final _telefoneController = TextEditingController();

  // Função para registrar o usuário no Firebase
  Future<bool> _cadastrarUsuario() async {
    try {
      // Validação local da senha
      if (_senhaController.text.trim().length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A senha deve ter pelo menos 6 caracteres.')),
        );
        return false; // Cadastro falhou
      }

      // Cria o usuário no Firebase Authentication
      final UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );

      // Obtém o usuário autenticado
      final user = userCredential.user;

      if (user != null) {
        // Salva as informações adicionais no Firestore
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
          'nome': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'telefone': _telefoneController.text.trim(),
          'tipo_usuario': '4',
          'empresa_id': 0,
          'data_criacao': FieldValue.serverTimestamp(),
        });

        print("Usuário registrado e salvo com sucesso!");

        // Atualiza o nome do usuário no Firebase Authentication
        await user.updateDisplayName(_nameController.text.trim());

        return true; // Cadastro bem-sucedido
      } else {
        throw Exception("Usuário não encontrado após o cadastro.");
      }
    } catch (e) {
      // Tratamento de erros
      String errorMessage = 'Erro ao cadastrar usuário.';
      if (e is FirebaseAuthException) {
        if (e.code == 'weak-password') {
          errorMessage = 'A senha deve ter pelo menos 6 caracteres.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'E-mail já está em uso.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'E-mail inválido.';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      print('Erro ao cadastrar usuário: ${e.toString()}');
      return false; // Cadastro falhou
    }
  }

  // Máscara para o campo de telefone -- JUCA 08/03/2025
  var phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####', // Máscara base para celular
    filter: { "#": RegExp(r'[0-9]') }, // Apenas números são permitidos
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFEEEE9),
      appBar: AppBar(
        title: const Text(
          'Cadastro',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF6bc2d3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'E-mail',
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
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu e-mail';
                  }
                  return null;
                },
                onFieldSubmitted: (value) {
                  _submitForm();
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo',
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
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu nome completo';
                  }
                  return null;
                },
                onFieldSubmitted: (value) {
                  _submitForm();
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _senhaController,
                obscureText: true,
                decoration: const InputDecoration(
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
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira sua senha';
                  }
                  return null;
                },
                onFieldSubmitted: (value) {
                  _submitForm();
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _senhaConfirmController,
                obscureText: true,
                decoration: const InputDecoration(
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
                onFieldSubmitted: (value) {
                  _submitForm();
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone de contato',
                  //hintText: '(99) 99999-9999', // Adicionado decoração de "dica" para o formato do telefone desejado
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
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu telefone de contato';
                  }
                  return null;
                },
                keyboardType: TextInputType.phone, // Obrigando a abertura somente do teclado numérico do celular
                inputFormatters: [phoneMaskFormatter], // Aplica a máscara criada na váriavel "var phoneMaskFormatter"
                onFieldSubmitted: (value) {
                  _submitForm();
                },
                onChanged: (value) {
                  // Atualiza a máscara dinamicamente tanto para celular quanto para telefone fixo
                  if (value.length == 15) { // Celular com 11 dígitos
                    phoneMaskFormatter.updateMask(mask:'(##) #####-####');
                  } else { // Telefone fixo com 10 dígitos
                    phoneMaskFormatter.updateMask(mask:'(##) ####-####');
                  }
                },
              ),
              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (context, constraints) {
                  return ElevatedButton(
                    onPressed: () async {
                      _submitForm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6bc2d3),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 50),
                      fixedSize: Size(constraints.maxWidth * 0.8, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Color(0xFF202A44), width: 2),
                      ),
                    ),
                    child: const Text(
                      'Cadastrar',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Função para submeter o formulário
  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final sucesso = await _cadastrarUsuario();
      if (sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cadastro realizado com sucesso!')),
        );
        Navigator.pop(context); // Volta para a tela de login
      } else {
        print('Cadastro falhou. Corrija os erros e tente novamente.');
      }
    }
  }
}

class IndexPage extends StatelessWidget {
  final User user;
  final String userRole;

  const IndexPage({
    Key? key,
    required this.user, // Recebe o usuário autenticado
    required this.userRole, // Recebe o tipo de usuário
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Página de Índice'),
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