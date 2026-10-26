/// True only for the demo entrypoint build; gates the FICTIONAL-DATA tag and
/// the PLACEHOLDER a11y announce. Never set in the production app.
const bool kDemoBuild = bool.fromEnvironment('DEMO_BUILD', defaultValue: false);
