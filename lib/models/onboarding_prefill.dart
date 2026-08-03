/// Prefill data passed from the welcome slides into the questionnaire.
class OnboardingPrefill {
  const OnboardingPrefill({this.name, this.email, this.hospitalId, this.interests = const []});

  final String? name;
  final String? email;
  final String? hospitalId;
  final List<String> interests;
}