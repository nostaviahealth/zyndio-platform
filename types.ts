export interface User {
  id: string;
  name: string;
  email?: string; // Optional email for Settings page
  age: number;
  bioAge: number;
  avatarUrl: string;
  healthGrade: string;
  primaryGoal: string;
  isPremium: boolean;
  paceOfAging: number; // Biological aging rate (e.g., 0.85 means aging at 85% of normal rate)
}

// Intelligence Data for AI health analysis
export interface IntelligenceData {
  overallScore: number;
  biomarkersScore: number;
  lifestyleScore: number;
  riskFactorsScore: number;
  healthDomains: Array<{
    name: string;
    score: number;
    target: number;
    icon?: string;
  }>;
  diseaseRisks: Array<{
    condition: string;
    probability: number;
    level: 'Low' | 'Moderate' | 'High';
    drivers: string[];
  }>;
  approved?: boolean;
  published?: boolean;
  generatedAt?: string;
  publishedAt?: string;
  lastUpdated?: string;
}

export interface BiomarkerData {
  date: string;
  value: number;
  unit: string;
  status: 'Optimal' | 'Normal' | 'Abnormal';
}

export interface Message {
  id: string;
  sender: 'user' | 'ai' | 'doctor';
  text: string;
  timestamp: Date;
}

// Report type for advanced health panels
export type ReportType =
  | 'standard_blood'
  | 'gut_microbiome'
  | 'genetic'
  | 'methylation'
  | 'heavy_metals'
  | 'toxicity';

// Panel-specific metadata (only relevant fields populated per type)
export interface PanelMetadata {
  // Gut Microbiome
  phylumRatios?: { name: string; percentage: number; color: string }[];
  diversityIndices?: { name: string; value: number; status: string }[];
  pathogens?: { name: string; detected: boolean; level?: string }[];

  // Genetic
  isOneTime?: boolean; // Genetics never change

  // Methylation / Biological Age
  biologicalAge?: number;
  chronologicalAge?: number;
  ageAcceleration?: number;
  paceOfAging?: number;
  clockScores?: { name: string; value: number }[];

  // Heavy Metals
  specimenType?: 'blood' | 'urine' | 'hair' | 'provoked_urine';
  provocationAgent?: string;

  // Toxicity
  toxinCategory?: 'mycotoxin' | 'pesticide' | 'voc' | 'plasticizer' | 'mixed';
  toxinLoadScore?: number;
}

export interface LabReport {
  id: string;
  date: string;
  title: string;
  summary: string;
  reportType?: ReportType;
  providerName?: string;
  aiInterpretation?: string;
  panelMetadata?: PanelMetadata;
  markers: {
    name: string;
    value: string;
    range: string;
    status: 'Normal' | 'Abnormal' | 'Optimal';
    insight?: string;
    category?: string;
    riskLevel?: 'low' | 'moderate' | 'high';
    genotype?: string;
    detected?: boolean;
  }[];
}

export enum TabType {
  LIFESTYLE = 'LIFESTYLE',
  DIET = 'DIET',
  FITNESS = 'FITNESS',
  SUPPLEMENTS = 'SUPPLEMENTS'
}

export type DeviceType = 'apple-watch' | 'fitbit' | 'garmin' | 'oura' | 'whoop';

export interface ConnectedDevice {
  id: string;
  type: DeviceType;
  name: string;
  connected: boolean;
  lastSync: Date;
  battery?: number;
}

export interface WearableMetrics {
  date: Date;
  steps: number;
  heartRate: {
    avg: number;
    min: number;
    max: number;
    resting: number;
  };
  restingHeartRate?: number; // Added for Insights page - can also use heartRate.resting
  sleep: {
    duration: number;
    quality: number;
    deep: number;
    rem: number;
    light: number;
  };
  calories: number;
  activeMinutes: number;
  hrv?: number;
  spo2?: number;
  temperature?: number;
  vo2max?: number;
}

export interface DailyMetrics {
  date: string;
  steps: number;
  calories: number;
  activeMinutes: number;
  sleepHours: number;
  avgHeartRate: number;
  restingHeartRate: number; // Added for Insights page
  hrv?: number;
}

export interface Insight {
  id: string;
  type: 'positive' | 'warning' | 'info';
  title: string;
  description: string;
  recommendation?: string;
  metric: string;
  timestamp: Date;
  priority: number;
}

// Admin Portal & Onboarding Types

export type UserRole = 'user' | 'admin' | 'doctor' | 'nutritionist';

export type SubscriptionPlan = 'free' | 'baseline' | 'plus' | 'pro' | 'ultimate';

export type OnboardingStage =
  | 'payment_pending'
  | 'lab_test_scheduled'
  | 'lab_processing'
  | 'profile_creation' // Admin creates account here
  | 'questionnaire_pending'
  | 'intelligence_generation'
  | 'doctor_verification'
  | 'consultation_scheduled'
  | 'protocol_ready';

export interface PatientProfile extends User {
  role: UserRole;
  stage: OnboardingStage;
  subscriptionPlan: SubscriptionPlan; // Pro or Ultimate
  email: string;
  phone: string;
  joinedDate?: string; // Changed to optional as per instruction

  // Uploads & Data
  labReportUrl?: string;
  questionnaireUrl?: string;

  // Professional Inputs
  doctorNotes?: string;
  nutritionistNotes?: string;

