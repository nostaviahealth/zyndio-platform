/// Patient profile model matching the React PatientProfile type
class PatientProfile {
  final String id;
  final String? userId;
  final String? name;
  final String? email;
  final String? phone;
  final int? age;
  final int? bioAge;
  final String? healthGrade;
  final String? primaryGoal;
  final bool isPremium;
  final String subscriptionPlan; // New field
  final double paceOfAging;
  final String? avatarUrl;
  final String stage;
  final String? doctorNotes;
  final String? nutritionistNotes;
  final Map<String, dynamic>? questionnaireData;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? subscriptionExpiresAt; // Expiry for admin overrides
  final String? fcmToken; // Firebase Messaging Token
  final int xp; // Gamification: experience points
  final int coins; // Gamification: reward coins
  final int leagueXp; // League: monthly experience points
  final String currentLeague; // League: current tier name
  final DateTime leagueResetAt; // League: when the current season ends
  final Map<String, int> leagueBadges; // League: persistent collection of earned badges
  final String? organization; // Organization selected for user

  PatientProfile({
    required this.id,
    this.userId,
    this.name,
    this.email,
    this.phone,
    this.age,
    this.bioAge,
    this.healthGrade,
    this.primaryGoal,
    this.isPremium = false,
    this.subscriptionPlan = 'free', // Default to free
    this.paceOfAging = 1.0,
    this.avatarUrl,
    this.stage = 'profile_creation',
    this.doctorNotes,
    this.nutritionistNotes,
    this.questionnaireData,
    this.createdAt,
    this.updatedAt,
    this.subscriptionExpiresAt,
    this.fcmToken,
    this.xp = 0,
    this.coins = 0,
    this.leagueXp = 0,
    this.currentLeague = 'bronze',
    DateTime? leagueResetAt,
    this.leagueBadges = const {},
    this.organization,
  }) : leagueResetAt = leagueResetAt ?? DateTime(2024, 1, 1);

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      // Logic: Try top-level 'age' -> Try 'questionnaire_data.age' -> Null (No Default 30)
      age: json['age'] as int? ?? 
           (json['questionnaire_data'] != null && json['questionnaire_data']['age'] != null 
             ? int.tryParse(json['questionnaire_data']['age'].toString()) 
             : null),
      bioAge: json['bio_age'] as int?,
      healthGrade: json['health_grade'] as String?,
      primaryGoal: json['primary_goal'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
      subscriptionPlan: json['subscription_plan'] as String? ?? 'free',
      paceOfAging: (json['pace_of_aging'] as num?)?.toDouble() ?? 1.0,
      avatarUrl: json['avatar_url'] as String?,
      stage: json['stage'] as String? ?? 'profile_creation',
      doctorNotes: json['doctor_notes'] as String?,
      nutritionistNotes: json['nutritionist_notes'] as String?,
      questionnaireData: json['questionnaire_data'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      subscriptionExpiresAt: json['subscription_expires_at'] != null
          ? DateTime.parse(json['subscription_expires_at'] as String)
          : null,
      fcmToken: json['fcm_token'] as String?,
      name: json['name'] as String?,
      xp: json['xp'] as int? ?? 0,
      coins: json['coins'] as int? ?? 0,
      leagueXp: json['league_xp'] as int? ?? 0,
      currentLeague: json['current_league'] as String? ?? 'bronze',
      leagueResetAt: json['league_reset_at'] != null
          ? DateTime.parse(json['league_reset_at'] as String)
          : DateTime(2024, 1, 1),
      leagueBadges: (json['league_badges'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ?? const {},
      organization: json['organization'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'age': age,
      'bio_age': bioAge,
      'health_grade': healthGrade,
      'primary_goal': primaryGoal,
      'is_premium': isPremium,
      'subscription_plan': subscriptionPlan, // free, baseline, plus, pro, ultimate
      'pace_of_aging': paceOfAging,
      'avatar_url': avatarUrl,
      'stage': stage,
      'doctor_notes': doctorNotes,
      'nutritionist_notes': nutritionistNotes,
      'subscription_expires_at': subscriptionExpiresAt?.toIso8601String(),
      'fcm_token': fcmToken,
      'xp': xp,
      'coins': coins,
      'league_xp': leagueXp,
      'current_league': currentLeague,
      'league_reset_at': leagueResetAt.toIso8601String(),
      'league_badges': leagueBadges,
      'organization': organization,
    };
  }

  PatientProfile copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phone,
    int? age,
    int? bioAge,
    String? healthGrade,
    String? primaryGoal,
    bool? isPremium,
    String? subscriptionPlan,
    double? paceOfAging,
    String? avatarUrl,
    String? stage,
    String? doctorNotes,
    String? nutritionistNotes,
    Map<String, dynamic>? questionnaireData,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? subscriptionExpiresAt,
    String? fcmToken,
    bool clearExpiresAt = false,
    int? xp,
    int? coins,
    int? leagueXp,
    String? currentLeague,
    DateTime? leagueResetAt,
    Map<String, int>? leagueBadges,
    String? organization,
  }) {
    return PatientProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      bioAge: bioAge ?? this.bioAge,
      healthGrade: healthGrade ?? this.healthGrade,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      isPremium: isPremium ?? this.isPremium,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      paceOfAging: paceOfAging ?? this.paceOfAging,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      stage: stage ?? this.stage,
      doctorNotes: doctorNotes ?? this.doctorNotes,
      nutritionistNotes: nutritionistNotes ?? this.nutritionistNotes,
      questionnaireData: questionnaireData ?? this.questionnaireData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subscriptionExpiresAt: clearExpiresAt ? null : (subscriptionExpiresAt ?? this.subscriptionExpiresAt),
      fcmToken: fcmToken ?? this.fcmToken,
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      leagueXp: leagueXp ?? this.leagueXp,
      currentLeague: currentLeague ?? this.currentLeague,
      leagueResetAt: leagueResetAt ?? this.leagueResetAt,
      leagueBadges: leagueBadges ?? this.leagueBadges,
      organization: organization ?? this.organization,
    );
  }
}
