import { WearableMetrics, DailyMetrics, Insight, DeviceType } from '../types';

// Generate realistic wearable data for today
export const generateTodayMetrics = (deviceType: DeviceType): WearableMetrics => {
    const now = new Date();
    const hour = now.getHours();

    // Steps increase throughout the day
    const stepsProgress = Math.min(hour / 24, 1);
    const baseSteps = deviceType === 'oura' ? 7000 : 10000;
    const steps = Math.floor(baseSteps * stepsProgress + Math.random() * 1000);

    // Heart rate varies by time of day
    const restingHR = deviceType === 'whoop' ? 55 : 62;
    const avgHR = restingHR + (hour > 6 && hour < 22 ? 15 : 0) + Math.floor(Math.random() * 10);

    return {
        date: now,
        steps,
        heartRate: {
            avg: avgHR,
            min: restingHR - 5,
            max: avgHR + 40,
            resting: restingHR
        },
        sleep: {
            duration: 7.5 + (Math.random() - 0.5),
            quality: 75 + Math.floor(Math.random() * 20),
            deep: 1.5 + Math.random() * 0.5,
            rem: 1.8 + Math.random() * 0.4,
            light: 4.2 + Math.random() * 0.6
        },
        calories: Math.floor(1800 + steps * 0.04),
        activeMinutes: Math.floor(steps / 100),
        hrv: deviceType === 'whoop' || deviceType === 'oura' ? 50 + Math.floor(Math.random() * 30) : undefined,
        spo2: deviceType === 'fitbit' || deviceType === 'garmin' ? 96 + Math.floor(Math.random() * 3) : undefined,
        temperature: deviceType === 'oura' ? 36.5 + (Math.random() - 0.5) * 0.5 : undefined,
        vo2max: deviceType === 'garmin' ? 45 + Math.floor(Math.random() * 10) : undefined
    };
};

// Generate historical daily metrics for the past 7 days
export const generateWeekMetrics = (): DailyMetrics[] => {
    const metrics: DailyMetrics[] = [];
    const today = new Date();

    for (let i = 6; i >= 0; i--) {
        const date = new Date(today);
        date.setDate(date.getDate() - i);

        metrics.push({
            date: date.toISOString().split('T')[0],
            steps: 8000 + Math.floor(Math.random() * 4000),
            calories: 2000 + Math.floor(Math.random() * 500),
            activeMinutes: 45 + Math.floor(Math.random() * 45),
            sleepHours: 6.5 + Math.random() * 2,
            avgHeartRate: 68 + Math.floor(Math.random() * 12),
            hrv: 55 + Math.floor(Math.random() * 25),
            restingHeartRate: 58 + Math.floor(Math.random() * 8)
        });
    }

    return metrics;
};

