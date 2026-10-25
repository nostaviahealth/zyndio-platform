/**
 * Zyndio Space - rPPG Engine
 * Remote Photoplethysmography for heart rate and stress detection
 * Uses camera to analyze subtle skin color changes from blood flow
 */

export interface ScanResult {
    heartRate: number;      // BPM
    hrv: number;            // RMSSD in ms
    stressIndex: number;    // 0-100
    confidence: number;     // 0-1
    recommendation: 'low' | 'moderate' | 'high';
}

class RPPGEngine {
    private video: HTMLVideoElement | null = null;
    private canvas: HTMLCanvasElement | null = null;
    private ctx: CanvasRenderingContext2D | null = null;
    private stream: MediaStream | null = null;
    private isScanning = false;
    private animationId: number | null = null;

    // Signal buffers
    private greenSignal: number[] = [];
    private timestamps: number[] = [];

    // Constants
    private readonly SAMPLE_RATE = 30; // fps
    private readonly SCAN_DURATION = 20000; // 20 seconds for better accuracy
    private readonly MIN_HR = 40;
    private readonly MAX_HR = 180;

    /**
     * Start the biosensor scan
     * Returns a promise that resolves with scan results after SCAN_DURATION
     */
    async startScan(onProgress?: (progress: number) => void): Promise<ScanResult> {
        // Reset buffers
        this.greenSignal = [];
        this.timestamps = [];

        // Create video element for camera feed
        this.video = document.createElement('video');
        this.video.setAttribute('playsinline', 'true');
        this.video.setAttribute('autoplay', 'true');
        this.video.muted = true;

        // Create canvas for frame analysis
        this.canvas = document.createElement('canvas');
        this.canvas.width = 320;
        this.canvas.height = 240;
        this.ctx = this.canvas.getContext('2d', { willReadFrequently: true });

        try {
            // Request front camera
            this.stream = await navigator.mediaDevices.getUserMedia({
                video: {
                    facingMode: 'user',
                    width: { ideal: 320 },
                    height: { ideal: 240 },
                    frameRate: { ideal: 30 }
                }
            });

            this.video.srcObject = this.stream;
            await this.video.play();
            this.isScanning = true;

            // Start sampling
            const startTime = Date.now();

            return new Promise((resolve) => {
                const sample = () => {
                    if (!this.isScanning) {
                        this.cleanup();
                        resolve(this.calculateResults());
                        return;
                    }

                    const elapsed = Date.now() - startTime;

                    if (elapsed >= this.SCAN_DURATION) {
                        this.isScanning = false;
                        this.cleanup();
                        resolve(this.calculateResults());
                        return;
                    }

                    // Report progress
                    if (onProgress) {
                        onProgress(elapsed / this.SCAN_DURATION);
                    }

                    // Extract green channel from face region
                    this.extractGreenSignal();

                    this.animationId = requestAnimationFrame(sample);
                };

                sample();
            });
        } catch (error) {
            this.cleanup();
            throw new Error('Camera access denied or unavailable');
        }
    }

    /**
     * Stop scanning early
     */
    stopScan(): void {
        this.isScanning = false;
    }

    /**
     * Extract average green channel intensity from face region
     * The forehead region provides cleaner signal
     */
    private extractGreenSignal(): void {
        if (!this.video || !this.ctx || !this.canvas) return;

        // Draw current frame
        this.ctx.drawImage(this.video, 0, 0, this.canvas.width, this.canvas.height);

        // Sample forehead region (center-top of frame)
        const roiX = this.canvas.width * 0.3;
        const roiY = this.canvas.height * 0.1;
        const roiW = this.canvas.width * 0.4;
        const roiH = this.canvas.height * 0.25;

        const imageData = this.ctx.getImageData(roiX, roiY, roiW, roiH);
        const data = imageData.data;

        // Calculate average green intensity
        let greenSum = 0;
        let pixelCount = 0;

        for (let i = 0; i < data.length; i += 4) {
            const r = data[i];
            const g = data[i + 1];
            const b = data[i + 2];

            // Simple skin detection (rough heuristic)
            if (r > 60 && g > 40 && b > 20 && r > b) {
                greenSum += g;
                pixelCount++;
            }
        }

        if (pixelCount > 100) {
            const avgGreen = greenSum / pixelCount;
            this.greenSignal.push(avgGreen);
            this.timestamps.push(Date.now());
        }
    }

