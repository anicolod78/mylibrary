import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/library_provider.dart';

/// Gestione degli scaffali: crea, rinomina, elimina.
class ShelvesScreen extends StatelessWidget {
  const ShelvesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final shelves = provider.shelves;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestisci scaffali')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo'),
      ),
      body: shelves.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nessuno scaffale.\nCreane uno con il pulsante "Nuovo".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
              ),
            )
          : ListView.separated(
              itemCount: shelves.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final name = shelves[i];
                final count = provider.booksOnShelf(name);
                final isDefault = provider.defaultShelf == name;
                return ListTile(
                  leading: IconButton(
                    tooltip: isDefault
                        ? 'Scaffale predefinito (tocca per rimuovere)'
                        : 'Imposta come predefinito',
                    icon: Icon(isDefault ? Icons.star : Icons.star_border,
                        color: isDefault ? Colors.amber[700] : null),
                    onPressed: () =>
                        provider.setDefaultShelf(isDefault ? '' : name),
                  ),
                  title: Text(name),
                  subtitle: Text(
                      isDefault ? '$count libri · predefinito' : '$count libri'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Rinomina',
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _editDialog(context, existing: name),
                      ),
                      IconButton(
                        tooltip: 'Elimina',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, name, count),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _editDialog(BuildContext context, {String? existing}) async {
    final controller = TextEditingController(text: existing ?? '');
    final provider = context.read<LibraryProvider>();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nuovo scaffale' : 'Rinomina scaffale'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome scaffale'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(existing == null ? 'Crea' : 'Salva'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    if (existing == null) {
      await provider.addShelf(name);
    } else {
      await provider.renameShelf(existing, name);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, String name, int count) async {
    final provider = context.read<LibraryProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare lo scaffale?'),
        content: Text(count > 0
            ? 'Lo scaffale "$name" verrà eliminato. I $count libri che vi appartengono resteranno nel catalogo senza scaffale.'
            : 'Lo scaffale "$name" verrà eliminato.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await provider.deleteShelf(name);
    }
  }
}
