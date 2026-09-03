import 'package:eterlotto/widgets/contenedor4.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/models/comment.dart';
import 'package:eterlotto/widgets/custom_app_bar.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/widgets/user_balota_avatar.dart';

import '../utils/secure_storage_helper.dart';

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
  final storage = AppSecureStorage.instance;

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
    final l10n = AppLocalizations.of(context);
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n?.escribeComentario ?? "Escribe un comentario")));
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
      final rawError = e.toString().replaceAll("Exception: ", "").trim();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
        content: Text(rawError.isNotEmpty ? rawError : (l10n?.errorEnviarComentario(e.toString()) ?? "Error al enviar comentario: $e")),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // Eliminar comentario
  Future<void> _eliminarComentario(int id) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ApiService.deleteComment(id);
      if (mounted) {
        setState(() => comments.removeWhere((c) => c.id == id));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n?.comentarioEliminado ?? "Comentario eliminado")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n?.errorEliminarComentario(e.toString()) ?? "Error al eliminar: $e")));
      }
    }
  }

  // Denunciar comentario
  void _denunciarComentario(Comment comment) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n?.comentarioReportado(comment.userName) ?? "Comentario de @${comment.userName} reportado."),
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
    final l10n = AppLocalizations.of(context);
    final rootComments = comments.where((c) => c.parentId == null).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(comments.length);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                CustomSliverAppBar(
                  title: widget.postTitle,
                  pinned: true,
                  floating: true,
                  snap: true,
                  onBackPressed: () => Navigator.of(context).pop(comments.length),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(l10n?.comentarios ?? "Comentarios", style: AppTextStyles.h2),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.grayBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withOpacity(0.3), width: 0.8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.forum_outlined, color: Colors.amber, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "@${widget.postUserName} - ${widget.postTitle}",
                                  style: AppTextStyles.h2.copyWith(fontSize: 15, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppContainer4(
                          child: isLoading && comments.isEmpty
                              ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                              : rootComments.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Text(
                                          l10n?.noHayComentarios ?? "No hay comentarios aún. ¡Sé el primero en comentar!",
                                          style: const TextStyle(color: AppColors.yellow),
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
                                          l10n: l10n,
                                        );
                                      },
                                    ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                              l10n?.respondiendoA(replyingToUser!) ?? "Respondiendo a @$replyingToUser",
                              style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600),
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
                  Container(
                    color: const Color(0xFF121212),
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 12),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              focusNode: _commentFocusNode,
                              maxLength: 300,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(300),
                              ],
                              style: AppTextStyles.mensajeSecundario,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                                if (currentLength > 240) {
                                  return Text(
                                    "$currentLength/$maxLength",
                                    style: const TextStyle(fontSize: 10, color: AppColors.yellow),
                                  );
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: replyingToUser != null
                                    ? (l10n?.escribeRespuesta ?? "Escribe tu respuesta...")
                                    : (l10n?.escribeComentarioHint ?? "Escribe un comentario..."),
                                hintStyle: const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: AppColors.grayBlue.withOpacity(0.3),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                counterText: _commentController.text.length > 240 ? null : "",
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _commentController.text.trim().isEmpty ? null : _addComment,
                            icon: Icon(Icons.send_rounded, color: _commentController.text.trim().isEmpty ? Colors.grey : AppColors.yellow),
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

  Widget _buildYouTubeCommentTile({
    required Comment comment,
    List<Comment> respuestas = const [],
    bool isReply = false,
    AppLocalizations? l10n,
  }) {
    final bool isOwner = currentUserId != null && comment.userId.toString() == currentUserId;
    final bool hasReplies = respuestas.isNotEmpty;
    final bool isExpanded = _expandedReplies.contains(comment.id);

    return Container(
      margin: EdgeInsets.only(top: isReply ? 2 : 4, bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserBalotaAvatar(
                userName: comment.userName,
                userId: comment.userId,
                radius: isReply ? 11 : 12,
                animateGradient: false,
                showGlow: false,
                showBorder: false,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "@${comment.userName}",
                  style: AppTextStyles.mensajeSecundario.copyWith(fontWeight: FontWeight.w600, fontSize: isReply ? 13 : 14, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Text("•", style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(width: 6),
              Text(comment.relativeTime, style: AppTextStyles.caption.copyWith(fontSize: 11, color: Colors.white54)),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white54, size: 16),
                color: const Color(0xFF1E1E2E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'delete') _eliminarComentario(comment.id);
                  if (value == 'report') _denunciarComentario(comment);
                },
                itemBuilder: (context) => [
                  if (isOwner)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Text(l10n?.eliminar ?? 'Eliminar', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            Localizations.localeOf(context).languageCode == 'en'
                                ? 'Report'
                                : (Localizations.localeOf(context).languageCode == 'pt' ? 'Denunciar' : 'Reportar'),
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                ],
              ),
            ],
          ),

          const SizedBox(height: 6),
          Text(comment.content, style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white.withOpacity(0.9), fontSize: isReply ? 13 : 13.5, height: 1.35)),
          const SizedBox(height: 6),
          Row(
            children: [
              InkWell(
                onTap: () => _iniciarRespuesta(comment),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.reply_outlined, color: AppColors.yellow, size: 15),
                      const SizedBox(width: 4),
                      Text(l10n?.responder ?? "Responder", style: AppTextStyles.caption.copyWith(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              if (hasReplies && !isReply) ...[
                const SizedBox(width: 16),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) _expandedReplies.remove(comment.id);
                      else _expandedReplies.add(comment.id);
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.yellow, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          respuestas.length == 1 ? "1 ${l10n?.respuesta ?? 'respuesta'}" : "${respuestas.length} ${l10n?.respuestas ?? 'respuestas'}",
                          style: AppTextStyles.caption.copyWith(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (hasReplies && isExpanded && !isReply)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
              child: Container(
                decoration: BoxDecoration(border: Border(left: BorderSide(color: AppColors.grayBlue.withOpacity(0.5), width: 1.2))),
                padding: const EdgeInsets.only(left: 10),
                child: Column(children: respuestas.map((reply) => _buildYouTubeCommentTile(comment: reply, isReply: true, l10n: l10n)).toList()),
              ),
            ),
          if (!isReply) ...[
            const SizedBox(height: 6),
            const Divider(color: AppColors.grayBlue, thickness: 0.3),
          ],
        ],
      ),
    );
  }
}
