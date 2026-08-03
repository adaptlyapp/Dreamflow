class PainDetail {
  final String area; // e.g., "lower_back", "right_knee"
  final String type; // e.g., "ache", "stabbing", "burning"
  final int intensity; // 1-10
  final String? note;

  const PainDetail({
    required this.area,
    required this.type,
    required this.intensity,
    this.note,
  });

  factory PainDetail.fromJson(Map<String, dynamic> json) => PainDetail(
    area: json['area'],
    type: json['type'],
    intensity: json['intensity'],
    note: json['note'],
  );

  Map<String, dynamic> toJson() => {
    'area': area,
    'type': type,
    'intensity': intensity,
    if (note != null) 'note': note,
  };

  PainDetail copyWith({
    String? area,
    String? type,
    int? intensity,
    String? note,
  }) => PainDetail(
    area: area ?? this.area,
    type: type ?? this.type,
    intensity: intensity ?? this.intensity,
    note: note ?? this.note,
  );
}

/// Body area definitions - Clinical-grade 48-region anatomy map
class BodyAreas {
  // Head & Neck (4 regions)
  static const String headFront = 'head_front';
  static const String headBack = 'head_back';
  static const String neckFront = 'neck_front';
  static const String neckBack = 'neck_back';
  
  // Shoulders (4 regions)
  static const String leftShoulderFront = 'left_shoulder_front';
  static const String rightShoulderFront = 'right_shoulder_front';
  static const String leftShoulderBack = 'left_shoulder_back';
  static const String rightShoulderBack = 'right_shoulder_back';
  
  // Torso Front (6 regions)
  static const String chestLeft = 'chest_left';
  static const String chestRight = 'chest_right';
  static const String abdomenUpper = 'abdomen_upper';
  static const String abdomenLower = 'abdomen_lower';
  static const String abdomenLeft = 'abdomen_left';
  static const String abdomenRight = 'abdomen_right';
  
  // Torso Back (6 regions)
  static const String upperBackLeft = 'upper_back_left';
  static const String upperBackRight = 'upper_back_right';
  static const String middleBackLeft = 'middle_back_left';
  static const String middleBackRight = 'middle_back_right';
  static const String lowerBackLeft = 'lower_back_left';
  static const String lowerBackRight = 'lower_back_right';
  
  // Arms (8 regions)
  static const String leftUpperArm = 'left_upper_arm';
  static const String rightUpperArm = 'right_upper_arm';
  static const String leftElbow = 'left_elbow';
  static const String rightElbow = 'right_elbow';
  static const String leftForearm = 'left_forearm';
  static const String rightForearm = 'right_forearm';
  static const String leftWrist = 'left_wrist';
  static const String rightWrist = 'right_wrist';
  
  // Hands (4 regions)
  static const String leftHandPalm = 'left_hand_palm';
  static const String rightHandPalm = 'right_hand_palm';
  static const String leftHandBack = 'left_hand_back';
  static const String rightHandBack = 'right_hand_back';
  
  // Hips & Pelvis (4 regions)
  static const String leftHipFront = 'left_hip_front';
  static const String rightHipFront = 'right_hip_front';
  static const String leftHipBack = 'left_hip_back';
  static const String rightHipBack = 'right_hip_back';
  
  // Legs (8 regions)
  static const String leftThighFront = 'left_thigh_front';
  static const String rightThighFront = 'right_thigh_front';
  static const String leftThighBack = 'left_thigh_back';
  static const String rightThighBack = 'right_thigh_back';
  static const String leftKnee = 'left_knee';
  static const String rightKnee = 'right_knee';
  static const String leftCalfFront = 'left_calf_front';
  static const String rightCalfFront = 'right_calf_front';
  
  // Calves & Ankles (6 regions)
  static const String leftCalfBack = 'left_calf_back';
  static const String rightCalfBack = 'right_calf_back';
  static const String leftAnkle = 'left_ankle';
  static const String rightAnkle = 'right_ankle';
  
  // Feet (4 regions)
  static const String leftFootTop = 'left_foot_top';
  static const String rightFootTop = 'right_foot_top';
  static const String leftFootBottom = 'left_foot_bottom';
  static const String rightFootBottom = 'right_foot_bottom';
  
  // Legacy aliases for backward compatibility
  static const String head = headFront;
  static const String neck = neckFront;
  static const String leftShoulder = leftShoulderFront;
  static const String rightShoulder = rightShoulderFront;
  static const String chest = chestLeft;
  static const String abdomen = abdomenUpper;
  static const String lowerBack = lowerBackLeft;
  static const String upperBack = upperBackLeft;
  static const String leftHip = leftHipFront;
  static const String rightHip = rightHipFront;
  static const String leftThigh = leftThighFront;
  static const String rightThigh = rightThighFront;
  static const String leftCalf = leftCalfFront;
  static const String rightCalf = rightCalfFront;
  static const String leftFoot = leftFootTop;
  static const String rightFoot = rightFootTop;
  static const String leftArm = leftUpperArm;
  static const String rightArm = rightUpperArm;
  static const String leftHand = leftHandPalm;
  static const String rightHand = rightHandPalm;

