import 'package:flutter/material.dart';
import '../../services/trusted_contacts_service.dart';

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() =>
      _TrustedContactsScreenState();
}

class _TrustedContactsScreenState
    extends State<TrustedContactsScreen> {
  final TrustedContactsService _service =
      TrustedContactsService();

  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  String? _citizenId;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // ============================================================
  // LOAD CURRENT CITIZEN + TRUSTED CONTACTS
  // ============================================================

  Future<void> _loadContacts() async {
    try {
      final citizen = await _service.getCurrentCitizen();

      _citizenId = citizen['id'].toString();

      final contacts =
          await _service.getTrustedContacts(_citizenId!);

      if (!mounted) return;

      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load trusted contacts: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // ADD TRUSTED CONTACT
  // ============================================================

  Future<void> _showAddContactDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();

    // Save messenger before the dialog opens.
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Add Trusted Contact',
          ),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // NAME
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(
                      Icons.person_outline,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // PHONE
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // RELATIONSHIP
                TextField(
                  controller: relationshipController,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    prefixIcon: Icon(
                      Icons.people_outline,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // DIALOG BUTTONS
          // ====================================================

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () async {
                final name =
                    nameController.text.trim();

                final phone =
                    phoneController.text.trim();

                final relationship =
                    relationshipController.text.trim();

                // Validate fields
                if (name.isEmpty ||
                    phone.isEmpty ||
                    relationship.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please fill all fields.',
                      ),
                    ),
                  );
                  return;
                }

                // Check citizen ID
                if (_citizenId == null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Citizen profile not found.',
                      ),
                    ),
                  );
                  return;
                }

                try {
                  // Insert into Supabase
                  await _service.addTrustedContact(
                    citizenId: _citizenId!,
                    name: name,
                    phone: phone,
                    relationship: relationship,
                  );

                  // Close dialog
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }

                  // Reload contacts
                  await _loadContacts();

                  if (!mounted) return;

                  // Success message
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Trusted contact added successfully.',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to add contact: $e',
                      ),
                    ),
                  );
                }
              },

              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    // Dispose controllers
    nameController.dispose();
    phoneController.dispose();
    relationshipController.dispose();
  }

  // ============================================================
  // DELETE TRUSTED CONTACT
  // ============================================================

  Future<void> _deleteContact(
    String contactId,
    String contactName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Contact',
          ),

          content: Text(
            'Remove $contactName from your trusted contacts?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteTrustedContact(
        contactId,
      );

      await _loadContacts();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Trusted contact removed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete contact: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // MAIN UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Trusted Contacts',
        ),
      ),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _contacts.isEmpty
              ? _buildEmptyState()
              : _buildContactList(),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _showAddContactDialog,
        icon: const Icon(
          Icons.person_add,
        ),
        label: const Text(
          'Add Contact',
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              Icons.contact_emergency_outlined,
              size: 80,
              color: Colors.grey.shade500,
            ),

            const SizedBox(height: 20),

            const Text(
              'No Trusted Contacts',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Add people you trust so they can be '
              'contacted during an emergency.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: _showAddContactDialog,
              icon: const Icon(
                Icons.person_add,
              ),
              label: const Text(
                'Add Trusted Contact',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTACT LIST
  // ============================================================

  Widget _buildContactList() {
    return RefreshIndicator(
      onRefresh: _loadContacts,

      child: ListView.builder(
        padding: const EdgeInsets.all(16),

        itemCount: _contacts.length,

        itemBuilder: (context, index) {
          final contact = _contacts[index];

          // These match your actual Supabase columns.
          final name =
              contact['contact_name']
                      ?.toString() ??
                  '';

          final phone =
              contact['contact_phone']
                      ?.toString() ??
                  '';

          final relationship =
              contact['relationship']
                      ?.toString() ??
                  '';

          return Card(
            margin: const EdgeInsets.only(
              bottom: 12,
            ),

            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  name.isNotEmpty
                      ? name[0].toUpperCase()
                      : '?',
                ),
              ),

              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              subtitle: Text(
                '$relationship\n$phone',
              ),

              isThreeLine: true,

              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                ),

                onPressed: () {
                  _deleteContact(
                    contact['id'].toString(),
                    name,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