    /**
     * Calculate heart rate, HRV, and stress from collected signal
     */
    private calculateResults(): ScanResult {
        if (this.greenSignal.length < 100) {
            // Not enough data
            return {
                heartRate: 0,
                hrv: 0,
                stressIndex: 50,
                confidence: 0,
                recommendation: 'moderate'
            };
        }

        // 1. Detrend and normalize signal
        const signal = this.detrendSignal(this.greenSignal);

        // 2. Apply bandpass filter (0.7-3Hz = 42-180 BPM)
        const filtered = this.bandpassFilter(signal);

        // 3. Find peaks (heartbeats)
        const peakIndices = this.findPeaks(filtered);

        // 4. Calculate heart rate from peak intervals
        const intervals = this.calculateIntervals(peakIndices);
        const heartRate = this.calculateHeartRate(intervals);

        // 5. Calculate HRV (RMSSD)
        const hrv = this.calculateHRV(intervals);

        // 6. Calculate stress index
        const stressIndex = this.calculateStressIndex(hrv, heartRate);

        // 7. Determine confidence
        const confidence = this.calculateConfidence(peakIndices.length, intervals);

        // 8. Get recommendation
        const recommendation = this.getRecommendation(stressIndex);

        return {
            heartRate: Math.round(heartRate),
            hrv: Math.round(hrv),
            stressIndex: Math.round(stressIndex),
            confidence,
            recommendation
        };
    }

    /**
     * Remove linear trend from signal
     */
    private detrendSignal(signal: number[]): number[] {
        const n = signal.length;
        const xMean = (n - 1) / 2;
        const yMean = signal.reduce((a, b) => a + b, 0) / n;

        let num = 0;
        let den = 0;
        for (let i = 0; i < n; i++) {
            num += (i - xMean) * (signal[i] - yMean);
            den += (i - xMean) ** 2;
        }
        const slope = num / den;
        const intercept = yMean - slope * xMean;

        return signal.map((y, i) => y - (slope * i + intercept));
    }

    /**
     * Simple moving average bandpass filter
     */
    private bandpassFilter(signal: number[]): number[] {
        // Low-pass at ~3Hz (for 30fps, window of ~10 samples)
        const lowPassed = this.movingAverage(signal, 3);

        // High-pass at ~0.7Hz (remove DC and slow drift)
        const highPassed = this.highPass(lowPassed, 0.7 / this.SAMPLE_RATE);

        return highPassed;
    }

    private movingAverage(signal: number[], windowSize: number): number[] {
        const result: number[] = [];
        for (let i = 0; i < signal.length; i++) {
            let sum = 0;
            let count = 0;
            for (let j = Math.max(0, i - windowSize); j <= Math.min(signal.length - 1, i + windowSize); j++) {
                sum += signal[j];
                count++;
            }
            result.push(sum / count);
        }
        return result;
    }

    private highPass(signal: number[], alpha: number): number[] {
        const result: number[] = [signal[0]];
        const rc = 1 / (2 * Math.PI * alpha);
        const dt = 1 / this.SAMPLE_RATE;
        const a = rc / (rc + dt);

        for (let i = 1; i < signal.length; i++) {
            result.push(a * (result[i - 1] + signal[i] - signal[i - 1]));
        }
        return result;
    }

    /**
     * Find peaks in signal using simple local maxima detection
     */
    private findPeaks(signal: number[]): number[] {
        const peaks: number[] = [];
        const minDistance = Math.floor(this.SAMPLE_RATE * 0.33); // At least 0.33s between beats (180 BPM max)

        // Calculate threshold (mean + 0.5 * std)
        const mean = signal.reduce((a, b) => a + b, 0) / signal.length;
        const std = Math.sqrt(signal.reduce((sum, x) => sum + (x - mean) ** 2, 0) / signal.length);
        const threshold = mean + 0.3 * std;

        let lastPeak = -minDistance;

        for (let i = 2; i < signal.length - 2; i++) {
            if (
                signal[i] > threshold &&
                signal[i] > signal[i - 1] &&
                signal[i] > signal[i - 2] &&
                signal[i] >= signal[i + 1] &&
                signal[i] >= signal[i + 2] &&
                i - lastPeak >= minDistance
            ) {
                peaks.push(i);
                lastPeak = i;
            }
        }

        return peaks;
    }