  static String displayName(String area) {
    switch (area) {
      // Head & Neck (Zones 1-3)
      case headFront: return 'Head – Forehead';
      case headBack: return 'Head (Back)';
      case neckFront: return 'Neck / Throat';
      case neckBack: return 'Neck (Back)';
      
      // Shoulders
      case leftShoulderFront: return 'Left Shoulder (Front)';
      case rightShoulderFront: return 'Right Shoulder (Front)';
      case leftShoulderBack: return 'Left Shoulder (Back)';
      case rightShoulderBack: return 'Right Shoulder (Back)';
      
      // Torso Front (Zones 4-5, 12-15)
      case chestLeft: return 'Left Upper Chest (Pectoral)';
      case chestRight: return 'Right Upper Chest (Pectoral)';
      case abdomenUpper: return 'Upper Abdomen';
      case abdomenLower: return 'Pelvis / Groin';
      case abdomenLeft: return 'Left Upper Abdomen';
      case abdomenRight: return 'Right Upper Abdomen';
      
      // Torso Back
      case upperBackLeft: return 'Upper Back (Left)';
      case upperBackRight: return 'Upper Back (Right)';
      case middleBackLeft: return 'Middle Back (Left)';
      case middleBackRight: return 'Middle Back (Right)';
      case lowerBackLeft: return 'Lower Back (Left)';
      case lowerBackRight: return 'Lower Back (Right)';
      
      // Arms (Zones 6-7, 9)
      case leftUpperArm: return 'Left Upper Arm';
      case rightUpperArm: return 'Right Upper Arm';
      case leftElbow: return 'Left Elbow';
      case rightElbow: return 'Right Elbow';
      case leftForearm: return 'Left Forearm';
      case rightForearm: return 'Right Forearm';
      case leftWrist: return 'Left Wrist';
      case rightWrist: return 'Right Wrist';
      
      // Hands (Zone 11)
      case leftHandPalm: return 'Left Hand / Wrist';
      case rightHandPalm: return 'Right Hand / Wrist';
      case leftHandBack: return 'Left Hand (Back)';
      case rightHandBack: return 'Right Hand (Back)';
      
      // Hips (Zone 17)
      case leftHipFront: return 'Left Pelvis / Groin';
      case rightHipFront: return 'Right Pelvis / Groin';
      case leftHipBack: return 'Left Hip (Back)';
      case rightHipBack: return 'Right Hip (Back)';
      
      // Legs (Zones 18, 21-22, 29)
      case leftThighFront: return 'Left Upper Thigh';
      case rightThighFront: return 'Right Upper Thigh';
      case leftThighBack: return 'Left Thigh (Back)';
      case rightThighBack: return 'Right Thigh (Back)';
      case leftKnee: return 'Left Knee / Upper Shin';
      case rightKnee: return 'Right Knee / Upper Shin';
      case leftCalfFront: return 'Left Lower Shin / Calf';
      case rightCalfFront: return 'Right Lower Shin / Calf';
      case leftCalfBack: return 'Left Calf (Back)';
      case rightCalfBack: return 'Right Calf (Back)';
      case leftAnkle: return 'Left Ankle';
      case rightAnkle: return 'Right Ankle';
      
      // Feet
      case leftFootTop: return 'Left Foot (Top)';
      case rightFootTop: return 'Right Foot (Top)';
      case leftFootBottom: return 'Left Foot (Bottom)';
      case rightFootBottom: return 'Right Foot (Bottom)';
      
      default: return area.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    }
  }
  
  /// Get all front-view regions
  static List<String> get frontView => [
    headFront,
    neckFront,
    leftShoulderFront,
    rightShoulderFront,
    chestLeft,
    chestRight,
    abdomenUpper,
    abdomenLower,
    abdomenLeft,
    abdomenRight,
    leftUpperArm,
    rightUpperArm,
    leftElbow,
    rightElbow,
    leftForearm,
    rightForearm,
    leftWrist,
    rightWrist,
    leftHandPalm,
    rightHandPalm,
    leftHipFront,
    rightHipFront,
    leftThighFront,
    rightThighFront,
    leftKnee,
    rightKnee,
    leftCalfFront,
    rightCalfFront,
    leftAnkle,
    rightAnkle,
    leftFootTop,
    rightFootTop,
  ];
  
  /// Get all back-view regions
  static List<String> get backView => [
    headBack,
    neckBack,
    leftShoulderBack,
    rightShoulderBack,
    upperBackLeft,
    upperBackRight,
    middleBackLeft,
    middleBackRight,
    lowerBackLeft,
    lowerBackRight,
    leftHipBack,
    rightHipBack,
    leftThighBack,
    rightThighBack,
    leftCalfBack,
    rightCalfBack,
    leftFootBottom,
    rightFootBottom,
  ];
}

/// Pain type definitions
class PainTypes {
  static const String ache = 'ache';
  static const String burning = 'burning';
  static const String numbness = 'numbness';
  static const String stabbing = 'stabbing';
  static const String pinsNeedles = 'pins_needles';
  static const String throbbing = 'throbbing';
  static const String sharp = 'sharp';
  static const String dull = 'dull';
  static const String cramping = 'cramping';
  static const String shooting = 'shooting';
  static const String other = 'other';

  static String displayName(String type) {
    switch (type) {
      case ache: return 'Ache';
      case burning: return 'Burning';
      case numbness: return 'Numbness';
      case stabbing: return 'Stabbing';
      case pinsNeedles: return 'Pins & Needles';
      case throbbing: return 'Throbbing';
      case sharp: return 'Sharp';
      case dull: return 'Dull';
      case cramping: return 'Cramping';
      case shooting: return 'Shooting';
      case other: return 'Other';
      default: return type;
    }
  }

  static List<String> get all => [
    ache,
    burning,
    numbness,
    stabbing,
    pinsNeedles,
    throbbing,
    sharp,
    dull,
    cramping,
    shooting,
    other,
  ];
}
