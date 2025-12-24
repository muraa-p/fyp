import 'dart:io'; // Required for File type
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart'; // Import image picker
import 'package:url_launcher/url_launcher.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.initialConversation});

  final Map<String, dynamic>? initialConversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  String searchQuery = "";
  Map<String, dynamic>? activeChat;
  RealtimeChannel? _currentChatChannel;
  final TextEditingController _msgController = TextEditingController();
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  final SupabaseClient supabase = Supabase.instance.client;
  User? currentUser;
  String? myName;

  List<Map<String, dynamic>> conversations = [];
  List<Map<String, dynamic>> workshopRequests = [];
  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> groupMembers = [];
  bool isLoadingMembers = false;
  bool isLoading = true;

  RealtimeChannel? _conversationsChannel;
  RealtimeChannel? _requestsChannel;

  // Image Picker instance
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // If an initial conversation is provided, open it immediately
    if (widget.initialConversation != null) {
      _openChat(widget.initialConversation!);
    } else {
      _initializeData();
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
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

    _requestsChannel = supabase
        .channel('workshop_requests')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'workshop_requests',
      callback: (_) => _fetchWorkshopRequests(),
    )
        .subscribe();
  }

  void _openChat(Map<String, dynamic> conversation) {
    _unsubscribeFromCurrentChat();
    setState(() {
      activeChat = conversation;
      messages = [];
    });
    _subscribeToCurrentChat();
    _fetchMessages(conversation['id']);
  }

  void _subscribeToCurrentChat() {
    _unsubscribeFromCurrentChat();
    if (activeChat == null) return;

    _currentChatChannel = supabase.channel('messages_${activeChat!['id']}').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: activeChat!['id'],
      ),
      callback: (payload) {
        final newMsg = payload.newRecord;
        final senderId = newMsg['sender_id'] as String;

        // Check if this is a message sent by the current user
        final isMyMessage = senderId == currentUser!.id;

        // If it's my message, check if we already have a message with the same content sent recently
        if (isMyMessage) {
          final hasSimilarMessage = messages.any((msg) =>
          msg['content'] == newMsg['content'] &&
              msg['sender_id'] == senderId &&
              DateTime.parse(msg['created_at']).isAfter(DateTime.now().subtract(const Duration(seconds: 5)))
          );

          if (hasSimilarMessage) {
            // Find the temporary message and replace it with the server message
            setState(() {
              final index = messages.indexWhere((msg) =>
              msg['content'] == newMsg['content'] &&
                  msg['sender_id'] == senderId
              );
              if (index != -1) {
                messages[index] = {
                  ...newMsg,
                  'sender': {
                    'id': senderId,
                    'name': myName,
                    'avatar_url': currentUser!.userMetadata?['avatar_url'],
                  },
                };
              }
            });
            return;
          }
        }

        // If it's not my message or we don't have a similar message, add it normally
        setState(() {
          messages.add({
            ...newMsg,
            'sender': {
              'id': senderId,
              'name': senderId == currentUser!.id ? myName : 'Other User',
              'avatar_url': null,
            },
          });
          Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
        });

        if (senderId != currentUser!.id) {
          supabase
              .from('messages')
              .update({'read_at': DateTime.now().toIso8601String()})
              .eq('id', newMsg['id']);
        }
      },
    ).subscribe();
  }

  void _unsubscribeFromCurrentChat() {
    _currentChatChannel?.unsubscribe();
    _currentChatChannel = null;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // --- NEW: File Upload Logic ---
  Future<String?> _uploadFile(File file) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final path = '${currentUser!.id}/$fileName';

      await supabase.storage.from('chat-files').upload(path, file);

      final urlResponse = supabase.storage.from('chat-files').getPublicUrl(path);
      return urlResponse;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  // --- NEW: Handle Attachment Press ---
  Future<void> _handleAttachmentPress() async {
    final XFile? file = await _picker.pickMedia(); // Allows images + videos + some files

    if (file == null) return;

    // Temporary loading message
    setState(() {
      messages.add({
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'content': 'Uploading ${file.name}...',
        'sender_id': currentUser!.id,
        'sender': {'id': currentUser!.id, 'name': myName},
        'message_type': 'text',
      });
      _scrollToBottom();
    });

    final uploadedUrl = await _uploadFile(File(file.path));

    setState(() {
      messages.removeWhere((m) => m['id'].toString().startsWith('temp_'));
    });

    if (uploadedUrl != null) {
      final type = getMessageType(file.path);
      await sendMessage(content: uploadedUrl, type: type);

      // Optional friendly message
      String friendly = '';
      if (type == 'pdf') friendly = '📄 Shared a PDF';
      else if (type == 'document') friendly = '📎 Shared a document';
      else if (type == 'image') friendly = '🖼️ Shared a photo';

      if (friendly.isNotEmpty) {
        await sendMessage(content: friendly, type: 'text');
      }
    }
  }

  Future<void> _fetchConversations() async {
    if (currentUser == null) return;
    try {
      final response = await supabase
          .rpc('get_user_conversations', params: {'current_user_id': currentUser!.id});
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
            id, content, created_at, sender_id, message_type,
            sender:users(id, name, avatar_url)
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      setState(() {
        messages = response;
        Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
      });

      await supabase
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .neq('sender_id', currentUser!.id)
          .is_('read_at', null);

      _fetchConversations();
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  // --- UPDATED: sendMessage now handles types ---
  Future<void> sendMessage({required String content, String type = 'text'}) async {
    if (activeChat == null) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    final tempMsg = {
      'id': tempId,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
      'sender_id': currentUser!.id,
      'message_type': type, // Include type in temp msg
      'sender': {
        'id': currentUser!.id,
        'name': myName,
        'avatar_url': currentUser!.userMetadata?['avatar_url'],
      },
    };

    setState(() {
      messages.add(tempMsg);
      Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
    });
    if (type == 'text') _msgController.clear();

    try {
      final data = await supabase
          .from('messages')
          .insert({
        'conversation_id': activeChat!['id'],
        'sender_id': currentUser!.id,
        'content': content,
        'message_type': type, // Insert type into DB
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
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send')));
      setState(() => messages.removeWhere((m) => m['id'] == tempId));
    }
  }

  Future<void> acceptRequest(Map<String, dynamic> request) async {
    try {
      // Get the workshop details to check if it has a conversation_id
      final workshopData = await supabase
          .from('workshops')
          .select('id, title, conversation_id, type')
          .eq('id', request['workshop_id'])
          .single();

      // Update the request status first
      await supabase
          .from('workshop_requests')
          .update({'status': 'accepted'})
          .eq('id', request['id']);

      // Check if this is a Teach4Learn workshop or a regular workshop
      final isTeach4Learn = workshopData['type'] == 'Teach4Learn';

      if (isTeach4Learn) {
        // For Teach4Learn workshops, create a 1-on-1 conversation
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

        // Update or insert the workshop enrollment
        await supabase.from('workshop_enrollments').upsert({
          'user_id': request['requester_id'],
          'workshop_id': request['workshop_id'],
          'status': 'enrolled',
        }, onConflict: 'user_id,workshop_id');

        // Open the 1-on-1 chat
        _openChat({
          'id': newConv['id'],
          'is_group': false,
          'other_user': {
            'id': request['requester_id'],
            'name': request['requester']['name'],
            'avatar_url': request['requester']['avatar_url'],
          },
        });
      } else {
        // For regular workshops, add the user to the workshop group chat
        if (workshopData['conversation_id'] != null) {
          // Update or insert the workshop enrollment
          await supabase.from('workshop_enrollments').upsert({
            'user_id': request['requester_id'],
            'workshop_id': request['workshop_id'],
            'status': 'enrolled',
          }, onConflict: 'user_id,workshop_id');

          // Add the user to the workshop group chat
          await supabase.rpc('add_user_to_workshop_chat', params: {
            'workshop_id': request['workshop_id'],
            'participant_id': request['requester_id'],  // Using participant_id
          });

          // Send a notification message to the group chat
          await supabase.from('messages').insert({
            'conversation_id': workshopData['conversation_id'],
            'sender_id': currentUser!.id,
            'content': "${request['requester']['name']} has joined the workshop!",
          });

          // Open the workshop group chat
          _openChat({
            'id': workshopData['conversation_id'],
            'is_group': true,
            'name': workshopData['title'] + ' - Group Chat',
            'workshop_id': workshopData['id'],
          });
        } else {
          // If no conversation exists, create one
          final conversationId = await supabase.rpc('create_workshop_group_chat', params: {
            'workshop_id': workshopData['id'],
            'workshop_title': workshopData['title'],
            'creator_id': currentUser!.id,
          });

          // Update or insert the workshop enrollment
          await supabase.from('workshop_enrollments').upsert({
            'user_id': request['requester_id'],
            'workshop_id': request['workshop_id'],
            'status': 'enrolled',
          }, onConflict: 'user_id,workshop_id');

          // Add the user to the newly created conversation
          await supabase.rpc('add_user_to_workshop_chat', params: {
            'workshop_id': workshopData['id'],
            'participant_id': request['requester_id'],
          });

          // Send a notification message to the group chat
          await supabase.from('messages').insert({
            'conversation_id': conversationId,
            'sender_id': currentUser!.id,
            'content': "${request['requester']['name']} has joined the workshop!",
          });

          // Open the workshop group chat
          _openChat({
            'id': conversationId,
            'is_group': true,
            'name': workshopData['title'] + ' - Group Chat',
            'workshop_id': workshopData['id'],
          });
        }
      }

      _fetchConversations();
      _fetchWorkshopRequests();
    } catch (e) {
      print('Error accepting request: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to accept: ${e.toString()}')));
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
      print('Error declining request: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to decline')));
    }
  }

  Future<void> startNewConversation() async {
    try {
      // Verify user is authenticated
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to start a conversation')),
        );
        return;
      }

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

      // Check for existing conversation
      final existing = await supabase.rpc('get_existing_conversation', params: {
        'user1_id': currentUser!.id,
        'user2_id': selectedUser['id'],
      });

      if (existing.isNotEmpty) {
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

      // Create new conversation with explicit created_by
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

      // Open the chat
      _openChat({
        'id': newConv['id'],
        'is_group': false,
        'other_user': {
          'id': selectedUser['id'],
          'name': selectedUser['name'],
          'avatar_url': selectedUser['avatar_url'],
        },
      });

      _fetchConversations();

    } catch (e) {
      print('Error starting new conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start conversation: $e')),
      );
    }
  }


  // New: Fetch group members when needed
  Future<void> _fetchGroupMembers(String conversationId) async {
    if (!mounted) return;
    setState(() {
      isLoadingMembers = true;
    });

    try {
      final response = await supabase
          .from('conversation_participants')
          .select('is_admin, user:users(id, name, avatar_url, university, bio, xp)')
          .eq('conversation_id', conversationId)
          .not('user', 'is', null);

      if (mounted) {
        setState(() {
          groupMembers = List<Map<String, dynamic>>.from(response);
          isLoadingMembers = false;
        });
      }
    } catch (e) {
      print('Error fetching group members: $e');
      if (mounted) {
        setState(() => isLoadingMembers = false);
      }
    }
  }

  // New: Show user profile or group members
