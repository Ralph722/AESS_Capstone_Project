import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';

/// The contact details saved on the profile when the tracer opened.
class ChedGtsContactOriginals {
  const ChedGtsContactOriginals({required this.email, required this.mobile});

  /// The profile's contact email (becomes the login email after verification).
  final String email;
  final String mobile;

  String of(ContactChannel channel) => switch (channel) {
    ContactChannel.email => email,
    ContactChannel.mobile => mobile,
  };
}

/// Q3 (email) and Q5 (mobile) must be verified before a changed value is
/// submitted. Q4 (telephone) is not checked: it is often a landline.
abstract final class ChedGtsContacts {
  static const emailItemId = 'ched_3';
  static const mobileItemId = 'ched_5';

  static String itemId(ContactChannel channel) => switch (channel) {
    ContactChannel.email => emailItemId,
    ContactChannel.mobile => mobileItemId,
  };

  static String answer(Map<String, dynamic> answers, ContactChannel channel) =>
      (answers[itemId(channel)] ?? '').toString().trim();

  /// Contacts whose answer differs from the profile. A cleared answer is not
  /// a change: there is nothing to verify and the profile keeps its value.
  static List<ContactChannel> changed(
    Map<String, dynamic> answers,
    ChedGtsContactOriginals originals,
  ) => [
    for (final c in ContactChannel.values)
      if (answer(answers, c).isNotEmpty &&
          !ContactNormalizer.same(c, answer(answers, c), originals.of(c)))
        c,
  ];

  /// Changed contacts that have not been verified with their current value.
  static List<ContactChannel> unverified(
    Map<String, dynamic> answers,
    ChedGtsContactOriginals originals,
    Map<ContactChannel, String> verified,
  ) => [
    for (final c in changed(answers, originals))
      if (!ContactNormalizer.same(c, verified[c], answer(answers, c))) c,
  ];

  /// [answers] with every unverified contact put back to its profile value.
  static Map<String, dynamic> revertUnverified(
    Map<String, dynamic> answers,
    ChedGtsContactOriginals originals,
    Map<ContactChannel, String> verified,
  ) {
    final out = Map<String, dynamic>.from(answers);
    for (final c in unverified(answers, originals, verified)) {
      final original = originals.of(c).trim();
      if (original.isEmpty) {
        out.remove(itemId(c));
      } else {
        out[itemId(c)] = original;
      }
    }
    return out;
  }

  /// Sentence for the leave dialog, e.g. "Your new email address isn't
  /// verified yet, so it will go back to ana@gmail.com."
  static String revertMessage(
    List<ContactChannel> channels,
    ChedGtsContactOriginals originals,
  ) {
    if (channels.length > 1) {
      return "Your new email address and mobile number aren't verified yet, "
          "so they'll go back to what's on your profile.";
    }
    final c = channels.single;
    final what = c == ContactChannel.email
        ? 'email address'
        : 'mobile number';
    final original = originals.of(c).trim();
    return original.isEmpty
        ? "Your new $what isn't verified yet, so it won't be saved."
        : "Your new $what isn't verified yet, so it will go back to "
              '$original.';
  }
}
