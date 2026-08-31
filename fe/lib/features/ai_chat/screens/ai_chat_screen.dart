import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/info_explainer_dialog.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../family/providers/active_profile_provider.dart';
import '../../home/providers/dashboard_banner_provider.dart'
    show recentChatSessionsProvider;
import '../../records/providers/records_provider.dart';
import '../../records/widgets/record_preview_sheet.dart';

// Quick chips always visible at the bottom - matching Figma. Localized via
// `t.chatQuickChipLastReport` / `t.chatQuickChipEmergencyInfo` at the call site
// since this list is a compile-time const built before any BuildContext exists.

/// A medical record referenced in AI chat - either attached by the user to a question
/// before sending, or returned by the backend as a citation grounding an answer.
/// Also used to carry an initial attachment in via route `extra` (e.g. "Explain with AI"
/// from a record's detail screen).
class AiChatAttachment {
  const AiChatAttachment({
    required this.recordId,
    required this.title,
    required this.recordType,
    this.recordDate,
    this.familyMemberId,
  });

  final String recordId;
  final String title;
  final String recordType;
  final String? recordDate;
  final String? familyMemberId;

  // `title` falls back to '' (not a hardcoded English string) when the backend omits
  // one - the localized "Untitled record" fallback is applied where it's displayed
  // (see `_RecordChip`), since a data factory has no `BuildContext`/`t` to localize with.
  factory AiChatAttachment.fromCitationJson(Map<String, dynamic> json) =>
      AiChatAttachment(
        recordId: json['record_id'] as String,
        title: json['title'] as String? ?? '',
        recordType: json['record_type'] as String? ?? 'other',
        recordDate: json['record_date'] as String?,
      );