// Generate personalized insights based on metrics
export const generateInsights = (metrics: DailyMetrics[]): Insight[] => {
    const insights: Insight[] = [];
    const latestMetrics = metrics[metrics.length - 1];
    const avgSteps = metrics.reduce((sum, m) => sum + m.steps, 0) / metrics.length;
    const avgSleep = metrics.reduce((sum, m) => sum + m.sleepHours, 0) / metrics.length;

    // Sleep insight
    if (latestMetrics.sleepHours < 7) {
        insights.push({
            id: 'sleep-1',
            type: 'warning',
            title: 'Sleep Below Target',
            description: `You slept ${latestMetrics.sleepHours.toFixed(1)} hours last night, below your 7-8 hour goal.`,
            recommendation: 'Try to maintain a consistent bedtime routine and avoid screens 1 hour before sleep.',
            metric: 'sleep',
            timestamp: new Date(),
            priority: 1
        });
    } else if (latestMetrics.sleepHours >= 7.5) {
        insights.push({
            id: 'sleep-2',
            type: 'positive',
            title: 'Excellent Sleep Quality',
            description: `Great job! You got ${latestMetrics.sleepHours.toFixed(1)} hours of quality sleep.`,
            metric: 'sleep',
            timestamp: new Date(),
            priority: 2
        });
    }

    // Activity insight
    if (latestMetrics.steps > avgSteps * 1.2) {
        insights.push({
            id: 'steps-1',
            type: 'positive',
            title: 'Activity Streak!',
            description: `You've walked ${latestMetrics.steps.toLocaleString()} steps today, 20% above your weekly average!`,
            metric: 'steps',
            timestamp: new Date(),
            priority: 3
        });
    } else if (latestMetrics.steps < 7000) {
        insights.push({
            id: 'steps-2',
            type: 'info',
            title: 'Low Activity Today',
            description: `You're at ${latestMetrics.steps.toLocaleString()} steps. Try a short walk to reach 10,000!`,
            recommendation: 'Take a 15-minute walk after dinner to boost your daily count.',
            metric: 'steps',
            timestamp: new Date(),
            priority: 2
        });
    }

    // HRV insight
    if (latestMetrics.hrv && latestMetrics.hrv < 50) {
        insights.push({
            id: 'hrv-1',
            type: 'warning',
            title: 'Low Heart Rate Variability',
            description: 'Your HRV is lower than usual, which may indicate stress or insufficient recovery.',
            recommendation: 'Consider taking a rest day and practicing stress-reducing activities like meditation.',
            metric: 'hrv',
            timestamp: new Date(),
            priority: 1
        });
    }

    // Sleep trend insight
    const sleepTrend = latestMetrics.sleepHours - avgSleep;
    if (Math.abs(sleepTrend) > 1) {
        insights.push({
            id: 'sleep-trend',
            type: 'info',
            title: sleepTrend > 0 ? 'Improved Sleep Pattern' : 'Declining Sleep Pattern',
            description: `Your sleep has ${sleepTrend > 0 ? 'increased' : 'decreased'} by ${Math.abs(sleepTrend).toFixed(1)} hours compared to your weekly average.`,
            metric: 'sleep',
            timestamp: new Date(),
            priority: 2
        });
    }

    return insights.sort((a, b) => a.priority - b.priority);
};

// Calculate protocol adherence score
export const calculateAdherenceScore = (metrics: DailyMetrics[]): number => {
    let score = 0;
    let maxScore = 0;

    metrics.forEach(day => {
        // Steps goal: 10,000 steps = 20 points
        if (day.steps >= 10000) score += 20;
        else score += (day.steps / 10000) * 20;
        maxScore += 20;

        // Sleep goal: 7-8 hours = 20 points
        if (day.sleepHours >= 7 && day.sleepHours <= 8) score += 20;
        else if (day.sleepHours >= 6.5) score += 15;
        else score += (day.sleepHours / 7) * 10;
        maxScore += 20;

        // Active minutes goal: 60 minutes = 15 points
        if (day.activeMinutes >= 60) score += 15;
        else score += (day.activeMinutes / 60) * 15;
        maxScore += 15;

        // Heart rate recovery (HRV if available) = 10 points
        if (day.hrv) {
            if (day.hrv >= 60) score += 10;
            else score += (day.hrv / 60) * 10;
        } else {
            score += 7; // Default partial credit
        }
        maxScore += 10;
    });

    return Math.round((score / maxScore) * 100);
};

// Simulate device sync
export const simulateSync = (deviceId: string): Promise<boolean> => {
    return new Promise((resolve) => {
        setTimeout(() => {
            resolve(true);
        }, 1500 + Math.random() * 1000);
    });
};

// Calculate HRV baseline from historical data
export const getHRVBaseline = (metrics: DailyMetrics[]): number => {
    const hrvValues = metrics.map(m => m.hrv).filter(v => v !== undefined) as number[];
    if (hrvValues.length === 0) return 60;
    return hrvValues.reduce((sum, v) => sum + v, 0) / hrvValues.length;
};

// Calculate RHR baseline
export const getRHRBaseline = (metrics: DailyMetrics[]): number => {
    const rhrValues = metrics.map(m => m.avgHeartRate);
    return rhrValues.reduce((sum, v) => sum + v, 0) / rhrValues.length;
};

