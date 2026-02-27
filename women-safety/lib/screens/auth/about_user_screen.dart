import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safety_pal/app_color.dart';
import 'package:safety_pal/widgets/auth_field.dart';
import 'package:safety_pal/widgets/buttons.dart';
import 'package:safety_pal/widgets/gender_button.dart';
import 'package:safety_pal/screens/auth/add_guardians_screen.dart';
import 'package:safety_pal/services/auth_service.dart';

class AboutUser extends StatefulWidget {
  const AboutUser({super.key});

  @override
  State<AboutUser> createState() => _AboutUserState();
}

class _AboutUserState extends State<AboutUser> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _ageController = TextEditingController();
  String? _selectedGender;
  String? _selectedBloodGroup;
  bool _isSaving = false;

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

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

      await AuthService.updateUserProfile(
        uid: currentUser.uid,
        data: {
          'age': int.tryParse(_ageController.text) ?? 0,
          'gender': _selectedGender ?? '',
          'blood_grp': _selectedBloodGroup ?? '',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Details saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving details: $e'),
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
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Center(
            child: Column(
              children: [
                const Text('About User',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 5),
                const Text('Please provide your details',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 30),
                AuthField(
                  title: 'Age',
                  hintText: 'Enter your age',
                  controller: _ageController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Age is required';
                    } else if (int.tryParse(value) == null) {
                      return 'Please enter a valid age';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 15),
                const Text('Gender',
                    style: TextStyle(fontSize: 14, color: Color(0xFF78828A))),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GenderButton(
                      text: 'Male',
                      icon: Icons.male,
                      isSelected: _selectedGender == 'Male',
                      onTap: () {
                        setState(() {
                          _selectedGender = 'Male';
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    GenderButton(
                      text: 'Female',
                      icon: Icons.female,
                      isSelected: _selectedGender == 'Female',
                      onTap: () {
                        setState(() {
                          _selectedGender = 'Female';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Blood Group',
                    fillColor: Color(0xFFF6F6F6),
                    filled: true,
                  ),
                  value: _selectedBloodGroup,
                  items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                      .map((bloodGroup) => DropdownMenuItem(
                            value: bloodGroup,
                            child: Text(bloodGroup),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBloodGroup = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Blood group is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                PrimaryButton(
                  onTap: () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _isSaving = true);
                      await _saveData();
                      setState(() => _isSaving = false);
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddGuardiansPage(),
                          ),
                        );
                      }
                    }
                  },
                  text: _isSaving ? 'Saving...' : 'Submit',
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
