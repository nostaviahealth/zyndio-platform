enum ProviderType { onDevice, cloud }

enum BrandDataType {
  sleep,
  heartRate,
  hrv,
  spo2,
  activity,
  workouts,
  body,
  glucose
}

enum BrandProvider {
  healthKit(
      displayName: 'Apple Health',
      type: ProviderType.onDevice,
      platform: 'ios',
      supportedDataTypes: [
        BrandDataType.sleep,
        BrandDataType.heartRate,
        BrandDataType.hrv,
        BrandDataType.spo2,
        BrandDataType.activity,
        BrandDataType.workouts,
        BrandDataType.body,
        BrandDataType.glucose
      ]),
  healthConnect(
      displayName: 'Google Health Connect',
      type: ProviderType.onDevice,
      platform: 'android',
      supportedDataTypes: [
        BrandDataType.sleep,
        BrandDataType.heartRate,
        BrandDataType.hrv,
        BrandDataType.spo2,
        BrandDataType.activity,
        BrandDataType.workouts,
        BrandDataType.body,
        BrandDataType.glucose
      ]),
  oura(displayName: 'Oura Ring', type: ProviderType.cloud, supportedDataTypes: [
    BrandDataType.sleep,
    BrandDataType.heartRate,
    BrandDataType.hrv,
    BrandDataType.spo2,
    BrandDataType.activity
  ]),
  whoop(displayName: 'WHOOP', type: ProviderType.cloud, supportedDataTypes: [
    BrandDataType.sleep,
    BrandDataType.heartRate,
    BrandDataType.hrv,
    BrandDataType.activity,
    BrandDataType.workouts
  ]),
  fitbit(displayName: 'Fitbit', type: ProviderType.cloud, supportedDataTypes: [
    BrandDataType.sleep,
    BrandDataType.heartRate,
    BrandDataType.spo2,
    BrandDataType.activity,
    BrandDataType.workouts,
    BrandDataType.body
  ]),
  withings(
      displayName: 'Withings',
      type: ProviderType.cloud,
      supportedDataTypes: [
        BrandDataType.sleep,
        BrandDataType.heartRate,
        BrandDataType.activity,
        BrandDataType.body
      ]),
  polar(displayName: 'Polar', type: ProviderType.cloud, supportedDataTypes: [
    BrandDataType.sleep,
    BrandDataType.heartRate,
    BrandDataType.activity,
    BrandDataType.workouts
  ]),
  garmin(displayName: 'Garmin', type: ProviderType.cloud, supportedDataTypes: [
    BrandDataType.sleep,
    BrandDataType.heartRate,
    BrandDataType.hrv,
    BrandDataType.spo2,
    BrandDataType.activity,
    BrandDataType.workouts,
    BrandDataType.body
  ]),
  dexcom(
      displayName: 'Dexcom',
      type: ProviderType.cloud,
      supportedDataTypes: [BrandDataType.glucose]),
  ultrahuman(
      displayName: 'Ultrahuman Ring',
      type: ProviderType.cloud,
      supportedDataTypes: [
        BrandDataType.sleep,
        BrandDataType.heartRate,
        BrandDataType.hrv,
        BrandDataType.activity
      ]);

  final String displayName;
  final ProviderType type;
  final String? platform;
  final List<BrandDataType> supportedDataTypes;

  const BrandProvider({
    required this.displayName,
    required this.type,
    this.platform,
    required this.supportedDataTypes,
  });
}