// Calculate recovery score (0-100)
export const calculateRecoveryScore = (todayMetrics: WearableMetrics, weekMetrics: DailyMetrics[]): number => {
    let score = 0;

    // HRV component (40 points)
    if (todayMetrics.hrv) {
        const hrvBaseline = getHRVBaseline(weekMetrics);
        const hrvDiff = todayMetrics.hrv - hrvBaseline;
        const hrvScore = Math.min(40, Math.max(0, 25 + (hrvDiff / hrvBaseline) * 40));
        score += hrvScore;
    } else {
        score += 25; // Default if no HRV
    }

    // Sleep component (30 points)
    const sleepQuality = todayMetrics.sleep.quality / 100 * 30;
    score += sleepQuality;

    // RHR component (20 points)
    const rhrBaseline = getRHRBaseline(weekMetrics);
    const rhrDiff = rhrBaseline - todayMetrics.heartRate.resting;
    const rhrScore = Math.min(20, Math.max(0, 12 + (rhrDiff / rhrBaseline) * 20));
    score += rhrScore;

    // Activity balance (10 points) - penalize if yesterday was very high activity
    const yesterdayActivity = weekMetrics[weekMetrics.length - 1]?.activeMinutes || 50;
    const activityScore = Math.min(10, Math.max(5, 10 - (yesterdayActivity - 60) / 10));
    score += activityScore;

    return Math.round(Math.min(100, Math.max(0, score)));
};

// Generate smart recommendations based on metrics
export const generateRecommendations = (
    todayMetrics: WearableMetrics,
    weekMetrics: DailyMetrics[],
    recoveryScore: number
): string[] => {
    const recommendations: string[] = [];

    // Recovery-based training advice
    if (recoveryScore >= 85) {
        recommendations.push("💪 Great recovery! Good day for intense training");
    } else if (recoveryScore >= 70) {
        recommendations.push("✅ Moderate recovery - light to moderate activity recommended");
    } else {
        recommendations.push("🛌 Low recovery score - prioritize rest and light movement today");
    }

    // HRV insights
    if (todayMetrics.hrv) {
        const hrvBaseline = getHRVBaseline(weekMetrics);
        if (todayMetrics.hrv < hrvBaseline - 10) {
            recommendations.push("⚠️ HRV below baseline - consider stress management or extra rest");
        } else if (todayMetrics.hrv > hrvBaseline + 10) {
            recommendations.push("🎯 HRV elevated - excellent readiness for training");
        }
    }

    // Sleep analysis
    if (todayMetrics.sleep.duration < 7) {
        const deficit = (7 - todayMetrics.sleep.duration).toFixed(1);
        recommendations.push(`😴 Sleep ${deficit}h below target - aim for earlier bedtime tonight`);
    } else if (todayMetrics.sleep.deep < 1.2) {
        recommendations.push("🌙 Low deep sleep - avoid alcohol and late meals");
    }

    // RHR trends
    const rhrBaseline = getRHRBaseline(weekMetrics);
    if (todayMetrics.heartRate.resting > rhrBaseline + 5) {
        recommendations.push("❤️ Elevated resting HR - monitor for illness or overtraining");
    }

    // Activity consistency
    const avgSteps = weekMetrics.reduce((sum, m) => sum + m.steps, 0) / weekMetrics.length;
    if (todayMetrics.steps < avgSteps * 0.7) {
        recommendations.push("🚶 Activity below average - take a 15-minute walk");
    }

    // Hydration (based on activity)
    const targetWater = (todayMetrics.activeMinutes / 60) * 0.5 + 2;
    recommendations.push(`💧 Drink ${targetWater.toFixed(1)}L water today based on activity level`);

    return recommendations.slice(0, 5); // Return top 5
};

// ===== ADVANCED PHYSIOLOGICAL ALGORITHMS =====

