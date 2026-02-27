import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safety_pal/app_color.dart';
import 'package:safety_pal/services/auth_service.dart';
import 'package:safety_pal/screens/home/home_screen.dart';

class AddGuardiansPage extends StatefulWidget {
  const AddGuardiansPage({super.key});

  @override
  State<AddGuardiansPage> createState() => _AddGuardiansPageState();
}

class _AddGuardiansPageState extends State<AddGuardiansPage> {
  final List<_Contact> trustedGuardians = [];
  bool _isSaving = false;

  Future<void> _saveData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Convert guardians to the required format
      final guardiansData = trustedGuardians
          .map((guardian) => {
                'name': guardian.name,
                'phone': guardian.phone,
                'email': guardian.email,
              })
          .toList();

      await AuthService.updateUserProfile(
        uid: currentUser.uid,
        data: {
          'guardians': guardiansData,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardians saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving guardians: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving guardians: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.kWhite,
      appBar: AppBar(
        backgroundColor: AppColor.kWhite,
        elevation: 0,
        leading: const BackButton(color: AppColor.kPrimary),
        title: const Text('Trusted Guardians',
            style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: _isSaving
                ? null
                : () async {
                    setState(() => _isSaving = true);
                    await _saveData();
                    setState(() => _isSaving = false);
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomePage(),
                        ),
                      );
                    }
                  },
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: const TextStyle(color: AppColor.kPrimary),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Add trusted guardians who will be notified immediately in case of emergencies.',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // Import from contacts action
              },
              icon: const Icon(Icons.contacts),
              label: const Text('Import from Contacts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionHeader('Trusted Guardians', onAdd: () {
              _showAddContactDialog(context, isGuardian: true);
            }),
            const SizedBox(height: 10),
            _buildContactList(trustedGuardians),
            const SizedBox(height: 20),
            // _buildSectionHeader('Emergency Contacts', onAdd: () {
            //   _showAddContactDialog(context, isGuardian: false);
            // }),
            // const SizedBox(height: 10),
            // _buildContactList(emergencyContacts),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required VoidCallback onAdd}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: onAdd,
          child: const Text('+Add', style: TextStyle(color: AppColor.kPrimary)),
        ),
      ],
    );
  }

  Widget _buildContactList(List<_Contact> contacts) {
    return Column(
      children: contacts.map((contact) {
        return ListTile(
          leading: CircleAvatar(
            child: Text(contact.name[0]),
          ),
          title: Text(contact.name),
          subtitle:
              Text('${contact.relation}\n${contact.phone}\n${contact.email}'),
          trailing: const Icon(Icons.more_vert),
        );
      }).toList(),
    );
  }

  void _showAddContactDialog(BuildContext context, {required bool isGuardian}) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              isGuardian ? 'Add Trusted Guardian' : 'Add Emergency Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final newContact = _Contact(
                    name: nameController.text,
                    email: emailController.text,
                    relation: 'Guardian',
                    phone: phoneController.text,
                  );
                  trustedGuardians.add(newContact);
                });
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _Contact {
  final String name;
  final String email;
  final String relation;
  final String phone;

  _Contact({
    required this.name,
    required this.email,
    required this.relation,
    required this.phone,
  });
}

