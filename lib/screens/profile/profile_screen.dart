import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 23),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // PROFILE ICON
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF164B5C),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // HEAD
                  Positioned(
                    top: 10,
                    child: Container(
                      width: 23,
                      height: 23,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // BODY
                  Positioned(
                    bottom: 10,
                    child: Container(
                      width: 57,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                      ),
                    ),
                  ),

                  // EDIT ICON
                  Positioned(
                    right: 0,
                    bottom: 9,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD0D0D0)),
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 12,
                        color: Color(0xFF164B5C),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // NAME
            const Text(
              'Alden Euan Raine Cruz',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF164B5C),
              ),
            ),

            const SizedBox(height: 1),

            // POSITION
            const Text(
              'SSITE Officer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF164B5C),
              ),
            ),

            const SizedBox(height: 4),

            // EDIT PROFILE BUTTON
            SizedBox(
              height: 24,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  side: const BorderSide(color: Color(0xFFD0D0D0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                child: const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 9, color: Color(0xFF555555)),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // INFORMATION DROPBOX
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: Material(
                color: const Color(0xFFD5EAF2),
                borderRadius: BorderRadius.circular(5),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: _isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _isExpanded = expanded;
                    });
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: EdgeInsets.zero,
                  backgroundColor: const Color(0xFFD5EAF2),
                  collapsedBackgroundColor: const Color(0xFFD5EAF2),
                  title: const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF164B5C),
                    ),
                  ),
                  trailing: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF164B5C),
                    size: 25,
                  ),
                  children: [
                    _buildInfoRow(label: 'Student Number', value: '2425-0123'),
                    _buildDivider(),
                    _buildInfoRow(label: 'Year Level', value: '3 - Regular'),
                    _buildDivider(),
                    _buildInfoRow(label: 'Program', value: 'ICS – BSIT'),
                    _buildDivider(),
                    _buildInfoRow(label: 'Gender', value: 'Male'),
                    _buildDivider(),
                    _buildContactRow(
                      icon: Icons.phone,
                      label: 'Contact Number',
                      value: '091284627763',
                    ),
                    _buildDivider(),
                    _buildContactRow(
                      icon: Icons.email,
                      label: 'Email',
                      value: 'Alden67@mcc.edu.ph',
                    ),
                    _buildDivider(),
                    _buildContactRow(
                      icon: Icons.location_on,
                      label: 'Address',
                      value: 'St. Peter, Catucatan, Masaya...',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 17),

            // SWITCH ACCOUNT
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFD5EAF2),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 28),

                  Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: const Color(0xFF164B5C),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 9),

                  const Text(
                    'Switch Account',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF164B5C),
                    ),
                  ),

                  const Spacer(),

                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 27,
                    color: Color(0xFF164B5C),
                  ),

                  const SizedBox(width: 10),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // NORMAL INFORMATION ROW
  Widget _buildInfoRow({required String label, required String value}) {
    return SizedBox(
      width: double.infinity,
      height: 41,
      child: Padding(
        padding: const EdgeInsets.only(left: 28, top: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 8, color: Color(0xFF78909C)),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF164B5C),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CONTACT INFORMATION ROW
  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return SizedBox(
      height: 41,
      child: Row(
        children: [
          const SizedBox(width: 28),

          Container(
            width: 27,
            height: 23,
            decoration: BoxDecoration(
              color: const Color(0xFF164B5C),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(icon, size: 17, color: Colors.white),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFF78909C),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF164B5C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 1, color: Colors.white);
  }
}
