import 'package:dataloto/styles/colores.dart';
import 'package:flutter/material.dart';

class DropdownCiudad extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> futureCiudades;
  final ValueNotifier<int?> selectedId;
  final void Function(int?)? onChanged;

  const DropdownCiudad({
    super.key,
    required this.futureCiudades,
    required this.selectedId,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: futureCiudades,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.yellow),
          );
        } else if (snapshot.hasError) {
          return Text(
            'Error: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text(
            'No hay ciudades disponibles',
            style: TextStyle(color: Colors.white70),
          );
        }

        final ciudades = snapshot.data!;
        final ciudadesConTodas = [
          {"id": null, "nombre": "Todas las ciudades"},
          ...ciudades.map((c) => {
                "id": c["id"] as int?,
                "nombre": c["nombre"] as String,
              }),
        ];

        return ValueListenableBuilder<int?>(
          valueListenable: selectedId,
          builder: (context, selectedValue, _) {
            return DropdownButtonFormField<int?>(
              value: selectedValue,
              isExpanded: true,
              dropdownColor: Colors.black87,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Ciudad",
                labelStyle: const TextStyle(color: AppColors.white),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              iconEnabledColor: AppColors.yellow,
              items: ciudadesConTodas.map((c) {
                return DropdownMenuItem<int?>(
                  value: c["id"] as int?,
                  child: Text(c["nombre"] as String),
                );
              }).toList(),
              onChanged: (value) {
                selectedId.value = value;
                if (onChanged != null) onChanged!(value);
              },
            );
          },
        );
      },
    );
  }
}

class DropdownCategoria extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> futureCategorias;
  final ValueNotifier<int?> selectedId;
  final void Function(int?)? onChanged;

  const DropdownCategoria({
    super.key,
    required this.futureCategorias,
    required this.selectedId,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: futureCategorias,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.yellow),
          );
        } else if (snapshot.hasError) {
          return Text(
            'Error: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text(
            'No hay categorías disponibles',
            style: TextStyle(color: Colors.white70),
          );
        }

        final categorias = snapshot.data!;
        final categoriasConTodas = [
          {"id": null, "nombre": "Todas las categorías"},
          ...categorias.map((c) => {
                "id": c["id"] as int?,
                "nombre": c["nombre"] as String,
              }),
        ];

        return ValueListenableBuilder<int?>(
          valueListenable: selectedId,
          builder: (context, selectedValue, _) {
            return DropdownButtonFormField<int?>(
              value: selectedValue,
              isExpanded: true,
              dropdownColor: Colors.black87,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Categoría",
                labelStyle: const TextStyle(color: AppColors.white),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              iconEnabledColor: AppColors.yellow,
              items: categoriasConTodas.map((c) {
                return DropdownMenuItem<int?>(
                  value: c["id"] as int?,
                  child: Text(c["nombre"] as String),
                );
              }).toList(),
              onChanged: (value) {
                selectedId.value = value;
                if (onChanged != null) onChanged!(value);
              },
            );
          },
        );
      },
    );
  }
}
