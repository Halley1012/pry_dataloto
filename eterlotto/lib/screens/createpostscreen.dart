import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/widgets/contenedor4.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/widgets/custom_app_bar.dart';
import 'package:eterlotto/models/post.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';

class CreatePostScreen extends StatefulWidget {
  final Post? post; // 🔹 Si es null → crear, si no → editar

  const CreatePostScreen({super.key, this.post});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    // 🔹 Si se pasa un post, precargar sus datos
    if (widget.post != null) {
      _titleController.text = widget.post!.title;
      _contentController.text = widget.post!.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // 🔹 Crear o editar post según corresponda
  Future<void> _submitPost() async {
    final l10n = AppLocalizations.of(context);
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.todosCamposObligatorios ?? "Todos los campos son obligatorios")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      if (widget.post == null) {
        // 🟢 Crear nuevo post
        final newPost = await ApiService.createPost(
          
          _titleController.text.trim(),
          _contentController.text.trim(),
        );
        if (!mounted) return;
        Navigator.pop(context, newPost);
      } else {
        // 🟡 Editar post existente
        final updatedPost = await ApiService.updatePost(
          widget.post!.id,
          _titleController.text.trim(),
          _contentController.text.trim(),
        );
        if (!mounted) return;
        Navigator.pop(context, updatedPost);
      }
    } catch (e) {
      debugPrint("🚨 Error guardando post: $e");
      if (!mounted) return;
      final rawError = e.toString().replaceAll("Exception: ", "").trim();
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(rawError.isNotEmpty ? rawError : (l10n?.errorGuardarPost ?? "Error al guardar el post")),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.post != null;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            CustomSliverAppBar(
              title: isEditing ? (l10n?.editarPost ?? "Editar Post") : (l10n?.crearPost ?? "Crear Post"),
              pinned: true,
              floating: true,
              snap: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔹 Campo de título
                    _buildTextField(
                      _titleController,
                      l10n?.titulo ?? "Título",
                      maxLength: 100,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      _contentController,
                      l10n?.contenido ?? "Contenido",
                      maxLines: 8,
                      maxLength: 500,
                      showCounterThreshold: true,
                    ),
                    const SizedBox(height: 20),
                    // 🔹 Botón de acción
                    isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.amber))
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitPost,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                   vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: AppColors.yellow,
                              ),
                              child: Text(
                                isEditing ? (l10n?.guardarCambios ?? "Guardar Cambios") : (l10n?.publicar ?? "Publicar"),
                                style: AppTextStyles.h2.copyWith(
                                  color: Colors.black,
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
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    int? maxLength,
    bool showCounterThreshold = false,
  }) {
    return AppContainer4(
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        inputFormatters: [
          if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        ],
        style: AppTextStyles.mensajeSecundario,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
          if (showCounterThreshold && maxLength != null && currentLength > (maxLength * 0.8)) {
            return Text(
              "$currentLength/$maxLength",
              style: const TextStyle(fontSize: 10, color: AppColors.yellow),
            );
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.mensajeSecundario,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          counterText: (showCounterThreshold && maxLength != null && controller.text.length > (maxLength * 0.8)) ? null : "",
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
