enum InjuryType {
  cut,
  burn,
  bruise,
  abrasion,
  unknown;

  String get displayName => switch (this) {
        InjuryType.cut => 'Cut / Laceration',
        InjuryType.burn => 'Burn',
        InjuryType.bruise => 'Bruise',
        InjuryType.abrasion => 'Abrasion / Scrape',
        InjuryType.unknown => 'Unclassified',
      };
}

enum SeverityLevel {
  minor,
  mild,
  moderate,
  severe,
  critical;

  int get score => index + 1;

  String get displayName => switch (this) {
        SeverityLevel.minor => 'Minor — monitor at home',
        SeverityLevel.mild => 'Mild — keep clean and watch',
        SeverityLevel.moderate => 'Moderate — consider professional care',
        SeverityLevel.severe => 'Severe — seek medical attention',
        SeverityLevel.critical => 'Critical — seek emergency care',
      };

  String get shortLabel => switch (this) {
        SeverityLevel.minor => 'Minor',
        SeverityLevel.mild => 'Mild',
        SeverityLevel.moderate => 'Moderate',
        SeverityLevel.severe => 'Severe',
        SeverityLevel.critical => 'Critical',
      };
}
