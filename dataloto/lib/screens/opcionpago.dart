import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../styles/colores.dart';

class OpcionPagoScreen extends StatefulWidget {
  const OpcionPagoScreen({super.key});

  @override
  State<OpcionPagoScreen> createState() => _OpcionPagoScreenState();
}

class _OpcionPagoScreenState extends State<OpcionPagoScreen> {
  final _formKey = GlobalKey<FormState>();
  String? nombre;
  String? numeroTarjeta;
  String? fechaExp;
  String? cvv;

  bool procesando = false;

  void _procesarPago() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        procesando = true;
      });

      // 🔹 Aquí iría la integración con la pasarela real de pagos
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          procesando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Pago realizado con éxito")),
        );
        Navigator.pop(context, true); // Devuelve "true" para indicar que pagó
      });
    }
  }

  String? checkoutUrl;

  Future<void> createTransaction() async {
    final response = await http.post(
      Uri.parse('http://localhost:8000/create_transaction'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "amount": 5000,
        "currency": "COP",
        "email": "cliente@correo.com",
        "name": "Michael",
        "reference": "ORD12345"
      }),
    );

    final data = jsonDecode(response.body);
    setState(() {
      checkoutUrl = data['checkout_url'];
    });

    if (checkoutUrl != null) {
      final uri = Uri.parse(checkoutUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir el checkout';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Opción de Pago",
          style: GoogleFonts.montserrat(color: const Color(0xFF121212)),
        ),
        backgroundColor: Colors.amber,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                "Completa tus datos de pago",
                style: GoogleFonts.montserrat(
                  color: const Color(0xFF121212),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // Nombre en la tarjeta
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Nombre en la tarjeta",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Ingresa el nombre" : null,
                onSaved: (value) => nombre = value,
              ),
              const SizedBox(height: 15),

              // Número de tarjeta
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Número de tarjeta",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 16,
                validator: (value) =>
                    value!.length < 16 ? "Número de tarjeta inválido" : null,
                onSaved: (value) => numeroTarjeta = value,
              ),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: "MM/AA",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          4,
                        ), // limita a 3 dígitos
                      ],
                      validator: (value) =>
                          value!.isEmpty ? "Fecha inválida" : null,
                      onSaved: (value) => fechaExp = value,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: "CVV",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          3,
                        ), // limita a 3 dígitos
                      ],
                      validator: (value) =>
                          value!.length < 3 ? "CVV inválido" : null,
                      onSaved: (value) => cvv = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: procesando ? null : _procesarPago,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.payment, color: Color(0xFF121212)),
                label: procesando
                    ? const CircularProgressIndicator(color: AppColors.amber)
                    : Text(
                        "Pagar",
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFF121212),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
          ElevatedButton(
          onPressed: createTransaction,
          child: Text('Pagar con ePayco'),
        ),
            ],
          ),
        ),
      ),
    );
  }
}
