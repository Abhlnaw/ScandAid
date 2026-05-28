enum InjuryType {
  cut,
  burn,
  bruise,
  abrasion, // Scrape
  unknown
}

enum SeverityLevel {
  minor,       // Level 1: general RICE + care 
  mild,        // Level 2: monitor
  moderate,    // Level 3: consider doctor
  severe,      // Level 4: go --> doctor
  critical     // Level 5: call 911
}