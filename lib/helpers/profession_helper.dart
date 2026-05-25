import 'dart:math';

class ProfessionHelper {
  // List of diverse careers
  static const List<String> _careers = [
    // Creative & Arts
    'Artist',
    'Musician',
    'Designer',
    'Photographer',
    'Writer',
    'Filmmaker',
    'Dancer',
    'Actor',

    // Business & Finance
    'Entrepreneur',
    'Accountant',
    'Manager',
    'Consultant',
    'Banker',
    'Analyst',
    'Investor',

    // Technology
    'Engineer',
    'Developer',
    'Data Scientist',
    'UI/UX Designer',
    'Product Manager',
    'IT Specialist',

    // Healthcare
    'Doctor',
    'Nurse',
    'Therapist',
    'Pharmacist',
    'Dentist',
    'Surgeon',

    // Education
    'Teacher',
    'Professor',
    'Coach',
    'Trainer',

    // Legal & Government
    'Lawyer',
    'Judge',
    'Politician',

    // Media & Communication
    'Journalist',
    'PR Specialist',
    'Content Creator',
    'Social Media Manager',

    // Service Industry
    'Chef',
    'Stylist',
    'Fitness Trainer',
    'Travel Agent',

    // Science & Research
    'Scientist',
    'Researcher',
    'Architect',

    // Others
    'Student',
    'Freelancer',
    'Professional',
  ];

  /// Get a random career
  static String getRandomCareer() {
    final random = Random();
    return _careers[random.nextInt(_careers.length)];
  }

  /// Get a consistent career based on user ID (same user always gets same career)
  static String getCareerForUser(String userId) {
    // Use the hashCode of userId as a seed for consistent results
    final seed = userId.hashCode.abs();
    final random = Random(seed);
    return _careers[random.nextInt(_careers.length)];
  }

  /// Get all available careers
  static List<String> getAllCareers() {
    return List.from(_careers);
  }

  /// Check if a career is valid
  static bool isValidCareer(String career) {
    return _careers.contains(career);
  }
}