    /**
     * Calculate inter-beat intervals in milliseconds
     */
    private calculateIntervals(peakIndices: number[]): number[] {
        const intervals: number[] = [];
        for (let i = 1; i < peakIndices.length; i++) {
            const timeDiff = (peakIndices[i] - peakIndices[i - 1]) * (1000 / this.SAMPLE_RATE);
            // Only include physiologically plausible intervals (333ms to 1500ms = 40-180 BPM)
            if (timeDiff >= 333 && timeDiff <= 1500) {
                intervals.push(timeDiff);
            }
        }
        return intervals;
    }

    /**
     * Calculate heart rate from intervals
     */
    private calculateHeartRate(intervals: number[]): number {
        if (intervals.length === 0) return 0;
        const avgInterval = intervals.reduce((a, b) => a + b, 0) / intervals.length;
        const hr = 60000 / avgInterval;
        return Math.max(this.MIN_HR, Math.min(this.MAX_HR, hr));
    }

    /**
     * Calculate HRV using RMSSD (Root Mean Square of Successive Differences)
     */
    private calculateHRV(intervals: number[]): number {
        if (intervals.length < 3) return 40; // Default moderate HRV

        let sumSquaredDiff = 0;
        for (let i = 1; i < intervals.length; i++) {
            const diff = intervals[i] - intervals[i - 1];
            sumSquaredDiff += diff * diff;
        }

        return Math.sqrt(sumSquaredDiff / (intervals.length - 1));
    }

    /**
     * Calculate stress index from HRV and heart rate
     * Lower HRV and higher HR = higher stress
     */
    private calculateStressIndex(hrv: number, heartRate: number): number {
        // Normalize HRV (inverse relationship)
        // HRV > 50ms = low stress, < 20ms = high stress
        const hrvFactor = Math.max(0, Math.min(100, (60 - hrv) * 2));

        // Normalize heart rate
        // HR < 65 = low stress, > 90 = high stress
        const hrFactor = Math.max(0, Math.min(100, (heartRate - 55) * 2));

        // Combined stress index (weighted average)
        const stress = hrvFactor * 0.6 + hrFactor * 0.4;

        return Math.max(0, Math.min(100, stress));
    }

    /**
     * Calculate signal confidence
     */
    private calculateConfidence(peakCount: number, intervals: number[]): number {
        // Expected peaks for 10 seconds at 60-80 BPM = 10-13 peaks
        const expectedPeaks = 12;
        const peakConfidence = Math.min(1, peakCount / expectedPeaks);

        // Interval regularity (low variance = high confidence)
        if (intervals.length < 3) return 0.3;

        const mean = intervals.reduce((a, b) => a + b, 0) / intervals.length;
        const variance = intervals.reduce((sum, x) => sum + (x - mean) ** 2, 0) / intervals.length;
        const cv = Math.sqrt(variance) / mean; // Coefficient of variation
        const regularityConfidence = Math.max(0, 1 - cv * 2);

        return (peakConfidence * 0.4 + regularityConfidence * 0.6);
    }

    /**
     * Get recommendation based on stress level
     */
    private getRecommendation(stressIndex: number): 'low' | 'moderate' | 'high' {
        if (stressIndex < 35) return 'low';
        if (stressIndex < 65) return 'moderate';
        return 'high';
    }

    /**
     * Cleanup resources
     */
    private cleanup(): void {
        if (this.animationId) {
            cancelAnimationFrame(this.animationId);
            this.animationId = null;
        }

        if (this.stream) {
            this.stream.getTracks().forEach(track => track.stop());
            this.stream = null;
        }

        if (this.video) {
            this.video.srcObject = null;
            this.video = null;
        }

        this.canvas = null;
        this.ctx = null;
    }

    /**
     * Get protocol configuration based on stress level
     */
    getProtocolForStress(stressIndex: number): {
        brainwavePosition: number;
        durationMinutes: number;
        message: string;
    } {
        if (stressIndex >= 65) {
            return {
                brainwavePosition: 0.1, // Delta - deep relaxation
                durationMinutes: 6,
                message: "High sympathetic activity detected. Deploying 6-minute down-regulation protocol."
            };
        } else if (stressIndex >= 35) {
            return {
                brainwavePosition: 0.25, // Theta - calm
                durationMinutes: 5,
                message: "Moderate stress levels. Beginning 5-minute calming session."
            };
        } else {
            return {
                brainwavePosition: 0.5, // Alpha - flow
                durationMinutes: 5,
                message: "Balanced state detected. Optimizing for focus and flow."
            };
        }
    }
}

// Singleton instance
export const rppgEngine = new RPPGEngine();
