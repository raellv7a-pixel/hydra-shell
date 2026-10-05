.pragma library

// A valid pre-onboarding settings file belongs to an existing installation.
// Missing/new files keep version zero even after their defaults reach disk.
function versionForSettings(raw, freshInstall, currentVersion) {
  if (freshInstall || !raw || typeof raw !== "object" || Array.isArray(raw))
    return 0;
  if (raw.onboardingVersion === undefined)
    return currentVersion;
  return Number.isInteger(raw.onboardingVersion) && raw.onboardingVersion >= 0 ? raw.onboardingVersion : 0;
}
