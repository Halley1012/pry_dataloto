import 'package:dataloto/widgets/contenedor4.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/comment.dart';
import '../widgets/custom_app_bar.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PostScreen extends StatefulWidget {
  final int postId;
  final String postTitle;
  final String postUserName;

  const PostScreen({
    super.key,
    required this.postId,
    required this.postTitle,
    required this.postUserName,
  });

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final storage = const FlutterSecureStorage();

  bool isLoading = false;
  List<Comment> comments = [];
  String? currentUserId;

  // 💬 Estado para la lógica de respuesta estilo YouTube
  String? replyingToUser;
  int? replyingToCommentId;

  // 📂 Estado de respuestas desplegadas por comentario ID
  final Set<int> _expandedReplies = {};

  @override
  void initState() {
    super.initState();
    _cargarDatosInicialesOptimizado();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosInicialesOptimizado() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final userIdFuture = storage.read(key: 'user_id');
      final commentsFuture = ApiService.getComments(widget.postId);

      final userId = await userIdFuture;
      final fetchedComments = await commentsFuture;

      if (!mounted) return;

      setState(() {
        currentUserId = userId;
        comments = fetchedComments;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // Añadir comentario o respuesta
  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Escribe un comentario")));
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final comment = await ApiService.createComment(
        widget.postId,
        text,
        parentId: replyingToCommentId,
      );
      if (!mounted) return;
      setState(() {
        comments.insert(0, comment);
        if (replyingToCommentId != null) {
          _expandedReplies.add(replyingToCommentId!);
        }
        _commentController.clear();
        replyingToUser = null;
        replyingToCommentId = null;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al enviar comentario: $e")));
    }
  }

  // Eliminar comentario
  Future<void> _eliminarComentario(int id) async {
    try {
      await ApiService.deleteComment(id);
      if (mounted) {
        setState(() => comments.removeWhere((c) => c.id == id));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Comentario eliminado")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
      }
    }
  }

  // Denunciar comentario
  void _denunciarComentario(Comment comment) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Comentario de @${comment.userName} reportado."),
        backgroundColor: Colors.amber.shade900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Activar modo respuesta estilo YouTube
  void _iniciarRespuesta(Comment comment) {
    setState(() {
      replyingToUser = comment.userName;
      replyingToCommentId = comment.id;
      _commentController.text = "@${comment.userName} ";
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    });
    _commentFocusNode.requestFocus();
  }

  // Cancelar modo respuesta
  void _cancelarRespuesta() {
    setState(() {
      replyingToUser = null;
      replyingToCommentId = null;
      _commentController.clear();
    });
  }

  // 🔍 Filtra las respuestas que pertenecen a un comentario principal
  List<Comment> _obtenerRespuestas(Comment parentComment) {
    return comments.where((c) {
      if (c.id == parentComment.id) return false;
      return c.parentId != null && c.parentId == parentComment.id;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // 📌 Separa comentarios raíz (no son respuestas)
    final rootComments = comments.where((c) {
      return c.parentId == null;
    }).toList();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // === CONTENIDO DESPLAZABLE ===
            CustomScrollView(
              slivers: [
                CustomSliverAppBar(
                  title: widget.postTitle,
                  pinned: true,
                  floating: true,
                  snap: true,
                  onBackPressed: () {
                    Navigator.of(context).pop(comments.length);
                  },
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text("Comentarios", style: AppTextStyles.h2),
                      const SizedBox(height: 12),

                      // Título del post original
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.grayBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.forum_outlined, color: Colors.amber, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "@${widget.postUserName} - ${widget.postTitle}",
                                style: AppTextStyles.h2.copyWith(
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Lista de comentarios estilo YouTube
                      AppContainer4(
                        child: isLoading && comments.isEmpty
                            ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                            : rootComments.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20.0),
                                      child: Text(
                                        "No hay comentarios aún. ¡Sé el primero en comentar!",
                                        style: TextStyle(color: AppColors.yellow),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: rootComments.length,
                                    itemBuilder: (context, index) {
                                      final comment = rootComments[index];
                                      final respuestas = _obtenerRespuestas(comment);
                                      return _buildYouTubeCommentTile(
                                        comment: comment,
                                        respuestas: respuestas,
                                      );
                                    },
                                  ),
                      ),

                      // Espacio final para que el teclado/input no tape los últimos comentarios
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // === INPUT FIJO EN LA PARTE INFERIOR (ESTILO YOUTUBE) ===
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Banner "Respondiendo a @usuario"
                if (replyingToUser != null)
                  Container(
                    color: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.reply, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Respondiendo a @$replyingToUser",
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                          onPressed: _cancelarRespuesta,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                // Campo de texto del comentario
                Container(
                  color: const Color(0xFF121212),
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 10,
                    bottom: 12,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            style: AppTextStyles.mensajeSecundario,
                            decoration: InputDecoration(
                              hintText: replyingToUser != null
                                  ? "Escribe tu respuesta..."
                                  : "Escribe un comentario...",
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: AppColors.grayBlue.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed:
                              _commentController.text.trim().isEmpty ? null : _addComment,
                          icon: Icon(
                            Icons.send_rounded,
                            color: _commentController.text.trim().isEmpty
                                ? Colors.grey
                                : AppColors.yellow,
                          ),
                          iconSize: 26,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // 📺 Widget individual de Comentario al estilo YouTube
  Widget _buildYouTubeCommentTile({
    required Comment comment,
    List<Comment> respuestas = const [],
    bool isReply = false,
  }) {
    final bool isOwner =
        currentUserId != null && comment.userId.toString() == currentUserId;
    final bool hasReplies = respuestas.isNotEmpty;
    final bool isExpanded = _expandedReplies.contains(comment.id);

    final String initialLetter = comment.userName.isNotEmpty
        ? comment.userName[0].toUpperCase()
        : "?";

    return Container(
      margin: EdgeInsets.only(top: isReply ? 8 : 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Avatar Circular del usuario
              CircleAvatar(
                radius: isReply ? 14 : 17,
                backgroundColor: AppColors.getAvatarColor(comment.userName, userId: comment.userId),
                child: Text(
                  initialLetter,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isReply ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Nombre del usuario + Tiempo relativo ("hace 2 d") + Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado: @userName • hace 2 d
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            "@${comment.userName}",
                            style: AppTextStyles.mensajeSecundario.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isReply ? 13 : 14,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "•",
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          comment.relativeTime, // 🕒 Hace X días / horas sin la hora completa
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Texto del comentario
                    Text(
                      comment.content,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isReply ? 13 : 14,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // 3. Fila de Acciones inferior (Boton Responder + Ver Respuestas estilo YouTube)
                    Row(
                      children: [
                        // Botón "Responder"
                        InkWell(
                          onTap: () => _iniciarRespuesta(comment),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.reply_outlined, color: Colors.white60, size: 15),
                                SizedBox(width: 4),
                                Text(
                                  "Responder",
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Desplegable de número de respuestas
                        if (hasReplies && !isReply) ...[
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedReplies.remove(comment.id);
                                } else {
                                  _expandedReplies.add(comment.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: Colors.amberAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${respuestas.length} ${respuestas.length == 1 ? 'respuesta' : 'respuestas'}",
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 4. Menú de 3 punticos (⋮) a la derecha del comentario
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white54, size: 18),
                color: const Color(0xFF1E1E2E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) async {
                  if (value == 'eliminar') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                          children: [
                            const Icon(Icons.delete, color: Colors.redAccent, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              "Eliminar",
                              style: AppTextStyles.h2.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        content: Text(
                          "¿Estás seguro de eliminar este comentario?",
                          style: AppTextStyles.mensajeSecundario.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancelar", style: TextStyle(color: Colors.amber)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Eliminar", style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      _eliminarComentario(comment.id);
                    }
                  } else if (value == 'denunciar') {
                    _denunciarComentario(comment);
                  }
                },
                itemBuilder: (context) => [
                  if (isOwner)
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: 'denunciar',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, color: Colors.amber, size: 18),
                          SizedBox(width: 8),
                          Text('Reportar', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 5. Lista de respuestas anidadas (desplegables)
          if (hasReplies && isExpanded && !isReply)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 6, bottom: 4),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFF334155), width: 1.5),
                  ),
                ),
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  children: respuestas
                      .map((reply) => _buildYouTubeCommentTile(
                            comment: reply,
                            isReply: true,
                          ))
                      .toList(),
                ),
              ),
            ),

          if (!isReply)
            const Divider(color: Color(0xFF1E293B), thickness: 0.8, height: 16),
        ],
      ),
    );
  }
}