// Calculate Advanced HRV Metrics
export const calculateAdvancedHRV = (todayMetrics: WearableMetrics, weekMetrics: DailyMetrics[]): any => {
    const hrv = todayMetrics.hrv || 60;

    // rMSSD (gold standard for vagal tone)
    const rMSSD = hrv; // In our simulation, HRV already represents rMSSD

    // SDNN (total variability) - typically 1.5-2x rMSSD
    const SDNN = rMSSD * 1.7;

    // pNN50 (percentage of intervals > 50ms difference)
    // Correlated with rMSSD: high rMSSD → high pNN50
    const pNN50 = Math.min(50, (rMSSD / 100) * 45);

    // LF/HF Ratio simulation
    // HF power (0.15-0.4 Hz): vagal activity
    const HF_power = Math.pow(rMSSD, 2) * 2.5;
    // LF power (0.04-0.15 Hz): mixed autonomic
    const LF_power = Math.pow(SDNN, 2) * 1.8;
    const LFHF = LF_power / HF_power;

    // Baevsky Stress Index
    // SI = AMo50 / (2 × Mode × MxDMn)
    // Higher SI = more stress (rigid heart rate)
    const Mode = 800; // Most common R-R interval (ms)
    const MxDMn = rMSSD * 4; // Range of variability
    const AMo50 = Math.max(10, 60 - rMSSD); // Mode amplitude (inverse of HRV)
    const baevskyIndex = AMo50 / (2 * (Mode / 1000) * (MxDMn / 1000));

    return { rMSSD, SDNN, pNN50, LFHF, baevskyIndex };
};

// Calculate ANS Balance
export const calculateANSBalance = (advancedHRV: any, todayMetrics: WearableMetrics): any => {
    const { LFHF, rMSSD } = advancedHRV;

    // Parasympathetic dominance (high HRV, low LF/HF)
    const parasympathetic = Math.min(100, (rMSSD / 80) * 50 + (1 / LFHF) * 50);

    // Sympathetic dominance (low HRV, high LF/HF, elevated RHR)
    const rhrBaseline = 62;
    const rhrFactor = Math.max(0, (todayMetrics.heartRate.resting - rhrBaseline) / rhrBaseline * 30);
    const sympathetic = Math.min(100, LFHF * 20 + rhrFactor);

    // Balance score (50 = perfect balance)
    const balance = 50 + (parasympathetic - sympathetic) / 2;

    // Determine dominance
    let dominance: 'sympathetic' | 'parasympathetic' | 'balanced' = 'balanced';
    if (sympathetic > parasympathetic + 15) dominance = 'sympathetic';
    else if (parasympathetic > sympathetic + 15) dominance = 'parasympathetic';

    return {
        sympathetic: Math.round(sympathetic),
        parasympathetic: Math.round(parasympathetic),
        balance: Math.round(balance),
        dominance
    };
};

// Calculate Welltory-Style Scores
export const calculateWelltoryScores = (advancedHRV: any, todayMetrics: WearableMetrics, weekMetrics: DailyMetrics[]): any => {
    const { rMSSD, pNN50, baevskyIndex, SDNN } = advancedHRV;
    const hrvBaseline = getHRVBaseline(weekMetrics);

    // ENERGY (Parasympathetic Potential): 0-100
    // High rMSSD and pNN50 = high energy reserve
    const rmssdScore = Math.min(100, (rMSSD / hrvBaseline) * 50);
    const pnn50Score = pNN50;
    const energy = Math.round(rmssdScore + pnn50Score);

    // STRESS (Sympathetic Load): 0-100
    // High Baevsky Index and LF/HF = high stress
    const stressFromIndex = Math.min(50, baevskyIndex * 5);
    const stressFromHR = Math.min(50, (todayMetrics.heartRate.resting - 60) * 2);
    const stress = Math.round(stressFromIndex + stressFromHR);

    // HEALTH (Homeostatic Stability): 0-100
    // High SDNN and consistent HRV = good health
    const healthFromSDNN = Math.min(70, (SDNN / 100) * 70);
    const hrvVariance = weekMetrics.reduce((variance, m) => {
        const diff = (m.hrv || hrvBaseline) - hrvBaseline;
        return variance + diff * diff;
    }, 0) / weekMetrics.length;
    const stabilityScore = Math.max(0, 30 - hrvVariance / 10); // Lower variance = higher score
    const health = Math.round(healthFromSDNN + stabilityScore);

    return {
        energy: Math.min(100, Math.max(0, energy)),
        stress: Math.min(100, Math.max(0, stress)),
        health: Math.min(100, Math.max(0, health))
    };
};

