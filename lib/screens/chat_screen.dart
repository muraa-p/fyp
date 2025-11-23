import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  String searchQuery = "";
  Map<String, dynamic>? activeChat; // Full conversation object from RPC
  RealtimeChannel? _currentChatChannel;
  final TextEditingController _msgController = TextEditingController();
  late TabController _tabController;

  final SupabaseClient supabase = Supabase.instance.client;
  User? currentUser;
  String? myName; // Cached for consistent "You" in temp messages

  List<Map<String, dynamic>> conversations = [];
  List<Map<String, dynamic>> workshopRequests = [];
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;

  // Only needed realtime subscriptions
  RealtimeChannel? _conversationsChannel;
  RealtimeChannel? _requestsChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _tabController.dispose();
    _unsubscribeFromCurrentChat();
    _conversationsChannel?.unsubscribe();
    _requestsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initializeData() async {
    currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    myName = currentUser!.userMetadata?['name'] ?? 'You';

    await Future.wait([
      _fetchConversations(),
      _fetchWorkshopRequests(),
    ]);

    _setupRealtimeSubscriptions();
    setState(() => isLoading = false);
  }

  void _setupRealtimeSubscriptions() {
    // Refresh conversation list on join/leave
    _conversationsChannel = supabase
        .channel('conv_participants')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'conversation_participants',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: currentUser!.id,
      ),
      callback: (_) => _fetchConversations(),
    )
        .subscribe();

    // Workshop requests changes
    _requestsChannel = supabase
        .channel('workshop_requests')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'workshop_requests',
      callback: (_) => _fetchWorkshopRequests(),
    )
        .subscribe();

    // Refresh unread counts when any message is read
    supabase
        .channel('message_read')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'messages',
      callback: (_) => _fetchConversations(),
    )
        .subscribe();
  }

  // Unified method to open any chat
  void _openChat(Map<String, dynamic> conversation) {
    _unsubscribeFromCurrentChat();
    setState(() {
      activeChat = conversation;
      messages = []; // Clear old messages
    });
    _subscribeToCurrentChat();
    _fetchMessages(conversation['id']);
  }

  void _subscribeToCurrentChat() {
    _unsubscribeFromCurrentChat();
    if (activeChat == null) return;

    final channel = supabase.channel('chat_${activeChat!['id']}');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: activeChat!['id'],
      ),
      callback: (payload) {
        final newMsg = payload.newRecord!;
        final senderId = newMsg['sender_id'] as String;

        setState(() {
          messages.add({
            ...newMsg,
            'sender': {
              'id': senderId,
              'name': senderId == currentUser!.id ? myName : 'User',
              'avatar_url': null,
            },
          });
        });

        if (senderId != currentUser!.id) {
          supabase
              .from('messages')
              .update({'read_at': DateTime.now().toIso8601String()})
              .eq('id', newMsg['id']);
        }
      },
    ).subscribe();

    _currentChatChannel = channel;
  }

  void _unsubscribeFromCurrentChat() {
    _currentChatChannel?.unsubscribe();
    _currentChatChannel = null;
  }

  Future<void> _fetchConversations() async {
    if (currentUser == null) return;
    try {
      final response = await supabase
          .rpc('get_user_conversations', params: {'current_user_id': currentUser!.id})
          .order('updated_at', ascending: false);

      setState(() {
        conversations = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching conversations: $e');
    }
  }

  Future<void> _fetchWorkshopRequests() async {
    if (currentUser == null) return;
    try {
      final workshopsData = await supabase
          .from('workshops')
          .select('id')
          .eq('creator_id', currentUser!.id);

      final workshopIds = workshopsData.map((e) => e['id'] as String).toList();
      if (workshopIds.isEmpty) {
        setState(() => workshopRequests = []);
        return;
      }

      final requestsData = await supabase
          .from('workshop_requests')
          .select('''
            id, workshop_id, requester_id, status, message, created_at,
            requester:users(id, name, avatar_url),
            workshop:workshops(id, title, skill_requested, skill_offered)
          ''')
          .in_('workshop_id', workshopIds)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      setState(() => workshopRequests = requestsData);
    } catch (e) {
      print('Error fetching requests: $e');
    }
  }

  Future<void> _fetchMessages(String conversationId) async {
    try {
      final response = await supabase
          .from('messages')
          .select('''
            id, content, created_at, sender_id,
            sender:users(id, name, avatar_url)
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      setState(() => messages = response);

      // Mark all unread as read
      await supabase
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .neq('sender_id', currentUser!.id)
          .is_('read_at', null);
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  Future<void> sendMessage() async {
    if (_msgController.text.trim().isEmpty || activeChat == null) return;

    final content = _msgController.text.trim();
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    final tempMsg = {
      'id': tempId,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
      'sender_id': currentUser!.id,
      'sender': {
        'id': currentUser!.id,
        'name': myName,
        'avatar_url': currentUser!.userMetadata?['avatar_url'],
      },
    };

    setState(() => messages.add(tempMsg));
    _msgController.clear();

    try {
      final data = await supabase
          .from('messages')
          .insert({
        'conversation_id': activeChat!['id'],
        'sender_id': currentUser!.id,
        'content': content,
      })
          .select()
          .single();

      await supabase
          .from('conversations')
          .update({
        'updated_at': DateTime.now().toIso8601String(),
        'last_message_id': data['id'],
      })
          .eq('id', activeChat!['id']);

      setState(() {
        final i = messages.indexWhere((m) => m['id'] == tempId);
        if (i != -1) messages[i] = {...data, 'sender': tempMsg['sender']};
      });

      _fetchConversations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send')));
      setState(() => messages.removeWhere((m) => m['id'] == tempId));
    }
  }

  Future<void> acceptRequest(Map<String, dynamic> request) async {
    try {
      final newConv = await supabase
          .from('conversations')
          .insert({'is_group': false, 'created_by': currentUser!.id})
          .select()
          .single();

      await supabase.from('conversation_participants').insert([
        {'conversation_id': newConv['id'], 'user_id': currentUser!.id},
        {'conversation_id': newConv['id'], 'user_id': request['requester_id']},
      ]);

      await supabase.from('messages').insert({
        'conversation_id': newConv['id'],
        'sender_id': currentUser!.id,
        'content': "Exchange accepted! Let's collaborate.",
      });

      await supabase.from('workshop_enrollments').upsert({
        'user_id': request['requester_id'],
        'workshop_id': request['workshop_id'],
        'status': 'enrolled',
      });

      await supabase
          .from('workshop_requests')
          .update({'status': 'accepted'})
          .eq('id', request['id']);

      _openChat({
        'id': newConv['id'],
        'is_group': false,
        'other_user': {
          'id': request['requester_id'],
          'name': request['requester']['name'],
          'avatar_url': request['requester']['avatar_url'],
        },
      });

      _fetchConversations();
      _fetchWorkshopRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to accept')));
    }
  }

  Future<void> declineRequest(Map<String, dynamic> request) async {
    try {
      await supabase
          .from('workshop_requests')
          .update({'status': 'declined'})
          .eq('id', request['id']);
      _fetchWorkshopRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to decline')));
    }
  }

  Future<void> startNewConversation() async {
    try {
      // Get users that the current user is following
      final response = await supabase
          .from('follows')
          .select('following_id:users!follows_following_id_fkey(id, name, avatar_url)')
          .eq('follower_id', currentUser!.id);

      final usersFollowed = response
          .map((e) => e['following_id'] as Map<String, dynamic>)
          .toList();

      if (usersFollowed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're not following anyone yet")),
        );
        return;
      }

      final selectedUser = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new conversation'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: usersFollowed.length,
              itemBuilder: (context, index) {
                final user = usersFollowed[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['avatar_url'] != null
                        ? NetworkImage(user['avatar_url'])
                        : null,
                    child: user['avatar_url'] == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(user['name'] ?? 'User'),
                  onTap: () => Navigator.of(context).pop(user),
                );
              },
            ),
          ),
        ),
      );

      if (selectedUser == null) return;

      // Check if conversation already exists
      final existing = await supabase.rpc('get_existing_conversation', params: {
        'user1_id': currentUser!.id,
        'user2_id': selectedUser['id'],
      });

      if (existing.isNotEmpty) {
        // Reuse existing conversation
        _openChat({
          'id': existing.first['id'],
          'is_group': false,
          'other_user': {
            'id': selectedUser['id'],
            'name': selectedUser['name'],
            'avatar_url': selectedUser['avatar_url'],
          },
        });
        return;
      }

      // Create new conversation
      final newConv = await supabase
          .from('conversations')
          .insert({
        'is_group': false,
        'created_by': currentUser!.id,
      })
          .select()
          .single();

      // Add both participants
      await supabase.from('conversation_participants').insert([
        {
          'conversation_id': newConv['id'],
          'user_id': currentUser!.id,
        },
        {
          'conversation_id': newConv['id'],
          'user_id': selectedUser['id'],
        },
      ]);

      // Open the new chat using the unified method
      _openChat({
        'id': newConv['id'],
        'is_group': false,
        'other_user': {
          'id': selectedUser['id'],
          'name': selectedUser['name'],
          'avatar_url': selectedUser['avatar_url'],
        },
      });

      // Refresh list to show the new conversation immediately
      _fetchConversations();
    } catch (e) {
      print('Error starting new conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start conversation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (activeChat != null) {
      final isGroup = activeChat!['is_group'] == true;
      final displayName = isGroup
          ? (activeChat!['name'] ?? 'Group Chat')
          : (activeChat!['other_user'] as Map<String, dynamic>?)!['name'] ?? 'User';
      final avatarUrl = isGroup
          ? activeChat!['avatar_url'] as String?
          : (activeChat!['other_user'] as Map<String, dynamic>?)!['avatar_url'] as String?;

      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _unsubscribeFromCurrentChat();
              setState(() => activeChat = null);
            },
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundImage: avatarUrl?.isNotEmpty == true ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl?.isNotEmpty != true ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  final isMe = msg['sender_id'] == currentUser?.id;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        msg['content'] ?? '',
                        style: TextStyle(color: isMe ? Colors.white : null),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.attach_file), onPressed: () {}),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: sendMessage),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Conversation List
    final filtered = conversations.where((c) {
      final q = searchQuery.toLowerCase();
      if (c['is_group'] == true) {
        return (c['name'] ?? '').toString().toLowerCase().contains(q);
      }
      final name = (c['other_user'] as Map<String, dynamic>?)?['name']?.toString().toLowerCase() ?? '';
      return name.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages & Requests"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.message), text: "Messages"),
            Tab(icon: Icon(Icons.swap_horiz), text: "Requests"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Messages Tab
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(hintText: "Search...", prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? const Center(child: Text("No conversations"))
                    : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    final isGroup = c['is_group'] == true;
                    final name = isGroup ? (c['name'] ?? 'Group') : (c['other_user'] as Map)['name'];
                    final avatar = isGroup ? c['avatar_url'] : (c['other_user'] as Map)['avatar_url'];
                    final lastMsg = c['last_message_content'] ?? 'No messages';
                    final time = c['last_message_time'];
                    final unread = (c['unread_count'] as num?)?.toInt() ?? 0;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: avatar?.isNotEmpty == true ? NetworkImage(avatar) : null,
                        child: avatar?.isNotEmpty != true ? const Icon(Icons.person) : null,
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (time != null) Text(_formatTime(time), style: const TextStyle(fontSize: 11)),
                          if (unread > 0)
                            CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Text('$unread', style: const TextStyle(fontSize: 10, color: Colors.white))),
                        ],
                      ),
                      onTap: () => _openChat(c),
                    );
                  },
                ),
              ),
            ],
          ),

          // Requests Tab (your original, works perfectly)
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : workshopRequests.isEmpty
              ? const Center(child: Text("No pending requests"))
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workshopRequests.length,
            itemBuilder: (_, i) {
              final r = workshopRequests[i];
              final req = r['requester'] as Map<String, dynamic>;
              final ws = r['workshop'] as Map<String, dynamic>;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(backgroundImage: NetworkImage(req['avatar_url'] ?? '')),
                          const SizedBox(width: 12),
                          Expanded(child: Text("${req['name']} wants to join", style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(ws['title'] ?? 'Workshop'),
                      if (ws['skill_requested'] != null) Text("Learn: ${ws['skill_requested']}"),
                      if (ws['skill_offered'] != null) Text("Offers: ${ws['skill_offered']}"),
                      if (r['message']?.isNotEmpty == true) Text("Message: ${r['message']}"),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => declineRequest(r), child: const Text("Decline")),
                          ElevatedButton(onPressed: () => acceptRequest(r), child: const Text("Accept")),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: startNewConversation,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatTime(String timestamp) {
    final dt = DateTime.parse(timestamp);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}

// Extensions for Supabase filters
extension on PostgrestFilterBuilder {
  PostgrestFilterBuilder is_(String column, dynamic value) => filter(column, 'is', value);
}

extension on PostgrestFilterBuilder<PostgrestList> {
  PostgrestFilterBuilder<PostgrestList> in_(String column, List<dynamic> values) => filter(column, 'in', values);
}