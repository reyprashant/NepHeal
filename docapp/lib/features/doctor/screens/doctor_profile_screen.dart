import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/models/user.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/profile_avatar_widget.dart';
import '../../auth/screens/login_screen.dart';
import '../../../shared/screens/profile_photo_screen.dart';
import '../../../shared/screens/edit_profile_screen.dart';
import '../../../shared/screens/change_password_screen.dart';
import 'doctor_reviews_screen.dart';
import '../../../shared/widgets/exit_wrapper_widget.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  bool _isLoading = false;
  String? _error;
  String? _doctorBio;

  // Variables to store rating data
  double _averageRating = 0.0;
  int _totalReviews = 0;
  int _totalPatients = 0;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  //Load doctor data including bio and rating
  Future<void> _loadDoctorData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getDoctorProfile();
      if (response['success']) {
        final doctorData = response['data']['doctor'];
        final doctorId = doctorData['doctor_id'];

        setState(() {
          _doctorBio = doctorData['bio'] ?? '';
        });

        //Fetch rating statistics
        await _loadRatingStats(doctorId);
      }
    } catch (e) {
      setState(() {
        _error = 'Could not load doctor data: $e';
      });
      print('Could not load doctor data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //Load rating statistics from the API
  Future<void> _loadRatingStats(int doctorId) async {
    try {
      final response = await ApiService.getDoctorRatingStats(doctorId);
      if (response['success']) {
        final statsData = response['data'];
        setState(() {
          _averageRating = (statsData['average_rating'] ?? 0.0).toDouble();
          _totalReviews = statsData['total_reviews'] ?? 0;
          _totalPatients = _calculateTotalPatients();
        });
      }
    } catch (e) {
      // If rating stats fail to load, continue with default values
      print('Could not load rating stats: $e');
      setState(() {
        _averageRating = 0.0;
        _totalReviews = 0;
      });
    }
  }

  int _calculateTotalPatients() {
    return _totalReviews > 0 ? (_totalReviews * 1.2).round() : 0;
  }


  @override
  Widget build(BuildContext context) {
    return ExitWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showLogoutDialog(context),
            ),
          ],
        ),
        body: Consumer<AuthService>(
          builder: (context, authService, child) {
            final user = authService.user;

            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_error != null) {
              return _buildErrorState();
            }

            if (user == null) {
              return const Center(child: Text('No user data available'));
            }

            return _buildProfileContent(user);
          },
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Colors.red.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _loadDoctorData(); // Reload all data
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(User user) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header with Profile Photo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.green.shade600,
                  Colors.green.shade400,
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Profile Photo with edit functionality
                  ProfileAvatar(
                    imageUrl: user.profilePhotoUrl,
                    initials: user.initials,
                    radius: 60,
                    showEditIcon: true,
                    onEditTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProfilePhotoScreen(
                            user: user,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Dr. ${user.displayName}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_hospital,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Medical Professional',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Stats with dynamic data
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard(
                        icon: Icons.people,
                        title: _totalPatients > 0 ? '${_totalPatients}+' : '0',
                        subtitle: 'Patients',
                        color: Colors.white,
                      ),
                      _buildStatCard(
                        icon: Icons.star,
                        title: _averageRating > 0
                            ? _averageRating.toStringAsFixed(1)
                            : '0.0',
                        subtitle: _totalReviews > 0
                            ? '($_totalReviews reviews)'
                            : 'No reviews',
                        color: Colors.white,
                      ),
                      _buildStatCard(
                        icon: Icons.work,
                        title:
                            '8+', // This could also be made dynamic if have data
                        subtitle: 'Years',
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Profile Information
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Professional Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                _buildInfoCard(
                  icon: Icons.email,
                  title: 'Email',
                  value: user.email,
                  color: Colors.blue,
                ),

                if (user.phone != null && user.phone!.isNotEmpty)
                  _buildInfoCard(
                    icon: Icons.phone,
                    title: 'Phone',
                    value: user.phone!,
                    color: Colors.green,
                  ),

                if (user.address != null && user.address!.isNotEmpty)
                  _buildInfoCard(
                    icon: Icons.location_on,
                    title: 'Clinic Address',
                    value: user.address!,
                    color: Colors.red,
                  ),

                _buildInfoCard(
                  icon: Icons.person,
                  title: 'Gender',
                  value: user.gender.toUpperCase(),
                  color: Colors.purple,
                ),

                if (_totalReviews > 0)
                  _buildClickableInfoCard(
                    icon: Icons.star,
                    title: 'Patient Rating',
                    value:
                        '${_averageRating.toStringAsFixed(1)} ($_totalReviews reviews)',
                    color: Colors.amber,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const DoctorReviewsScreen(),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // Account Actions
                const Text(
                  'Account Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                _buildActionButton(
                  icon: Icons.edit,
                  title: 'Edit Profile',
                  subtitle: 'Update your professional information',
                  color: Colors.green,
                  onTap: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(
                          user: user,
                          doctorBio: _doctorBio,
                        ),
                      ),
                    );

                    if (result == true) {
                      // Profile was updated successfully - reload doctor data
                      await _loadDoctorData();
                    }
                  },
                ),
                _buildActionButton(
                  icon: Icons.security,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  color: Colors.orange,
                  onTap: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (context) => ChangePasswordScreen(user: user),
                      ),
                    );

                    if (result == true) {
                      // Password was changed successfully
                      // Show additional confirmation if needed
                    }
                  },
                ),
                _buildActionButton(
                  icon: Icons.help,
                  title: 'Help & Support',
                  subtitle: 'Get help and contact support',
                  color: Colors.teal,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help & support coming soon!'),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showLogoutDialog(context),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
            ),
            textAlign:
                TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClickableInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: color.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: color.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
