import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String searchQuery = "";
  Map<String, dynamic>? activeChat;
  final TextEditingController _msgController = TextEditingController();

  // --- EXISTING CHATS ---
  final List<Map<String, dynamic>> chats = [
    {
      "id": 1,
      "name": "Sarah Johnson",
      "avatar": "👩‍💻",
      "lastMessage": "Great! Looking forward to the Python workshop",
      "time": "2m ago",
      "unread": 2,
      "online": true,
      "type": "direct",
    },
    {
      "id": 2,
      "name": "Web Development Workshop",
      "avatar": "🌐",
      "lastMessage": "Emily: Thanks for sharing those resources!",
      "time": "15m ago",
      "unread": 0,
      "participants": 12,
      "type": "group",
    },
  ];

  // --- NEW: PENDING EXCHANGE REQUESTS ---
  final List<Map<String, dynamic>> requests = [
    {
      "id": 101,
      "from": "John Doe",
      "skillOffered": "Digital Illustration",
      "skillRequested": "Web Development",
      "time": "3m ago",
      "avatar": "🎨",
    },
    {
      "id": 102,
      "from": "Aisha Malik",
      "skillOffered": "Photography",
      "skillRequested": "Graphic Design",
      "time": "10m ago",
      "avatar": "📸",
    },
  ];

  // --- SAMPLE MESSAGES ---
  final List<Map<String, dynamic>> messages = [
    {"sender": "Sarah Johnson", "message": "Hi! I saw you're teaching Python.", "isMe": false},
    {"sender": "You", "message": "Hi Sarah! I'd be happy to help.", "isMe": true},
    {"sender": "Sarah Johnson", "message": "I'm completely new but motivated!", "isMe": false},
    {"sender": "You", "message": "Perfect! I have a workshop Friday.", "isMe": true},
  ];

  void sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    setState(() {
      messages.add({
        "sender": "You",
        "message": _msgController.text.trim(),
        "isMe": true,
      });
    });
    _msgController.clear();
  }

  void acceptRequest(Map<String, dynamic> req) {
    setState(() {
      requests.remove(req);
      final newChat = {
        "id": DateTime.now().millisecondsSinceEpoch,
        "name": req["from"],
        "avatar": req["avatar"],
        "lastMessage": "Exchange accepted! Let's start collaborating.",
        "time": "Now",
        "unread": 0,
        "online": true,
        "type": "direct",
      };
      chats.insert(0, newChat);
      activeChat = newChat; // auto-open
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Exchange with ${req["from"]} accepted!")),
    );
  }

  void declineRequest(Map<String, dynamic> req) {
    setState(() => requests.remove(req));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // --- CHAT DETAIL SCREEN ---
    if (activeChat != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => activeChat = null),
          ),
          title: Row(
            children: [
              Text(activeChat!["avatar"], style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activeChat!["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("Online", style: theme.textTheme.bodySmall),
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
                  final isMe = msg["isMe"] as bool;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        msg["message"],
                        style: TextStyle(
                          color: isMe
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
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
            )
          ],
        ),
      );
    }

    // --- CHAT LIST + REQUESTS WITH TABS ---
    final filteredChats = chats
        .where((c) => c["name"].toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Messages & Requests"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.message), text: "Messages"),
              Tab(icon: Icon(Icons.swap_horiz), text: "Requests"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
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
                  child: ListView.separated(
                    itemCount: filteredChats.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      return ListTile(
                        leading: Text(chat["avatar"], style: const TextStyle(fontSize: 26)),
                        title: Text(chat["name"], overflow: TextOverflow.ellipsis),
                        subtitle: Text(chat["lastMessage"], overflow: TextOverflow.ellipsis),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(chat["time"], style: theme.textTheme.bodySmall),
                            if (chat["unread"] > 0)
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.red,
                                child: Text(
                                  "${chat["unread"]}",
                                  style: const TextStyle(fontSize: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        onTap: () => setState(() => activeChat = chat),
                      );
                    },
                  ),
                ),
              ],
            ),

            // --- REQUESTS TAB ---
            requests.isEmpty
                ? const Center(child: Text("No pending exchange requests"))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index];
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
                        Text(req["avatar"], style: const TextStyle(fontSize: 30)),
                        const SizedBox(height: 6),
                        Text("${req["from"]} is requesting an exchange",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text("Wants: ${req["skillRequested"]}"),
                        Text("Offers: ${req["skillOffered"]}"),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => declineRequest(req),
                              child: const Text("Decline"),
                            ),
                            ElevatedButton(
                              onPressed: () => acceptRequest(req),
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
      ),
    );
  }
}
