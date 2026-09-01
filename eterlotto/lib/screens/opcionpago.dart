import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../styles/colores.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import '../services/api_service.dart';

class OpcionPagoScreen extends StatefulWidget {
  final double amount;
  final String email;
  final String name;
  final String reference;

  const OpcionPagoScreen({
    super.key,
    required this.amount,
    required this.email,
    required this.name,
    required this.reference,
  });

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
    final l10n = AppLocalizations.of(context);
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
          SnackBar(content: Text(l10n?.pagoExito ?? "✅ Pago realizado con éxito")),
        );
        Navigator.pop(context, true); // Devuelve "true" para indicar que pagó
      });
    }
  }

  String? checkoutUrl;

  Future<void> createTransaction() async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/pagos/create_transaction'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "amount": widget.amount,
        "currency": "COP",
        "email": widget.email,
        "name": widget.name,
        "reference": widget.reference
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n?.opcionPago ?? "Opción de Pago",
          style: GoogleFonts.montserrat(color: const Color(0xFF121212)),
        ),
        backgroundColor: Colors.amber,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                l10n?.completaDatosPago ?? "Completa tus datos de pago",
                style: GoogleFonts.montserrat(
                  color: const Color(0xFF121212),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // Nombre en la tarjeta
              TextFormField(
                decoration: InputDecoration(
                  labelText: l10n?.nombreTarjeta ?? "Nombre en la tarjeta",
                  border: const OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? (l10n?.ingresaNombre ?? "Ingresa el nombre") : null,
                onSaved: (value) => nombre = value,
              ),
              const SizedBox(height: 15),

              // Número de tarjeta
              TextFormField(
                decoration: InputDecoration(
                  labelText: l10n?.numeroTarjeta ?? "Número de tarjeta",
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 16,
                validator: (value) =>
                    value!.length < 16 ? (l10n?.tarjetaInvalida ?? "Número de tarjeta inválido") : null,
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
                          value!.isEmpty ? (l10n?.fechaInvalida ?? "Fecha inválida") : null,
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
                          value!.length < 3 ? (l10n?.cvvInvalido ?? "CVV inválido") : null,
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
                        l10n?.pagar ?? "Pagar",
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFF121212),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
          ElevatedButton(
          onPressed: createTransaction,
          child: Text(l10n?.pagarEpayco ?? 'Pagar con ePayco'),
        ),
            ],
          ),
        ),
      ),
      ),
      ),
      ),
    );
  }
}