  avatar?: string; // Added as per instruction
  preferences?: { // Added as per instruction
    theme: 'light' | 'dark';
    notifications: boolean;
  };

  // Verification Flags
  isIntelligenceVerified: boolean;
  isDietPlanCreated?: boolean;
  isProtocolPublished: boolean;
}

// ============ HEALTH JOURNEY TYPES ============

export type PhaseGoalType = 'disease_risk_reduction' | 'longevity';
export type PhaseStatus = 'draft' | 'active' | 'completed';

export interface PhaseGoal {
  type: PhaseGoalType;
  description: string;
  targetDisease?: string; // for disease risk reduction
  targetMetrics?: string[]; // e.g., ["LDL cholesterol", "Blood pressure"]
}

export interface LifestyleProtocol {
  habits: Array<{
    name: string;
    time: string;
    duration: string;
    icon: string;
    desc: string;
  }>;
  approved?: boolean;
  published?: boolean;
  publishedAt?: string;
  lastUpdated?: string;
}

export interface DietProtocol {
  principles: string[];
  macros: {
    protein: string;
    fats: string;
    carbs: string;
  };
  calories: number;
  exclusions: string[];
  approved?: boolean;
  published?: boolean;
  publishedAt?: string;
  lastUpdated?: string;
}

export interface FitnessProtocol {
  pillars: Array<{
    title: string;
    desc: string;
    tag: string;
    icon: string;
  }>;
  approved?: boolean;
  published?: boolean;
  publishedAt?: string;
  lastUpdated?: string;
}

export interface SupplementsProtocol {
  items: Array<{
    name: string;
    dosage: string;
    timing: string;
    purpose: string;
  }>;
  approved?: boolean;
  published?: boolean;
  publishedAt?: string;
  lastUpdated?: string;
}

export interface PhaseProtocol {
  lifestyle: LifestyleProtocol | null;
  diet: DietProtocol | null;
  fitness: FitnessProtocol | null;
  supplements: SupplementsProtocol | null;
  allApproved: boolean;
}

export interface JourneyPhase {
  id: string;
  phaseNumber: number;
  goal: PhaseGoal;
  protocol: PhaseProtocol;
  status: PhaseStatus;
  startDate?: string;
  endDate?: string;
  durationWeeks: number;
  notes?: string;
}

export interface HealthJourney {
  id: string;
  patientId: string;
  title?: string;
  status?: 'draft' | 'published' | 'archived';
  phases: JourneyPhase[];
  currentPhaseIndex: number;
  createdAt: string;
  lastUpdated: string;
  generatedByAI: boolean;
}

// ============ MEAL PLAN TYPES ============

export interface Meal {
  time: string;
  name: string;
  desc: string;
  calories?: number;
  protein?: string;
  carbs?: string;
  fats?: string;
}

export interface DayPlan {
  day: string;
  date: string;
  meals: Meal[];
}

export interface MealPlan {
  id: string;
  phaseId: string; // Links to specific journey phase
  version: number;
  weekStartDate: string;
  weeklyPlan: DayPlan[];
  approved: boolean;
  createdAt: string;
  lastUpdated: string;
  notes: string;
}

export interface WeeklyDietPlan {
  id: string;
  patientId: string;
  weekStartDate: string;
  status: 'draft' | 'published';
  days: {
    day: string;
    meals: {
      type: 'breakfast' | 'lunch' | 'dinner' | 'snack';
      name: string;
      calories: number;
      protein: number;
      carbs: number;
      fats: number;
    }[];
  }[];
}

// Advanced Physiological Metrics
export interface ANSBalance {
  sympathetic: number; // 0-100
  parasympathetic: number; // 0-100
  balance: number; // 0-100, 50 = perfect balance
  dominance: 'sympathetic' | 'parasympathetic' | 'balanced';
}

export interface WelltoryScores {
  energy: number; // 0-100, parasympathetic potential
  stress: number; // 0-100, sympathetic load
  health: number; // 0-100, homeostatic stability
}

export interface AdvancedHRV {
  rMSSD: number; // Root mean square of successive differences (ms)
  SDNN: number; // Standard deviation of NN intervals (ms)
  pNN50: number; // Percentage of NN intervals > 50ms (%)
  LFHF: number; // LF/HF ratio (unitless)
  baevskyIndex: number; // Stress index (units)
}

export interface HomeostasticCapacity {
  current: number; // 0-100
  baseline: number; // 0-100
  available: number; // % of baseline
  status: 'depleted' | 'low' | 'moderate' | 'high' | 'optimal';
}

export interface TrainingLoad {
  acute: number; // 7-day average
  chronic: number; // 30-day average
  tsb: number; // Training Stress Balance
  status: 'detraining' | 'fresh' | 'maintained' | 'productive' | 'overreaching';
}

export interface MentalResilience {
  score: number; // 0-100
  hrvConsistency: number; // Lower variance = better
  rhrStability: number; // Lower variance = better
  sleepConsistency: number; // Schedule regularity
  overallTrend: 'improving' | 'stable' | 'declining';
}

export interface SleepMetrics {
  totalDuration: number; // minutes
  efficiency: number; // %
  deep: number; // minutes
  rem: number; // minutes
  light: number; // minutes
  awake: number; // minutes
  latency: number; // minutes
}

export interface Vitals {
  spO2: number; // %
  respiratoryRate: number; // brpm
  skinTempDeviation: number; // celsius deviation
  glucose?: number; // mg/dL (optional)
}