  factory AiChatAttachment.fromRecordJson(Map<String, dynamic> json,
          {String? familyMemberId}) =>
      AiChatAttachment(
        recordId: json['id'] as String,
        title: json['title'] as String? ?? '',
        recordType: json['record_type'] as String? ?? 'other',
        recordDate: json['record_date'] as String?,
        familyMemberId: familyMemberId,
      );
}

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key, this.initialAttachment, this.initialSessionId});

  /// Set when navigating here from "Explain with AI" on a specific record - pre-attaches
  /// that record and locks the chat's patient scope to whoever it belongs to.
  final AiChatAttachment? initialAttachment;

  /// Set when navigating here from a "Recent AI Conversations" tile (e.g. on the
  /// home dashboard) - loads that specific past session's history instead of
  /// resuming/creating the usual most-recent-or-new session.
  final String? initialSessionId;

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final List<AiChatAttachment> _pendingAttachments = [];
  bool _isSending = false;
  String? _sessionId;
  String?
      _sessionMemberId; // the active member the current session was created for

  // How long a session may sit idle before returning to the AI tab starts a fresh one
  // instead of resuming it.
  static const _idleResumeThreshold = Duration(minutes: 1);

  late Future<void> _sessionInitFuture;

  @override
  void initState() {
    super.initState();
    final initialSessionId = widget.initialSessionId;
    if (initialSessionId != null) {
      _sessionInitFuture = _loadSession(initialSessionId);
      return;
    }
    final initial = widget.initialAttachment;
    if (initial != null) {
      _pendingAttachments.add(initial);
    }
    _sessionInitFuture = _resumeOrCreateSession();
  }

  /// Reuses the most recent session for the active profile (and hydrates its history) only if
  /// it was active within the last minute; otherwise leaves `_sessionId` unset so a fresh
  /// session is created lazily on the user's first message (see `_sendMessage`), matching
  /// "returning to the chat after a while should open a new session by default" without
  /// persisting an empty session just from opening the screen.
  Future<void> _resumeOrCreateSession() async {
    final memberId = ref.read(activeMemberIdProvider);
    _sessionMemberId = memberId;
    try {
      final api = ref.read(apiClientProvider);
      final sessionsResponse = await api.get<List<dynamic>>(
        '/ai/sessions',
        queryParameters: {
          if (memberId != null) 'family_member_id': memberId,
          'limit': 1,
        },
      );
      final sessions = sessionsResponse.data ?? [];
      if (sessions.isNotEmpty) {
        final sessionMap = sessions.first as Map<String, dynamic>;
        final updatedAt =
            DateTime.tryParse(sessionMap['updated_at'] as String? ?? '');
        final isFresh = updatedAt != null &&
            DateTime.now().toUtc().difference(updatedAt.toUtc()) <
                _idleResumeThreshold;
        if (isFresh) {
          final existingId = sessionMap['id'] as String;
          final messagesResponse = await api.get<List<dynamic>>(
            '/ai/sessions/$existingId/messages',
          );
          final history = (messagesResponse.data ?? [])
              .cast<Map<String, dynamic>>()
              .map((m) => _ChatMessage(
                    role: m['role'] as String,
                    content: m['content'] as String? ?? '',
                    citations: (m['citations'] as List<dynamic>? ?? [])
                        .map((c) => AiChatAttachment.fromCitationJson(
                            c as Map<String, dynamic>))
                        .toList(),
                  ))
              .toList();
          if (mounted) {
            setState(() {
              _sessionId = existingId;
              _messages.addAll(history);
            });
            return;
          }
        }
      }
    } catch (_) {
      // Nothing to resume - a fresh session will be created lazily on first send.
    }
  }

  /// Explicit "New Session" action - always starts fresh regardless of idle time. Doesn't
  /// create a session eagerly; one is created lazily on the user's first message.
  Future<void> _startNewSession() async {
    setState(() {
      _messages.clear();
      _pendingAttachments.clear();
      _sessionId = null;
    });
    _sessionInitFuture = Future.value();
  }

  static void _showAssistantInfo(BuildContext context, AppLocalizations t) {
    showInfoExplainerDialog(
      context,
      title: t.chatInfoModalTitle,
      gotItLabel: t.commonGotIt,
      items: [
        InfoExplainerItem(
          icon: Icons.chat_bubble_outline,
          title: t.chatInfoAskTitle,
          description: t.chatInfoAskDescription,
        ),
        InfoExplainerItem(
          icon: Icons.attach_file,
          title: t.chatInfoAttachTitle,
          description: t.chatInfoAttachDescription,
        ),
        InfoExplainerItem(
          icon: Icons.description_outlined,
          title: t.chatInfoSummarizeTitle,
          description: t.chatInfoSummarizeDescription,
        ),
        InfoExplainerItem(
          icon: Icons.psychology_outlined,
          title: t.chatInfoUnderstandTitle,
          description: t.chatInfoUnderstandDescription,
        ),
      ],
    );
  }

  /// Lists past sessions and, on selection, loads that session's history into this screen.
  Future<void> _showSessionHistory() async {
    final memberId = ref.read(activeMemberIdProvider);
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SessionHistorySheet(
        familyMemberId: memberId,
        activeSessionId: _sessionId,
      ),
    );
    if (selected == null || !mounted) return;
    if (selected['_deletedActiveSession'] == true) {
      // The session currently open in the main screen was deleted from the
      // history sheet - don't try to reload it, start a fresh one instead.
      await _startNewSession();
      return;
    }
    final existingId = selected['id'] as String;
    setState(() {
      _messages.clear();
      _pendingAttachments.clear();
      _sessionId = null;
    });
    _sessionInitFuture = _loadSession(existingId);
  }

  Future<void> _loadSession(String sessionId) async {
    try {
      final api = ref.read(apiClientProvider);
      final messagesResponse =
          await api.get<List<dynamic>>('/ai/sessions/$sessionId/messages');
      final history = (messagesResponse.data ?? [])
          .cast<Map<String, dynamic>>()
          .map((m) => _ChatMessage(
                role: m['role'] as String,
                content: m['content'] as String? ?? '',
                citations: (m['citations'] as List<dynamic>? ?? [])
                    .map((c) => AiChatAttachment.fromCitationJson(
                        c as Map<String, dynamic>))
                    .toList(),
              ))
          .toList();
      if (mounted) {
        setState(() {
          _sessionId = sessionId;
          _messages.addAll(history);
        });
      }
    } catch (_) {
      // Couldn't load that session - leave `_sessionId` unset; a fresh one is created
      // lazily on the user's next message rather than eagerly here.
      if (mounted) setState(() => _sessionId = null);
    }
  }

  Future<void> _createSession() async {
    final memberId = ref.read(activeMemberIdProvider);
    _sessionMemberId = memberId;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final api = ref.read(apiClientProvider);
        final response = await api.post(
          '/ai/sessions',
          data: memberId != null ? {'family_member_id': memberId} : null,
        );
        if (mounted) setState(() => _sessionId = response.data['id'] as String);
        return;
      } catch (_) {
        if (attempt < 2) await Future.delayed(Duration(seconds: attempt + 1));
      }
    }
    // Session creation failed - UI shows disabled send until retry
  }

  /// Switching the active family profile scopes the chat to a different patient on
  /// the backend - start a fresh session/thread rather than mixing messages between
  /// patients under one session. No session is created eagerly here; one is created
  /// lazily (scoped to the now-active profile) on the user's first message.
  void _onActiveProfileChanged() {
    _sessionMemberId = ref.read(activeMemberIdProvider);
    setState(() {
      _messages.clear();
      _pendingAttachments.clear();
      _sessionId = null;
    });
    _sessionInitFuture = Future.value();
  }

  Future<void> _pickAttachments() async {
    final memberId = ref.read(activeMemberIdProvider);
    final selected = await showModalBottomSheet<List<AiChatAttachment>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachmentPickerSheet(
        familyMemberId: memberId,
        alreadySelectedIds: _pendingAttachments.map((a) => a.recordId).toSet(),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        final existingIds = _pendingAttachments.map((a) => a.recordId).toSet();
        for (final a in selected) {
          if (!existingIds.contains(a.recordId)) _pendingAttachments.add(a);
        }
      });
    }
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = (quickText ?? _messageController.text).trim();
    if (text.isEmpty || _isSending) return;

    final attachmentsForThisMessage =
        List<AiChatAttachment>.from(_pendingAttachments);

    // Reflect the user's message and lock out further sends instantly - before any await -
    // so a suggestion chip/send tap never looks frozen, and a second tap while session setup
    // is still resolving can't slip through and fire a duplicate send.
    _messageController.clear();
    setState(() {
      _messages.add(_ChatMessage(
          role: 'user', content: text, attachments: attachmentsForThisMessage));
      _pendingAttachments.clear();
      _isSending = true;
    });
    _scrollToBottom();

    // Session resume may still be in flight - e.g. right after opening the screen. The
    // message is already visible and further sends are already locked out above, so it's
    // safe to wait here instead of dropping the message.
    if (_sessionId == null) {
      await _sessionInitFuture;
    }
    // No session was resumed (or none was in flight) - this is the normal path for a chat
    // that's never had a message sent yet. Create one now, scoped to the currently active
    // profile, instead of persisting an empty session from just opening the screen.
    if (_sessionId == null && mounted) {
      await _createSession();
    }
    if (_sessionId == null || !mounted) {
      if (mounted) {
        final t = ref.read(appLocalizationsProvider);
        setState(() {
          _isSending = false;
          _messages.add(_ChatMessage(
            role: 'assistant',
            content: t.chatSessionStartFailed,
            isStreaming: false,
          ));
        });
      }
      return;
    }

    final aiMsgIndex = _messages.length;
    _messages.add(
        const _ChatMessage(role: 'assistant', content: '', isStreaming: true));

    try {
      final api = ref.read(apiClientProvider);

      final response = await api.dio.post<ResponseBody>(
        '/ai/sessions/$_sessionId/messages/stream',
        data: {
          'content': text,
          if (attachmentsForThisMessage.isNotEmpty)
            'source_record_ids':
                attachmentsForThisMessage.map((a) => a.recordId).toList(),
        },
        options: Options(responseType: ResponseType.stream),
      );

      final responseBody = response.data;
      if (responseBody == null) throw Exception('Empty response');

      final contentBuffer = StringBuffer();
      var citations = <AiChatAttachment>[];
      // Accumulate incomplete SSE lines across chunk boundaries (important on web
      // where XHR may deliver multiple SSE lines in a single data chunk or split
      // a single line across multiple chunks).
      var partialLine = '';
      var done = false;

      await for (final rawBytes in responseBody.stream) {
        if (done) break;
        final rawText = partialLine + utf8.decode(rawBytes);
        final parts = rawText.split('\n');
        partialLine = parts.removeLast(); // last element may be incomplete

        for (final line in parts) {
          if (done) break;
          final trimmed = line.trim();
          if (!trimmed.startsWith('data: ')) continue;

          final data = trimmed.substring(6);
          if (data == '[DONE]') {
            done = true;
            break;
          }

          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            if (json.containsKey('error')) throw Exception(json['error']);

            if (json.containsKey('citations')) {
              final list = json['citations'] as List<dynamic>;
              citations = list
                  .map((c) => AiChatAttachment.fromCitationJson(
                      c as Map<String, dynamic>))
                  .toList();
              continue;
            }

            final content = json['chunk'] as String? ?? '';
            if (content.isNotEmpty) {
              contentBuffer.write(content);
              if (mounted) {
                setState(() {
                  _messages[aiMsgIndex] = _ChatMessage(
                    role: 'assistant',
                    content: contentBuffer.toString(),
                    isStreaming: true,
                  );
                });
                _scrollToBottom();
              }
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _messages[aiMsgIndex] = _ChatMessage(
            role: 'assistant',
            content: contentBuffer.toString(),
            isStreaming: false,
            citations: citations,
          );
        });
      }
      // A reply just landed, so this session now has a message and is
      // eligible to appear in the dashboard's recent-conversations preview -
      // that provider isn't autoDispose, so without this it would keep
      // showing whatever it last fetched for the rest of the app session.
      ref.invalidate(recentChatSessionsProvider);
    } catch (_) {
      if (mounted) {
        final t = ref.read(appLocalizationsProvider);
        setState(() {
          _messages[aiMsgIndex] = _ChatMessage(
            role: 'assistant',
            content: t.chatGenericError,
            isStreaming: false,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Tapping a suggested prompt pill only fills the input, matching web - the
  /// user still has to press send, it is not sent automatically.
  void _fillSuggestion(String prompt) {
    setState(() {
      _messageController.text = prompt;
      _messageController.selection =
          TextSelection.collapsed(offset: prompt.length);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final profile = ref.watch(activeProfileProvider);
    ref.listen<ActiveProfile>(activeProfileProvider, (previous, next) {
      final newMemberId = next.isOwnerMode ? null : next.memberId;
      if (newMemberId != _sessionMemberId) _onActiveProfileChanged();
    });
    final contextLabel = profile.isOwnerMode
        ? t.chatAskAboutYourHealth
        : t.chatAskAboutMembersHealth(profile.displayName);
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;

    if (!isOnline) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(t.chatHealthAssistantTitle),
          backgroundColor: AppTheme.background,
        ),
        body: OfflineBlockedNotice(
          message: t.chatOfflineNotice,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark]),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.chatHealthAssistantTitle,
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(contextLabel,
                    style:
                        TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: t.chatInfoAria,
            onPressed: () => _showAssistantInfo(context, t),
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: t.chatSessionHistoryTooltip,
            onPressed: _showSessionHistory,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: t.chatNewSessionTooltip,
            onPressed: _startNewSession,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Disclaimer banner - always visible above the conversation, matching web.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.primary.withValues(alpha: 0.08),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: AppTheme.primaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.chatDisclaimerBanner,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.primaryDark,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? _EmptyChat(onSuggestion: _fillSuggestion, t: t)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) =>
                        _MessageBubble(message: _messages[i]),
                  ),
          ),

          // Pending attachments for the next message
          if (_pendingAttachments.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              color: AppTheme.surface,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _pendingAttachments
                    .map((a) => _RecordChip(
                          attachment: a,
                          onRemove: () =>
                              setState(() => _pendingAttachments.remove(a)),
                        ))
                    .toList(),
              ),
            ),

          // Input field with attach + send
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.cardBorder)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _messageController,
                      maxLines: 4,
                      minLines: 1,
                      style:
                          TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: t.chatInputHint,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onFieldSubmitted: (_) => _sendMessage(),
                      // Rebuilds the send button as the field goes from
                      // empty to non-empty, matching web's disabled state.
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Attach records - restricts/grounds the next question to specific records
                  IconButton(
                    onPressed: _pickAttachments,
                    icon: Icon(
                      Icons.attach_file,
                      color: _pendingAttachments.isNotEmpty
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  // Send button - disabled and dimmed while sending or when
                  // there is nothing to send, matching web's validation.
                  Builder(builder: (context) {
                    final canSend =
                        _messageController.text.trim().isNotEmpty && !_isSending;
                    return GestureDetector(
                      onTap: canSend ? _sendMessage : null,
                      child: Opacity(
                        opacity: canSend ? 1 : 0.5,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primaryDark],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: _isSending
                              ? const Center(
                                  child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.black)))
                              : const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.black, size: 18),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.citations = const [],
    this.attachments = const [],
  });
  final String role;
  final String content;
  final bool isStreaming;
  final List<AiChatAttachment>
      citations; // assistant messages - what grounded the answer
  final List<AiChatAttachment>
      attachments; // user messages - what the user attached
}

/// The backend always appends its medical disclaimer as its own paragraph
/// starting with the warning emoji (be/app/services/prompts.py) - split it
/// out so it can render as its own styled callout instead of blending into
/// the answer body, matching web's splitAiNote.
(String, String?) _splitAiNote(String content) {
  final lines = content.split('\n');
  final noteIndex = lines.indexWhere((line) => line.trim().startsWith('⚠️'));
  if (noteIndex == -1) return (content, null);
  final note = lines[noteIndex].trim().replaceFirst(RegExp(r'^⚠️\s*'), '');
  final body = [...lines.sublist(0, noteIndex), ...lines.sublist(noteIndex + 1)]
      .join('\n')
      .trim();
  return (body, note);
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final isUser = message.role == 'user';
    // The backend always appends its medical disclaimer as its own paragraph
    // starting with the warning emoji, see be/app/services/prompts.py -
    // split it out so it renders as its own callout instead of blending
    // into the answer body, matching web.
    final (String displayContent, String? note) =
        isUser ? (message.content, null) : _splitAiNote(message.content);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // Circle AI avatar - matching Figma
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark]),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.black, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primary : AppTheme.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.content.isEmpty && message.isStreaming)
                    _TypingIndicator()
                  else if (isUser)
                    Text(
                      message.content,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black, height: 1.5),
                    )
                  else
                    MarkdownBody(
                      data: displayContent,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                            height: 1.5),
                        strong: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.5),
                        em: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                            fontStyle: FontStyle.italic,
                            height: 1.5),
                        listBullet: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                            height: 1.5),
                        h1: TextStyle(
                            fontSize: 18,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700),
                        h2: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700),
                        h3: TextStyle(
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700),
                        code: TextStyle(
                            fontSize: 13,
                            color: AppTheme.primary,
                            backgroundColor: Colors.transparent,
                            fontFamily: 'monospace'),
                        codeblockDecoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(
                              left: BorderSide(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.5),
                                  width: 3)),
                        ),
                        blockquotePadding: const EdgeInsets.only(left: 10),
                      ),
                    ),
                  if (note != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.warningBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: AppTheme.warningDark),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              note,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.warningDark,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (message.isStreaming && message.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: AppTheme.primary)),
                  ],
                  if (isUser && message.attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.attachments
                          .map((a) =>
                              _RecordChip(attachment: a, tint: Colors.black))
                          .toList(),
                    ),
                  ],
                  if (!isUser &&
                      !message.isStreaming &&
                      message.citations.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Divider(color: AppTheme.cardBorder, height: 1),
                    const SizedBox(height: 8),
                    Text(t.chatSourcesLabel,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.citations
                          .map((c) => _RecordChip(attachment: c))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Tappable record chip - used both for citations under a grounded assistant answer and
/// for attachments on a user's own message / staged before sending. Tapping the body
/// always opens a read-only preview in a bottom sheet (chat stays visible underneath);
/// when [onRemove] is set, a trailing "x" also lets the user un-attach before sending.
class _RecordChip extends ConsumerWidget {
  const _RecordChip({required this.attachment, this.onRemove, Color? tint})
      : _tint = tint;
  final AiChatAttachment attachment;
  final VoidCallback? onRemove;
  final Color? _tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final tint = _tint ?? AppTheme.primary;
    final title =
        attachment.title.isEmpty ? t.chatDefaultUntitledRecord : attachment.title;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RecordPreviewSheet(
          recordId: attachment.recordId,
          fallbackTitle: title,
          fallbackType: attachment.recordType,
          fallbackDate: attachment.recordDate,
        ),
      ),
      child: Container(
        // Noto Nastaliq Urdu's ascent/descent (and its stacked diacritics'
        // ink) run well past Manrope's at the same font size, so the pill
        // needs extra vertical breathing room in Urdu or the glyphs paint
        // outside this fixed-padding background.
        padding: EdgeInsets.fromLTRB(
            10, AppFonts.isUrdu ? 10 : 6, onRemove != null ? 4 : 10,
            AppFonts.isUrdu ? 10 : 6),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tint.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(recordTypeIcon(attachment.recordType), size: 12, color: tint),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Line height for Urdu is inherited from the ambient
                // DefaultTextStyle (see AppFonts.textTheme), which already
                // scales it to fit Noto Nastaliq Urdu's taller glyphs.
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500, color: tint),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close,
                    size: 14, color: tint.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for picking which of the active patient's records to attach to the next
/// chat message - restricts RAG retrieval to exactly these records instead of an open
/// semantic search across everything (see retrieve_relevant_chunks on the backend).
/// Lists past chat sessions for the active profile - tapping one returns it to the caller,
/// which loads its history into the current screen.
class _SessionHistorySheet extends ConsumerWidget {
  const _SessionHistorySheet({
    required this.familyMemberId,
    required this.activeSessionId,
  });
  final String? familyMemberId;
  /// The session currently open in the main chat screen, if any - used so a
  /// delete of this session can tell the caller to start a fresh one instead
  /// of leaving the main screen pointed at a now-deleted session.
  final String? activeSessionId;

  Future<void> _renameSession(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> session,
  ) async {
    final t = ref.read(appLocalizationsProvider);
    final controller =
        TextEditingController(text: (session['title'] as String?) ?? '');
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.chatRenameConversationTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: t.chatConversationTitleHint),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(t.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newTitle == null || newTitle.isEmpty) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/ai/sessions/${session['id']}', data: {
        'title': newTitle,
      });
      ref.invalidate(sessionHistoryProvider(familyMemberId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.chatRenameFailed)));
      }
    }
  }

  Future<void> _togglePin(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> session,
  ) async {
    final t = ref.read(appLocalizationsProvider);
    final isPinned = session['is_pinned'] == true;
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/ai/sessions/${session['id']}', data: {
        'is_pinned': !isPinned,
      });
      ref.invalidate(sessionHistoryProvider(familyMemberId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(isPinned ? t.chatUnpinFailed : t.chatPinFailed)));
      }
    }
  }

  Future<void> _deleteSession(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> session,
  ) async {
    final t = ref.read(appLocalizationsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.chatDeleteConversationTitle),
        content: Text(t.chatDeleteConversationBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.commonDelete, style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final sessionId = session['id'] as String;
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/ai/sessions/$sessionId');
      ref.invalidate(sessionHistoryProvider(familyMemberId));
      ref.invalidate(recentChatSessionsProvider);
      if (sessionId == activeSessionId && context.mounted) {
        // Close the sheet and tell the caller its active session is gone.
        Navigator.of(context).pop({'_deletedActiveSession': true});
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.chatDeleteFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    final sessionsFuture = ref.watch(sessionHistoryProvider(familyMemberId));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration:  BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
               Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t.chatSessionHistoryTitle,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: sessionsFuture.when(
                  loading: () =>  Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary)),
                  error: (_, __) =>  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(t.chatCouldNotLoadHistory,
                          style:
                              TextStyle(color: AppTheme.error, fontSize: 13)),
                    ),
                  ),
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return  Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(t.chatNoPreviousSessions,
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) =>
                           Divider(color: AppTheme.cardBorder, height: 1),
                      itemBuilder: (_, i) {
                        final s = sessions[i];
                        final title = (s['title'] as String?)?.trim();
                        final isPinned = s['is_pinned'] == true;
                        return ListTile(
                          leading: Icon(
                              isPinned
                                  ? Icons.push_pin
                                  : Icons.chat_bubble_outline,
                              color: AppTheme.primary,
                              size: 20),
                          title: Text(
                            title == null || title.isEmpty
                                ? t.chatUntitledConversation
                                : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:  TextStyle(
                                fontSize: 14, color: AppTheme.textPrimary),
                          ),
                          subtitle: Text(
                            _formatRelativeTime(t, s['updated_at'] as String?),
                            style:  TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert,
                                color: AppTheme.textSecondary, size: 20),
                            onSelected: (value) {
                              switch (value) {
                                case 'rename':
                                  _renameSession(context, ref, s);
                                  break;
                                case 'pin':
                                  _togglePin(context, ref, s);
                                  break;
                                case 'delete':
                                  _deleteSession(context, ref, s);
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(t.chatRename),
                              ),
                              PopupMenuItem(
                                value: 'pin',
                                child: Text(isPinned ? t.chatUnpin : t.chatPin),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(t.commonDelete),
                              ),
                            ],
                          ),
                          onTap: () => Navigator.of(context).pop(s),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Mirrors web's formatRelativeTime so the conversation list reads the same
/// way on both platforms ("now", "5m ago", "3d ago", and so on).
String _formatRelativeTime(AppLocalizations t, String? iso) {
  if (iso == null) return '';
  final DateTime dt;
  try {
    dt = DateTime.parse(iso);
  } catch (_) {
    return '';
  }
  final diff = DateTime.now().toUtc().difference(dt.toUtc());
  final diffMin = (diff.inSeconds / 60).round();
  if (diffMin < 1) return t.chatTimeNow;
  if (diffMin < 60) return t.chatTimeMinutesAgo(diffMin);
  final diffHr = (diffMin / 60).round();
  if (diffHr < 24) return t.chatTimeHoursAgo(diffHr);
  final diffDay = (diffHr / 24).round();
  if (diffDay < 7) return t.chatTimeDaysAgo(diffDay);
  final diffWeek = (diffDay / 7).round();
  if (diffWeek < 5) return t.chatTimeWeeksAgo(diffWeek);
  final diffMonth = (diffDay / 30).round();
  if (diffMonth < 12) return t.chatTimeMonthsAgo(diffMonth);
  return t.chatTimeYearsAgo((diffDay / 365).round());
}

// Exported (not file-private) so auth_provider.dart can invalidate it on
// logout - see _invalidateCachedDataProviders there. autoDispose means it's
// usually already gone once its sheet closes, but this covers the moment
// it's actively open during a logout.
final sessionHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, familyMemberId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>(
    '/ai/sessions',
    queryParameters: {
      if (familyMemberId != null) 'family_member_id': familyMemberId,
      'limit': 30,
    },
  );
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

class _AttachmentPickerSheet extends ConsumerStatefulWidget {
  const _AttachmentPickerSheet(
      {required this.familyMemberId, required this.alreadySelectedIds});
  final String? familyMemberId;
  final Set<String> alreadySelectedIds;

  @override
  ConsumerState<_AttachmentPickerSheet> createState() =>
      _AttachmentPickerSheetState();
}

class _AttachmentPickerSheetState
    extends ConsumerState<_AttachmentPickerSheet> {
  late final _selected = <String>{...widget.alreadySelectedIds};
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLocalizationsProvider);
    final recordsAsync =
        ref.watch(recordsByFamilyMemberProvider(widget.familyMemberId));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t.chatAttachRecords,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      t.chatAttachRecordsSubtitle,
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: t.chatAttachSearchPlaceholder,
                    prefixIcon: Icon(Icons.search,
                        size: 18, color: AppTheme.textMuted),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.card,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppTheme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppTheme.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppTheme.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: recordsAsync.when(
                  data: (records) {
                    if (records.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(t.chatNoRecordsForPatient,
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13)),
                        ),
                      );
                    }
                    final query = _query.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? records
                        : records
                            .where((r) => (r['title'] as String? ?? '')
                                .toLowerCase()
                                .contains(query))
                            .toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(t.chatAttachNoMatches,
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13)),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final r = filtered[i];
                        final id = r['id'] as String;
                        final type = r['record_type'] as String? ?? 'other';
                        return CheckboxListTile(
                          value: _selected.contains(id),
                          onChanged: (_) => setState(() =>
                              _selected.contains(id)
                                  ? _selected.remove(id)
                                  : _selected.add(id)),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppTheme.primary,
                          secondary: Icon(recordTypeIcon(type),
                              color: AppTheme.textSecondary),
                          title: Text(r['title'] as String? ?? t.recordsUntitled,
                              style: TextStyle(
                                  fontSize: 14, color: AppTheme.textPrimary)),
                          subtitle: Text(
                            '${recordTypeLabel(t, type)} · ${formatRecordDate(t, r['record_date'] as String?)}',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary)),
                  error: (_, __) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(t.chatCouldNotLoadRecords,
                          style:
                              TextStyle(color: AppTheme.error, fontSize: 13)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final records = ref
                              .read(recordsByFamilyMemberProvider(
                                  widget.familyMemberId))
                              .value ??
                          [];
                      final chosen = records
                          .where((r) => _selected.contains(r['id']))
                          .map((r) => AiChatAttachment.fromRecordJson(r,
                              familyMemberId: widget.familyMemberId))
                          .toList();
                      Navigator.of(context).pop(chosen);
                    },
                    child: Text(_selected.isEmpty
                        ? t.chatAttachButton
                        : t.chatAttachCountButton(_selected.length)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final delay = i * 0.2;
            final offset = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final bounce = offset < 0.5 ? offset * 2 : (1 - offset) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6 + (bounce * 4),
              decoration: BoxDecoration(
                  color: AppTheme.textSecondary, shape: BoxShape.circle),
            );
          },
        );
      }),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onSuggestion, required this.t});
  final void Function(String) onSuggestion;
  final AppLocalizations t;

  List<String> get _suggestions => [
        t.chatSuggestionSummarizeLatestLab,
        t.chatSuggestionExplainXray,
        t.chatSuggestionExplainMeds,
        t.chatSuggestionAnyConcerns,
      ];

  @override
  Widget build(BuildContext context) {
    // A plain Column with mainAxisAlignment.center can neither shrink nor
    // scroll, so when the keyboard opens and the available height drops
    // below this content's natural height, it overflows instead of
    // adjusting. LayoutBuilder plus a scrollable min-height Column keeps the
    // content centered when there is room and scrollable when there isn't.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome,
                      color: AppTheme.primary, size: 30),
                ),
                const SizedBox(height: 18),
                Text(t.chatEmptyTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  t.chatEmptyDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.5,
                      color: AppTheme.textSecondary,
                      height: 1.5),
                ),
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions
                      .map((s) => _SuggestionPill(
                            label: s,
                            onTap: () => onSuggestion(s),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionPill extends StatelessWidget {
  const _SuggestionPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5),
        ),
      ),
    );
  }
}
