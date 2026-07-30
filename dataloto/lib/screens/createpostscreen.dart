import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/contenedor4.dart';
import '../styles/app_text_styles.dart';
import '../styles/colores.dart';
import '../widgets/custom_app_bar.dart';
import '../models/post.dart'; // Asegúrate de importar tu modelo Post

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
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Todos los campos son obligatorios")),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error al guardar el post")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.post != null;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            CustomSliverAppBar(
              title: isEditing ? "Editar Post" : "Crear Post",
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
                    _buildTextField(_titleController, "Título"),
                    const SizedBox(height: 10),
                    _buildTextField(
                      _contentController,
                      "Contenido",
                      maxLines: 8,
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
                                isEditing ? "Guardar Cambios" : "Publicar",
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
  }) {
    return AppContainer4(
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: AppTextStyles.mensajeSecundario,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.mensajeSecundario,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}