// Calculate Homeostatic Capacity
export const calculateHomeostaticCapacity = (
    welltoryScores: any,
    todayMetrics: WearableMetrics,
    recoveryScore: number
): any => {
    const baseline = 100;

    // Current capacity = (Energy - Stress) × Sleep Quality × Recovery
    const energyFactor = welltoryScores.energy / 100;
    const stressFactor = 1 - (welltoryScores.stress / 100);
    const sleepFactor = todayMetrics.sleep.quality / 100;
    const recoveryFactor = recoveryScore / 100;

    const current = Math.round(baseline * energyFactor * stressFactor * sleepFactor * recoveryFactor);
    const available = Math.round((current / baseline) * 100);

    // Determine status
    let status: 'depleted' | 'low' | 'moderate' | 'high' | 'optimal' = 'moderate';
    if (available >= 80) status = 'optimal';
    else if (available >= 60) status = 'high';
    else if (available >= 40) status = 'moderate';
    else if (available >= 20) status = 'low';
    else status = 'depleted';

    return { current, baseline, available, status };
};

// Calculate Training Stress Balance
export const calculateTrainingLoad = (weekMetrics: DailyMetrics[]): any => {
    // Generate 30 days of data (extend week metrics)
    const thirtyDayMetrics = [];
    for (let i = 0; i < 30; i++) {
        const dayIndex = i % 7;
        thirtyDayMetrics.push(weekMetrics[dayIndex]);
    }

    // Acute Load: Last 7 days average strain
    const acute = weekMetrics.reduce((sum, m) => sum + m.activeMinutes + (m.steps / 100), 0) / 7;

    // Chronic Load: Last 30 days average strain
    const chronic = thirtyDayMetrics.reduce((sum, m) => sum + m.activeMinutes + (m.steps / 100), 0) / 30;

    // Training Stress Balance
    const tsb = chronic - acute;

    // Determine status
    let status: 'detraining' | 'fresh' | 'maintained' | 'productive' | 'overreaching' = 'maintained';
    if (tsb > 10) status = 'detraining';
    else if (tsb > 5) status = 'fresh';
    else if (tsb > -5) status = 'maintained';
    else if (tsb > -10) status = 'productive';
    else status = 'overreaching';

    return {
        acute: Math.round(acute),
        chronic: Math.round(chronic),
        tsb: Math.round(tsb),
        status
    };
};

