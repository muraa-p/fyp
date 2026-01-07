class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? bio;
  final String? university;
  final String? major;
  final String? year;
  final String? location;
  final String? website;
  final String? avatarUrl;

  final List<String> skillsToTeach;
  final List<String> skillsToLearn;

  final Map<String, String> social;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.bio,
    this.university,
    this.major,
    this.year,
    this.location,
    this.website,
    this.avatarUrl,
    this.skillsToTeach = const [],
    this.skillsToLearn = const [],
    this.social = const {},
  });

  // ---------------------------------------------------------
  // JSON → MODEL
  // ---------------------------------------------------------
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? 'Unknown',
      email: json['email'] ?? '',
      phone: json['phone'],
      bio: json['bio'],
      university: json['university'],
      major: json['major'],
      year: json['year'],
      location: json['location'],
      website: json['website'],

      // Important: Read avatar_url from DB to ensure consistency
      avatarUrl: json['avatar_url'],

      skillsToTeach: List<String>.from(json['skills_to_teach'] ?? []),
      skillsToLearn: List<String>.from(json['skills_to_learn'] ?? []),

      // Ensure social always has default values
      social: Map<String, String>.from(json['social'] ??
          {
            "instagram": "",
            "twitter": "",
            "linkedin": "",
            "github": "",
          }),
    );
  }

  // ---------------------------------------------------------
  // MODEL → JSON
  // ---------------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "email": email,
      "phone": phone,
      "bio": bio,
      "university": university,
      "major": major,
      "year": year,
      "location": location,
      "website": website,
      "avatar_url": avatarUrl,
      "skills_to_teach": skillsToTeach,
      "skills_to_learn": skillsToLearn,
      "social": social,
    };
  }

  // ---------------------------------------------------------
  // COPY WITH
  // ---------------------------------------------------------
  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? bio,
    String? university,
    String? major,
    String? year,
    String? location,
    String? website,
    String? avatarUrl,
    List<String>? skillsToTeach,
    List<String>? skillsToLearn,
    Map<String, String>? social,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      university: university ?? this.university,
      major: major ?? this.major,
      year: year ?? this.year,
      location: location ?? this.location,
      website: website ?? this.website,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      skillsToTeach: skillsToTeach ?? this.skillsToTeach,
      skillsToLearn: skillsToLearn ?? this.skillsToLearn,
      social: social ?? this.social,
    );
  }
}
