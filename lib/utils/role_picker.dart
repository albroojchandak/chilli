import 'dart:math';

class RoleProvider {
  static const List<String> _roles = [
    'Artist',
    'Musician',
    'Designer',
    'Photographer',
    'Writer',
    'Filmmaker',
    'Dancer',
    'Actor',
    'Entrepreneur',
    'Accountant',
    'Manager',
    'Consultant',
    'Banker',
    'Analyst',
    'Investor',
    'Engineer',
    'Developer',
    'Data Scientist',
    'UI/UX Designer',
    'Product Manager',
    'IT Specialist',
    'Doctor',
    'Nurse',
    'Therapist',
    'Pharmacist',
    'Dentist',
    'Surgeon',
    'Teacher',
    'Professor',
    'Coach',
    'Trainer',
    'Lawyer',
    'Judge',
    'Politician',
    'Journalist',
    'PR Specialist',
    'Content Creator',
    'Social Media Manager',
    'Chef',
    'Stylist',
    'Fitness Trainer',
    'Travel Agent',
    'Scientist',
    'Researcher',
    'Architect',
    'Student',
    'Freelancer',
    'Professional',
  ];

  static String pickRandom() {
    final random = Random();
    return _roles[random.nextInt(_roles.length)];
  }

  static String pickForUser(String userId) {
    final seed = userId.hashCode.abs();
    final random = Random(seed);
    return _roles[random.nextInt(_roles.length)];
  }

  static List<String> listAll() {
    return List.from(_roles);
  }

  static bool validate(String role) {
    return _roles.contains(role);
  }
}