// Add this field near your other state variables
  String memberSearchQuery = '';

// Updated: Show user profile or enhanced group members dialog
  Future<void> _showProfileOrMembers() async {
    final isGroup = activeChat!['is_group'] == true;

    if (!isGroup) {
      // 1-on-1 chat → show other user's profile
      final otherUser = activeChat!['other_user'] as Map<String, dynamic>;

      try {
        final fullUserData = await supabase
            .from('users')
            .select()
            .eq('id', otherUser['id'])
            .single();

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(user: fullUserData),
            ),
          );
        }
      } catch (e) {
        print("Error loading full profile: $e");
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(user: otherUser),
            ),
          );
        }
      }
    } else {
      // Group chat → show enhanced members dialog
      await _fetchGroupMembers(activeChat!['id']);

      // Reset search when opening
      memberSearchQuery = '';

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              // Filter members based on search
              final filteredMembers = groupMembers.where((participant) {
                final member = participant['user'] as Map<String, dynamic>?;
                if (member == null) return false;

                final name = (member['name'] ?? '').toString().toLowerCase();
                final university = (member['university'] ?? '').toString().toLowerCase();
                final query = memberSearchQuery.toLowerCase();

                return name.contains(query) || university.contains(query);
              }).toList();

              return AlertDialog(
                title: Text(
                  '${activeChat!['name'] ?? 'Group Members'} (${groupMembers.length} members)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 500,
                  child: Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          onChanged: (value) {
                            setDialogState(() {
                              memberSearchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search members...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                      Expanded(
                        child: isLoadingMembers
                            ? const Center(child: CircularProgressIndicator())
                            : filteredMembers.isEmpty
                            ? const Center(child: Text("No members found"))
                            : ListView.separated(
                          itemCount: filteredMembers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final participant = filteredMembers[index];
                            final member = participant['user'] as Map<String, dynamic>?;

                            if (member == null) {
                              return const ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.person_off, color: Colors.white70),
                                ),
                                title: Text('Deleted User'),
                                subtitle: Text('This account no longer exists'),
                                enabled: false,
                              );
                            }

                            final bool isAdmin = participant['is_admin'] == true;

                            return ListTile(
                              onTap: () {
                                Navigator.pop(context); // Close dialog
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserProfileScreen(user: member),
                                  ),
                                );
                              },
                              leading: CircleAvatar(
                                backgroundImage: member['avatar_url']?.isNotEmpty == true
                                    ? NetworkImage(member['avatar_url'] as String)
                                    : null,
                                child: member['avatar_url']?.isNotEmpty != true
                                    ? Text(
                                  (member['name'] as String?)?.isNotEmpty == true
                                      ? (member['name'] as String).substring(0, 1).toUpperCase()
                                      : 'U',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                )
                                    : null,
                              ),
                              title: Text(member['name'] ?? 'Unknown User'),
                              subtitle: Text(member['university'] ?? 'Member'),
                              trailing: isAdmin
                                  ? Chip(
                                label: const Text(
                                  'Admin',
                                  style: TextStyle(fontSize: 10, color: Colors.white),
                                ),
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                              )
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  // --- UPDATED: Message Item Builder ---
  Widget _buildMessageItem(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'] == currentUser?.id;
    final messageType = msg['message_type'] ?? 'text';
    final url = msg['content'] as String?;

    if (messageType == 'image' && url != null) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: const BoxConstraints(maxWidth: 280),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
              progress == null ? child : const CircularProgressIndicator(),
              errorBuilder: (context, error, stack) => const Text('Failed to load image'),
            ),
          ),
        ),
      );
    }

    // Handle PDF / Document / Generic File
    if ((messageType == 'pdf' || messageType == 'document' || messageType == 'file') && url != null) {
      final fileName = url.split('/').last.split('?').first; // Extract filename from URL
      final icon = messageType == 'pdf'
          ? Icons.picture_as_pdf
          : messageType == 'document'
          ? Icons.description
          : Icons.insert_drive_file;

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            // Open file in browser or download
            launchUrl(Uri.parse(url));
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            constraints: const BoxConstraints(maxWidth: 280),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: isMe ? Colors.white : null),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: TextStyle(color: isMe ? Colors.white : null),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.download, color: isMe ? Colors.white : null, size: 18),
              ],
            ),
          ),
        ),
      );
    }

    // Fallback to text
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Text(
          msg['content'] ?? '',
          style: TextStyle(color: isMe ? Colors.white : null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (activeChat != null) {
      final isGroup = activeChat!['is_group'] == true;
      final isWorkshopChat = activeChat!['workshop_id'] != null;
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
              // Make avatar clickable
              // In build() → AppBar title → replace GestureDetector with:
              InkWell(
                onTap: _showProfileOrMembers,
                borderRadius: BorderRadius.circular(40), // for nice ripple
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: CircleAvatar(
                    backgroundImage: avatarUrl?.isNotEmpty == true ? NetworkImage(avatarUrl!) : null,
                    child: avatarUrl?.isNotEmpty != true ? const Icon(Icons.person) : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (isWorkshopChat)
                      Text(
                        'Workshop Group Chat',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: isWorkshopChat ? [
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: () {
                // Show options for sharing materials
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Share Materials'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.slideshow),
                          title: const Text('Share Slides'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            final XFile? file = await _picker.pickMedia();
                            if (file != null) {
                              final url = await _uploadFile(File(file.path));
                              if (url != null) {
                                final type = getMessageType(file.path);
                                await sendMessage(content: url, type: type);
                                // Always say "slides" when using this button
                                await sendMessage(content: 'New slides have been uploaded!', type: 'text');
                              }
                            }
                          },
                        ),

                        ListTile(
                          leading: const Icon(Icons.assignment),
                          title: const Text('Share Assignment'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            final XFile? file = await _picker.pickMedia();
                            if (file != null) {
                              final url = await _uploadFile(File(file.path));
                              if (url != null) {
                                final type = getMessageType(file.path);
                                await sendMessage(content: url, type: type);
                                // Always say "assignment" when using this button
                                await sendMessage(content: 'A new assignment has been posted!', type: 'text');
                              }
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.announcement),
                          title: const Text('Make Announcement'),
                          onTap: () {
                            Navigator.of(context).pop();
                            _showAnnouncementDialog();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ] : null,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (_, i) => _buildMessageItem(messages[i]),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
              child: Row(
                children: [
                  // --- UPDATED: Attach Button ---
                  IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: _handleAttachmentPress
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none),
                      onSubmitted: (_) => sendMessage(content: _msgController.text.trim()),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () => sendMessage(content: _msgController.text.trim())
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
                    final isWorkshopChat = c['workshop_id'] != null;
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
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          ),
                          if (isWorkshopChat)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Workshop',
                                style: TextStyle(fontSize: 10, color: Colors.blue),
                              ),
                            ),
                        ],
                      ),
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

  void _sendWorkshopMessage(String content) {
    if (activeChat == null) return;
    sendMessage(content: content);
  }

  void _showAnnouncementDialog() {
    final TextEditingController announcementController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make Announcement'),
        content: TextField(
          controller: announcementController,
          decoration: const InputDecoration(
            hintText: 'Enter your announcement...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (announcementController.text.trim().isNotEmpty) {
                _sendWorkshopMessage('📢 Announcement: ${announcementController.text.trim()}');
                Navigator.of(context).pop();
              }
            },
            child: const Text('Send'),
          ),
        ],
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



// Add this helper to get mime type or extension-based type
String getMessageType(String filePath) {
  final extension = filePath.split('.').last.toLowerCase();
  const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'];
  const pdfExtensions = ['pdf'];
  const documentExtensions = ['doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'];

  if (imageExtensions.contains(extension)) return 'image';
  if (pdfExtensions.contains(extension)) return 'pdf';
  if (documentExtensions.contains(extension)) return 'document';
  return 'file'; // generic
}

// Extensions for Supabase filters
extension on PostgrestFilterBuilder {
  PostgrestFilterBuilder is_(String column, dynamic value) => filter(column, 'is', value);
}

extension on PostgrestFilterBuilder<PostgrestList> {
  PostgrestFilterBuilder<PostgrestList> in_(String column, List<dynamic> values) => filter(column, 'in', values);
}