// Calculate Mental Resilience Score
export const calculateMentalResilience = (weekMetrics: DailyMetrics[]): any => {
    const hrvBaseline = getHRVBaseline(weekMetrics);
    const rhrBaseline = getRHRBaseline(weekMetrics);

    // HRV Consistency (lower variance = better)
    const hrvVariance = weekMetrics.reduce((v, m) => {
        const diff = (m.hrv || hrvBaseline) - hrvBaseline;
        return v + Math.abs(diff);
    }, 0) / weekMetrics.length;
    const hrvConsistency = Math.max(0, 100 - hrvVariance);

    // RHR Stability (lower variance = better)
    const rhrVariance = weekMetrics.reduce((v, m) => {
        const diff = m.avgHeartRate - rhrBaseline;
        return v + Math.abs(diff);
    }, 0) / weekMetrics.length;
    const rhrStability = Math.max(0, 100 - rhrVariance * 2);

    // Sleep Consistency (regularity of schedule)
    const avgSleep = weekMetrics.reduce((sum, m) => sum + m.sleepHours, 0) / weekMetrics.length;
    const sleepVariance = weekMetrics.reduce((v, m) => {
        return v + Math.abs(m.sleepHours - avgSleep);
    }, 0) / weekMetrics.length;
    const sleepConsistency = Math.max(0, 100 - sleepVariance * 30);

    // Overall Score (weighted average)
    const score = Math.round(
        hrvConsistency * 0.4 +
        rhrStability * 0.3 +
        sleepConsistency * 0.3
    );

    // Trend analysis (compare first half vs second half of week)
    const firstHalf = weekMetrics.slice(0, 3);
    const secondHalf = weekMetrics.slice(4, 7);
    const firstHalfAvg = firstHalf.reduce((sum, m) => sum + (m.hrv || 60), 0) / 3;
    const secondHalfAvg = secondHalf.reduce((sum, m) => sum + (m.hrv || 60), 0) / 3;

    let overallTrend: 'improving' | 'stable' | 'declining' = 'stable';
    if (secondHalfAvg > firstHalfAvg * 1.1) overallTrend = 'improving';
    else if (secondHalfAvg < firstHalfAvg * 0.9) overallTrend = 'declining';

    return {
        score,
        hrvConsistency: Math.round(hrvConsistency),
        rhrStability: Math.round(rhrStability),
        sleepConsistency: Math.round(sleepConsistency),
        overallTrend
    };
};

export const generateSleepMetrics = (): import('../types').SleepMetrics => {
    // Simulate realistic sleep architecture
    const total = 465; // 7h 45m
    return {
        totalDuration: total,
        efficiency: 92,
        deep: Math.round(total * 0.22), // ~22% deep
        rem: Math.round(total * 0.25), // ~25% REM
        light: Math.round(total * 0.45), // ~45% light
        awake: Math.round(total * 0.08), // ~8% awake
        latency: 12
    };
};

export const generateVitals = (): import('../types').Vitals => {
    return {
        spO2: 98,
        respiratoryRate: 14.5,
        skinTempDeviation: -0.2, // Slightly cooler is often good for recovery
    };
};

// Enhanced Context-Aware Recommendations
export const generateAdvancedRecommendations = (
    ansBalance: any,
    welltoryScores: any,
    capacity: any,
    trainingLoad: any,
    mentalResilience: any
): string[] => {
    const recommendations: string[] = [];

    // ANS-based recommendations
    if (ansBalance.dominance === 'sympathetic') {
        recommendations.push("🧘 High sympathetic activation detected - try 5 minutes of box breathing (4-4-4-4)");
        recommendations.push("🌿 Consider a short meditation or nature walk to activate parasympathetic system");
    } else if (ansBalance.dominance === 'parasympathetic' && welltoryScores.energy < 50) {
        recommendations.push("😴 High parasympathetic tone but low energy - you may have accumulated sleep debt");
    }

    // Homeostatic capacity recommendations
    if (capacity.status === 'depleted' || capacity.status === 'low') {
        recommendations.push(`⚠️ Homeostatic capacity at ${capacity.available}% - prioritize recovery over performance today`);
    }

    // Training load recommendations
    if (trainingLoad.status === 'overreaching') {
        recommendations.push("🛑 High training stress detected - take a full rest day to avoid overtraining");
    } else if (trainingLoad.status === 'detraining') {
        recommendations.push("💪 Training load is low - safe to increase activity intensity");
    }

    // Mental resilience recommendations
    if (mentalResilience.score < 60) {
        recommendations.push("🧠 Low mental resilience - focus on sleep schedule consistency and stress management");
    }
    if (mentalResilience.overallTrend === 'declining') {
        recommendations.push("📉 HRV trend declining - review lifestyle factors (alcohol, late meals, screen time)");
    }

    // Welltory scores integration
    if (welltoryScores.stress > 70 && welltoryScores.energy < 40) {
        recommendations.push("⚡ High stress + low energy = burnout risk - take immediate action to reduce load");
    }

    return recommendations.slice(0, 6); // Top 6 recommendations
};
