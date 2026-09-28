import 'package:flutter/material.dart';

import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isExpanded = true;
  bool _showManageProfile = false;

  @override
  Widget build(BuildContext context) {
    return _showManageProfile
        ? _buildManageProfile(context)
        : _buildProfileOverview(context);
  }

  Widget _buildProfileOverview(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(27, 26, 27, 24),
        child: Column(
          children: [
            _buildProfileAvatar(),
            const SizedBox(height: 12),
            const Text(
              'Alden Euan Raine Cruz',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF164B5C),
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              'SSITE Officer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF164B5C),
              ),
            ),
            const SizedBox(height: 36),
            Material(
              color: const Color(0xFFD5EAF2),
              borderRadius: BorderRadius.circular(5),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildOverviewAction(
                    icon: Icons.account_circle_outlined,
                    title: 'Manage profile',
                    onTap: () {
                      setState(() {
                        _showManageProfile = true;
                      });
                    },
                  ),
                  const Divider(height: 1, color: Colors.white),
                  _buildOverviewAction(
                    icon: Icons.lock,
                    title: 'Password & Security',
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: Colors.white),
                  _buildOverviewAction(
                    icon: Icons.notifications_active,
                    title: 'Notifications',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 23),
            Material(
              color: const Color(0xFFD5EAF2),
              borderRadius: BorderRadius.circular(5),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {},
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 34),
                      Container(
                        width: 32,
                        height: 27,
                        decoration: BoxDecoration(
                          color: const Color(0xFF164B5C),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Switch Account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF164B5C),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 27,
                        color: Color(0xFF164B5C),
                      ),
                      const SizedBox(width: 17),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B3541),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: const Text(
                  'Log out',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 30),
            Icon(icon, size: 23, color: const Color(0xFF164B5C)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF164B5C),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 24, color: Color(0xFF164B5C)),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildManageProfile(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 23),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showManageProfile = false;
                    });
                  },
                  tooltip: 'Back to profile',
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF164B5C)),
                ),
                const Text(
                  'Manage profile',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF164B5C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // PROFILE ICON
            _buildProfileAvatar(),

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

  Widget _buildProfileAvatar() {
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF164B5C),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
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
          Positioned(
            bottom: 10,
            child: Container(
              width: 57,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
            ),
          ),
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
              child: const Icon(Icons.edit, size: 12, color: Color(0xFF164B5C)),
            ),
          ),
        ],
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
