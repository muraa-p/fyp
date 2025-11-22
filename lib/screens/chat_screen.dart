import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  String searchQuery = "";
  Map<String, dynamic>? activeChat;
  RealtimeChannel? _currentChatChannel;
  final TextEditingController _msgController = TextEditingController();
  late TabController _tabController;

  // Supabase client
  final SupabaseClient supabase = Supabase.instance.client;

  // Current user
  User? currentUser;

  // Data lists
  List<Map<String, dynamic>> conversations = [];
  List<Map<String, dynamic>> workshopRequests = [];
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;

  // Realtime subscriptions
  RealtimeChannel? _conversationsChannel;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _requestsChannel;
  RealtimeChannel? _participantsChannel;

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
    _conversationsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    _requestsChannel?.unsubscribe();
    _participantsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initializeData() async {
    currentUser = supabase.auth.currentUser;
    if (currentUser != null) {
      await _fetchConversations();
      await _fetchWorkshopRequests();
      _setupRealtimeSubscriptions();
      setState(() {
        isLoading = false;
      });
    }
  }

  void _setupRealtimeSubscriptions() {
    // 1. Refresh conversation list when you join/leave a chat
    supabase
        .channel('conversation_participants_changes')
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

    // 2. GLOBAL new message → always refresh the list (preview + unread count)
    supabase
        .channel('global_messages')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final convId = payload.newRecord!['conversation_id'] as String;

        // Refresh list preview
        _fetchConversations();

        // If we are inside this exact chat → instantly add the message
        if (activeChat != null && activeChat!['id'] == convId) {
          final newMsg = payload.newRecord!;
          setState(() {
            messages.add({
              ...newMsg,
              'sender': {
                'id': newMsg['sender_id'],
                'name': newMsg['sender_id'] == currentUser!.id
                    ? (currentUser!.userMetadata?['name'] ?? 'You')
                    : 'User', // you can improve this later
                'avatar_url': null,
              },
            });
          });

          // Mark as read if it's not from me
          if (newMsg['sender_id'] != currentUser!.id) {
            supabase
                .from('messages')
                .update({'read_at': DateTime.now().toIso8601String()})
                .eq('id', newMsg['id']);
          }
        }
      },
    )
        .subscribe();

    // Workshop requests realtime
    supabase
        .channel('workshop_requests_changes')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'workshop_requests',
      callback: (_) => _fetchWorkshopRequests(),
    )
        .subscribe();
  }

  void _subscribeToCurrentChat() {
    _currentChatChannel?.unsubscribe();
    if (activeChat == null) return;

    final channel = supabase.channel('chat_${activeChat!['id']}');

    channel
        .onPostgresChanges(
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
        setState(() {
          messages.add({
            ...newMsg,
            'sender': {
              'id': newMsg['sender_id'],
              'name': newMsg['sender_id'] == currentUser!.id
                  ? (currentUser!.userMetadata?['name'] ?? 'You')
                  : 'User',
              'avatar_url': null,
            },
          });
        });
      },
    )
        .subscribe();

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
      setState(() => conversations = []);
    }
  }

  Future<void> _fetchWorkshopRequests() async {
    if (currentUser == null) return;

    try {
      // Get workshops created by the current user
      final workshopsData = await supabase
          .from('workshops')
          .select('id, title, creator_id')
          .eq('creator_id', currentUser!.id);

      final workshopIds = workshopsData.map((e) => e['id'] as String).toList();

      if (workshopIds.isEmpty) {
        setState(() {
          workshopRequests = [];
        });
        return;
      }

      // Get pending requests for these workshops
      final requestsData = await supabase
          .from('workshop_requests')
          .select('''
            id,
            workshop_id,
            requester_id,
            status,
            message,
            created_at,
            requester:users(
              id,
              name,
              avatar_url
            ),
            workshop:workshops(
              id,
              title,
              skill_requested,
              skill_offered
            )
          ''')
          .in_('workshop_id', workshopIds)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      setState(() {
        workshopRequests = requestsData;
      });
    } catch (e) {
      print('Error fetching workshop requests: $e');
    }
  }

  Future<void> _fetchMessages(String conversationId) async {
    try {
      final response = await supabase
          .from('messages')
          .select('''
            id,
            content,
            created_at,
            sender_id,
            sender:users(
              id,
              name,
              avatar_url
            )
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      setState(() {
        messages = response;
      });

      // Mark messages as read
      await supabase
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .neq('sender_id', currentUser!.id)
          .is_('read_at', 'null');
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  Future<void> sendMessage() async {
    if (_msgController.text.trim().isEmpty || activeChat == null || currentUser == null) return;

    try {
      final messageContent = _msgController.text.trim();

      // Create a temporary message to show immediately
      final tempMessage = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID
        'content': messageContent,
        'created_at': DateTime.now().toIso8601String(),
        'sender_id': currentUser!.id,
        'sender': {
          'id': currentUser!.id,
          'name': currentUser!.userMetadata?['name'] ?? 'You',
          'avatar_url': currentUser!.userMetadata?['avatar_url'],
        }
      };

      // Add the temporary message to the UI immediately
      setState(() {
        messages.add(tempMessage);
      });

      _msgController.clear();

      // Send the message to the database
// Inside sendMessage(), after inserting the message:
      final messageData = await supabase
          .from('messages')
          .insert({
        'conversation_id': activeChat!['id'],
        'sender_id': currentUser!.id,
        'content': messageContent,
      })
          .select()
          .single();

// This is the key fix:
      await supabase
          .from('conversations')
          .update({
        'updated_at': DateTime.now().toIso8601String(),
        'last_message_id': messageData['id'],
      })
          .eq('id', activeChat!['id']);

      // Replace the temporary message with the real one
      setState(() {
        final index = messages.indexWhere((m) => m['id'] == tempMessage['id']);
        if (index != -1) {
          messages[index] = messageData;
        }
      });
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  Future<void> acceptRequest(Map<String, dynamic> request) async {
    try {
      // Update the request status
      await supabase
          .from('workshop_requests')
          .update({'status': 'accepted', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', request['id']);

      // Create a new conversation between the workshop creator and the requester
      final newConversation = await supabase
          .from('conversations')
          .insert({
        'is_group': false,
        'created_by': currentUser!.id,
      })
          .select()
          .single();

      // Add both users to the conversation
      await supabase.from('conversation_participants').insert([
        {
          'conversation_id': newConversation['id'],
          'user_id': currentUser!.id,
        },
        {
          'conversation_id': newConversation['id'],
          'user_id': request['requester_id'],
        }
      ]);

      // Send a welcome message
      await supabase.from('messages').insert({
        'conversation_id': newConversation['id'],
        'sender_id': currentUser!.id,
        'content': 'Exchange accepted! Let\'s start collaborating.',
      });

      // Update the workshop enrollment
      await supabase.from('workshop_enrollments').upsert({
        'user_id': request['requester_id'],
        'workshop_id': request['workshop_id'],
        'status': 'enrolled',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Exchange with ${request['requester']['name']} accepted!")),
      );

      // Open the new conversation
      setState(() {
        activeChat = {
          'id': newConversation['id'],
          'name': request['requester']['name'],
          'avatar_url': request['requester']['avatar_url'],
          'is_group': false,
        };
      });

      _fetchMessages(newConversation['id']);
      _fetchConversations(); // Refresh the conversation list
    } catch (e) {
      print('Error accepting request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept request: $e')),
      );
    }
  }

  Future<void> declineRequest(Map<String, dynamic> request) async {
    try {
      await supabase
          .from('workshop_requests')
          .update({'status': 'declined', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', request['id']);
    } catch (e) {
      print('Error declining request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decline request: $e')),
      );
    }
  }

  Future<void> startNewConversation() async {
    try {
      // Get users that the current user is following
      // We need to specify the foreign key relationship explicitly
      final response = await supabase
          .from('follows')
          .select('following_id:users!follows_following_id_fkey(id, name, avatar_url)')
          .eq('follower_id', currentUser!.id);

      final usersFollowed = response.map((e) => e['following_id'] as Map<String, dynamic>).toList();

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
                    backgroundImage: NetworkImage(user['avatar_url'] ?? ''),
                  ),
                  title: Text(user['name']),
                  onTap: () => Navigator.of(context).pop(user),
                );
              },
            ),
          ),
        ),
      );

      if (selectedUser == null) return;

      // Check if a conversation already exists using RPC
      final existingConversation = await supabase
          .rpc('get_existing_conversation', params: {
        'user1_id': currentUser!.id,
        'user2_id': selectedUser['id']
      });

      if (existingConversation.isNotEmpty) {
        // Open the existing conversation
        setState(() {
          activeChat = {
            'id': existingConversation.first['id'],
            'name': selectedUser['name'],
            'avatar_url': selectedUser['avatar_url'],
            'is_group': false,
          };
        });

        _fetchMessages(existingConversation.first['id']);
        return;
      }

      // Create a new conversation
      final newConversation = await supabase
          .from('conversations')
          .insert({
        'is_group': false,
        'created_by': currentUser!.id,
      })
          .select()
          .single();

      // Add both users to the conversation
      await supabase.from('conversation_participants').insert([
        {
          'conversation_id': newConversation['id'],
          'user_id': currentUser!.id,
        },
        {
          'conversation_id': newConversation['id'],
          'user_id': selectedUser['id'],
        }
      ]);

      // Open the new conversation
      setState(() {
        activeChat = {
          'id': newConversation['id'],
          'name': selectedUser['name'],
          'avatar_url': selectedUser['avatar_url'],
          'is_group': false,
        };
      });

      _fetchMessages(newConversation['id']);
      _fetchConversations(); // Refresh the conversation list
    } catch (e) {
      print('Error starting new conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start conversation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

// --- CHAT DETAIL SCREEN ---
    if (activeChat != null) {
      // Extract the correct name and avatar from the RPC structure
      final isGroup = activeChat!['is_group'] == true;
      final displayName = isGroup
          ? (activeChat!['name'] ?? 'Group Chat')
          : (activeChat!['other_user'] as Map<String, dynamic>?)?['name'] ?? 'Unknown User';

      final avatarUrl = isGroup
          ? activeChat!['avatar_url'] as String?
          : (activeChat!['other_user'] as Map<String, dynamic>?)?['avatar_url'] as String?;

      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _unsubscribeFromCurrentChat();     // <-- ADD THIS LINE
              setState(() => activeChat = null);
              _fetchConversations();
            },
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Online",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: const [
            Icon(Icons.call),
            SizedBox(width: 16),
            Icon(Icons.videocam),
            SizedBox(width: 16),
            Icon(Icons.more_vert),
            SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg["sender_id"] == currentUser?.id;

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        msg["content"] ?? '',
                        style: TextStyle(
                          color: isMe
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Message input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.attach_file), onPressed: () {}),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: InputBorder.none,
                      ),
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

    // --- CHAT LIST + REQUESTS WITH TABS ---
    // Fix the filtering logic
    final filteredConversations = conversations.where((c) {
      // For direct messages, check participant name
      if (!c['is_group'] && c['participants'] != null && c['participants'].isNotEmpty) {
        final participant = c['participants'][0] as Map<String, dynamic>;
        return participant['name']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false;
      }
      // For group chats, check conversation name
      return c['name']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false;
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            // --- MESSAGES TAB ---
// --- MESSAGES TAB ---
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: "Search conversations...",
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (val) => setState(() => searchQuery = val),
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : conversations.isEmpty
                      ? const Center(child: Text("No conversations yet"))
                      : ListView.separated(
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];

                      // SEARCH FILTER — CORRECTED FOR RPC DATA STRUCTURE
                      final otherUser = conversation['other_user'] as Map<String, dynamic>?;
                      final conversationName = conversation['is_group'] == true
                          ? (conversation['name'] ?? 'Group Chat')
                          : (otherUser?['name'] ?? 'Unknown User');

                      if (searchQuery.isNotEmpty &&
                          !conversationName.toLowerCase().contains(searchQuery.toLowerCase())) {
                        return const SizedBox.shrink(); // Hide non-matching
                      }

                      final lastMsgContent = conversation['last_message_content'] ?? 'No messages yet';
                      final lastMsgTime = conversation['last_message_time'];
                      final unreadCount = (conversation['unread_count'] as num?)?.toInt() ?? 0;

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage: (() {
                            final url = conversation['is_group'] == true
                                ? conversation['avatar_url']
                                : otherUser?['avatar_url'];
                            if (url == null || url.toString().trim().isEmpty) return null;
                            return NetworkImage(url);
                          })(),
                          child: (() {
                            final url = conversation['is_group'] == true
                                ? conversation['avatar_url']
                                : otherUser?['avatar_url'];
                            if (url == null || url.toString().trim().isEmpty) {
                              return const Icon(Icons.person);
                            }
                            return null;
                          })(),
                        ),
                        title: Text(
                          conversationName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          lastMsgContent,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (lastMsgTime != null)
                              Text(
                                _formatTime(lastMsgTime),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            if (unreadCount > 0)
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.red,
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(fontSize: 10, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            activeChat = conversation;
                          });
                          _subscribeToCurrentChat();          // <-- ADD THIS LINE
                          _fetchMessages(conversation['id']);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // --- REQUESTS TAB ---
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : workshopRequests.isEmpty
                ? const Center(child: Text("No pending workshop requests"))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: workshopRequests.length,
              itemBuilder: (context, index) {
                final request = workshopRequests[index];
                final requester = request['requester'] as Map<String, dynamic>;
                final workshop = request['workshop'] as Map<String, dynamic>;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(requester['avatar_url'] ?? ''),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${requester['name']} is requesting to join",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    workshop['title'] ?? 'Workshop',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (workshop['skill_requested'] != null)
                          Text("Wants to learn: ${workshop['skill_requested']}"),
                        if (workshop['skill_offered'] != null)
                          Text("Offers: ${workshop['skill_offered']}"),
                        if (request['message'] != null && request['message'].isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text("Message: ${request['message']}"),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => declineRequest(request),
                              child: const Text("Decline"),
                            ),
                            ElevatedButton(
                              onPressed: () => acceptRequest(request),
                              child: const Text("Accept"),
                            ),
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
      ),
    );
  }

  String _formatTime(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

extension on PostgrestFilterBuilder {
  is_(String s, String t) {}
}

extension on PostgrestFilterBuilder<PostgrestList> {
  in_(String s, List<String> conversationIds) {}
}