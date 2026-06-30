import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tincan_core/tincan_core.dart';

import '../engine/tincan_engine.dart';
import 'add_contact_screen.dart';
import 'backup_screen.dart';
import 'chat_screen.dart';

/// Contact list + access to your own card and to backup.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.engine});

  final TincanEngine engine;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh the list/badges whenever a message arrives.
    widget.engine.incoming.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _showMyCard() async {
    final card = await widget.engine.myCard();
    final encoded = card.encode();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Your contact card',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Short code: ${widget.engine.myShortCodeFormatted}'),
            const SizedBox(height: 16),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(data: encoded, size: 240),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: encoded)),
              icon: const Icon(Icons.copy),
              label: const Text('Copy card text'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = widget.engine.contactsByShortCode.values.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tincan'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Backup',
            icon: const Icon(Icons.backup_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => BackupScreen(engine: widget.engine),
            )),
          ),
          IconButton(
            tooltip: 'My card',
            icon: const Icon(Icons.qr_code_2),
            onPressed: _showMyCard,
          ),
        ],
      ),
      body: contacts.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No contacts yet.\nTap + to add someone by their card.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              itemCount: contacts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = contacts[i];
                final msgs = widget.engine.history[c.shortCode];
                final last =
                    (msgs != null && msgs.isNotEmpty) ? msgs.last : null;
                final initial =
                    c.label.isNotEmpty ? c.label.substring(0, 1) : '?';
                return ListTile(
                  leading: CircleAvatar(child: Text(initial)),
                  title: Text(c.label),
                  subtitle: Text(
                    last?.text ?? ShortCode.format(c.shortCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        ChatScreen(engine: widget.engine, contact: c),
                  )),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => AddContactScreen(engine: widget.engine),
          ));
          if (mounted) setState(() {});
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add contact'),
      ),
    );
  }
}
