/**
 * Zyndio Space - Audio Engine
 * Real-time audio synthesis using Web Audio API
 * No MP3 files - all generated in real-time
 */

export type AudioMode = 'void' | 'flow' | 'focus';
export type FlowVariant = 'brown' | 'pink' | 'rain';
export type FocusVariant = 'theta' | 'alpha';

class AudioEngine {
    private context: AudioContext | null = null;
    private masterGain: GainNode | null = null;
    private noiseNode: AudioBufferSourceNode | null = null;
    private binauralLeft: OscillatorNode | null = null;
    private binauralRight: OscillatorNode | null = null;
    private pannerLeft: StereoPannerNode | null = null;
    private pannerRight: StereoPannerNode | null = null;
    private filterNode: BiquadFilterNode | null = null;
    private isPlaying = false;
    private currentMode: AudioMode = 'void';
    private currentFlowVariant: FlowVariant = 'brown';
    private currentFocusVariant: FocusVariant = 'theta';

    // DeepSync - Independent binaural beat system for thought reduction
    private deepSyncLeft: OscillatorNode | null = null;
    private deepSyncRight: OscillatorNode | null = null;
    private deepSyncPannerLeft: StereoPannerNode | null = null;
    private deepSyncPannerRight: StereoPannerNode | null = null;
    private deepSyncGain: GainNode | null = null;
    private isDeepSyncPlaying = false;

    // Binaural Architecture - Adaptive brainwave control system
    private archNoiseNode: AudioBufferSourceNode | null = null;
    private archNoiseGain: GainNode | null = null;
    private archNoiseFilter: BiquadFilterNode | null = null;
    private archBinauralLeft: OscillatorNode | null = null;
    private archBinauralRight: OscillatorNode | null = null;
    private archBinauralGain: GainNode | null = null;
    private archPannerLeft: StereoPannerNode | null = null;
    private archPannerRight: StereoPannerNode | null = null;
    private isArchitecturePlaying = false;
    private currentBrainwaveTarget = 0.5; // 0 = delta, 1 = gamma

    // Neutralize Mode - Emergency calming system (brown noise + theta binaural)
    private neutralizeNoiseNode: AudioBufferSourceNode | null = null;
    private neutralizeNoiseGain: GainNode | null = null;
    private neutralizeNoiseFilter: BiquadFilterNode | null = null;
    private neutralizeBinauralLeft: OscillatorNode | null = null;
    private neutralizeBinauralRight: OscillatorNode | null = null;
    private neutralizeBinauralGain: GainNode | null = null;
    private neutralizePannerLeft: StereoPannerNode | null = null;
    private neutralizePannerRight: StereoPannerNode | null = null;
    private isNeutralizePlaying = false;

    /**
     * Initialize AudioContext (must be called after user interaction)
     */
    async init(): Promise<void> {
        if (this.context) return;

        this.context = new AudioContext();
        this.masterGain = this.context.createGain();
        this.masterGain.gain.value = 0;
        this.masterGain.connect(this.context.destination);

        // Resume context if suspended (iOS requirement)
        if (this.context.state === 'suspended') {
            await this.context.resume();
        }
    }

    /**
     * Start audio with the specified mode
     */
    async start(mode: AudioMode, variant?: FlowVariant | FocusVariant): Promise<void> {
        await this.init();
        if (!this.context || !this.masterGain) return;

        this.stopNodes();
        this.currentMode = mode;

        if (mode === 'flow') {
            this.currentFlowVariant = (variant as FlowVariant) || 'brown';
            await this.startFlow(this.currentFlowVariant);
        } else if (mode === 'focus') {
            this.currentFocusVariant = (variant as FocusVariant) || 'theta';
            await this.startFocus(this.currentFocusVariant);
        }
        // 'void' mode = silence, nothing to start

        // Fade in
        this.masterGain.gain.cancelScheduledValues(this.context.currentTime);
        this.masterGain.gain.setValueAtTime(0, this.context.currentTime);
        this.masterGain.gain.linearRampToValueAtTime(0.5, this.context.currentTime + 2);

        this.isPlaying = true;
    }

    /**
     * Generate noise for Flow mode (Brown, Pink, Rain)
     */
    private async startFlow(variant: FlowVariant): Promise<void> {
        if (!this.context || !this.masterGain) return;

        // Create noise buffer
        const bufferSize = 2 * this.context.sampleRate;
        const buffer = this.context.createBuffer(2, bufferSize, this.context.sampleRate);

        for (let channel = 0; channel < 2; channel++) {
            const data = buffer.getChannelData(channel);

            if (variant === 'brown') {
                // Brown noise: integrated white noise
                let lastOut = 0;
                for (let i = 0; i < bufferSize; i++) {
                    const white = Math.random() * 2 - 1;
                    lastOut = (lastOut + (0.02 * white)) / 1.02;
                    data[i] = lastOut * 3.5; // Normalize
                }
            } else if (variant === 'pink') {
                // Pink noise: 1/f noise approximation using Voss algorithm
                let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
                for (let i = 0; i < bufferSize; i++) {
                    const white = Math.random() * 2 - 1;
                    b0 = 0.99886 * b0 + white * 0.0555179;
                    b1 = 0.99332 * b1 + white * 0.0750759;
                    b2 = 0.96900 * b2 + white * 0.1538520;
                    b3 = 0.86650 * b3 + white * 0.3104856;
                    b4 = 0.55000 * b4 + white * 0.5329522;
                    b5 = -0.7616 * b5 - white * 0.0168980;
                    data[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11;
                    b6 = white * 0.115926;
                }
            } else if (variant === 'rain') {
                // Rain: filtered white noise with random amplitude modulation
                let lastOut = 0;
                for (let i = 0; i < bufferSize; i++) {
                    const white = Math.random() * 2 - 1;
                    // Low-pass filter for rain-like quality
                    lastOut = lastOut * 0.85 + white * 0.15;
                    // Random drops
                    const drop = Math.random() < 0.0002 ? (Math.random() * 0.3) : 0;
                    data[i] = (lastOut * 0.5) + drop;
                }
            }
        }

        this.noiseNode = this.context.createBufferSource();
        this.noiseNode.buffer = buffer;
        this.noiseNode.loop = true;

        // Add filter for warmer sound
        this.filterNode = this.context.createBiquadFilter();
        this.filterNode.type = 'lowpass';
        this.filterNode.frequency.value = variant === 'rain' ? 3000 : 1500;
        this.filterNode.Q.value = 0.7;

        this.noiseNode.connect(this.filterNode);
        this.filterNode.connect(this.masterGain);
        this.noiseNode.start();
    }

    /**
     * Generate binaural beats for Focus mode
     * Requires headphones - each ear gets a slightly different frequency
     * Brain perceives the difference as the target brainwave frequency
     */
    private async startFocus(variant: FocusVariant): Promise<void> {
        if (!this.context || !this.masterGain) return;

        // Base carrier frequency
        const baseFreq = 200;

        // Beat frequency (the difference the brain perceives)
        // Theta: 6Hz (deep meditation), Alpha: 10Hz (relaxation)
        const beatFreq = variant === 'theta' ? 6 : 10;

        // Left ear oscillator
        this.binauralLeft = this.context.createOscillator();
        this.binauralLeft.type = 'sine';
        this.binauralLeft.frequency.value = baseFreq;

        // Right ear oscillator (slightly higher frequency)
        this.binauralRight = this.context.createOscillator();
        this.binauralRight.type = 'sine';
        this.binauralRight.frequency.value = baseFreq + beatFreq;

        // Hard pan to separate ears
        this.pannerLeft = this.context.createStereoPanner();
        this.pannerRight = this.context.createStereoPanner();
        this.pannerLeft.pan.value = -1;
        this.pannerRight.pan.value = 1;

        // Connect with gentle volume
        const gainNode = this.context.createGain();
        gainNode.gain.value = 0.3;

        this.binauralLeft.connect(this.pannerLeft);
        this.binauralRight.connect(this.pannerRight);
        this.pannerLeft.connect(gainNode);
        this.pannerRight.connect(gainNode);
        gainNode.connect(this.masterGain);

        // Start
        this.binauralLeft.start();
        this.binauralRight.start();
    }

    /**
     * Execute the Smart Fade - 60 second non-linear fade out
     */
    async smartFade(): Promise<void> {
        if (!this.context || !this.masterGain || !this.isPlaying) return;

        const now = this.context.currentTime;
        const fadeDuration = 60;

        // Non-linear fade curve: stay louder longer, then quick fade at end
        this.masterGain.gain.cancelScheduledValues(now);
        this.masterGain.gain.setValueAtTime(this.masterGain.gain.value, now);

        // Custom exponential curve for gentle awakening
        const steps = 12;
        for (let i = 1; i <= steps; i++) {
            const t = i / steps;
            // Ease-in-out curve: slow start, slow end
            const curve = t < 0.5
                ? 4 * t * t * t
                : 1 - Math.pow(-2 * t + 2, 3) / 2;
            const volume = 0.5 * (1 - curve);
            this.masterGain.gain.linearRampToValueAtTime(
                Math.max(0, volume),
                now + (fadeDuration * t)
            );
        }

        // Schedule stop
        setTimeout(() => this.stop(), fadeDuration * 1000);
    }

    /**
     * Stop all audio immediately
     */
    stop(): void {
        this.stopNodes();

        if (this.masterGain && this.context) {
            this.masterGain.gain.cancelScheduledValues(this.context.currentTime);
            this.masterGain.gain.setValueAtTime(0, this.context.currentTime);
        }

        this.isPlaying = false;
    }

    /**
     * Stop and disconnect all audio nodes
     */
    private stopNodes(): void {
        try {
            if (this.noiseNode) {
                this.noiseNode.stop();
                this.noiseNode.disconnect();
                this.noiseNode = null;
            }
            if (this.binauralLeft) {
                this.binauralLeft.stop();
                this.binauralLeft.disconnect();
                this.binauralLeft = null;
            }
            if (this.binauralRight) {
                this.binauralRight.stop();
                this.binauralRight.disconnect();
                this.binauralRight = null;
            }
            if (this.filterNode) {
                this.filterNode.disconnect();
                this.filterNode = null;
            }
            if (this.pannerLeft) {
                this.pannerLeft.disconnect();
                this.pannerLeft = null;
            }
            if (this.pannerRight) {
                this.pannerRight.disconnect();
                this.pannerRight = null;
            }
        } catch (e) {
            // Nodes may already be stopped
        }
    }

    /**
     * Get volume for external monitoring
     */
    getVolume(): number {
        return this.masterGain?.gain.value || 0;
    }

    /**
     * Check if audio is currently playing
     */
    getIsPlaying(): boolean {
        return this.isPlaying;
    }

    /**
     * Get current mode
     */
    getMode(): AudioMode {
        return this.currentMode;
    }

    /**
     * Start DeepSync - Independent theta binaural beats for thought reduction
     * Creates a 6Hz theta wave to help quiet mental chatter
     * Requires stereo headphones for full effect
     * 
     * SAFE LISTENING PARAMETERS:
     * - Carrier frequency: 250Hz (gentler on ears than 200Hz)
     * - Beat frequency: 6Hz (theta range for deep meditation)
     * - Volume: 0.05 (very low - binaural beats work subliminally)
     * - Gentle amplitude modulation to reduce listener fatigue
     * 
     * Scientific basis:
     * - 250Hz carrier is within comfortable range (200-500Hz recommended)
     * - 6Hz theta is associated with deep relaxation and meditation
     * - Low volume prevents ear fatigue during extended sessions
     */
    async startDeepSync(): Promise<void> {
        await this.init();
        if (!this.context || this.isDeepSyncPlaying) return;

        // Carrier frequency - 250Hz is comfortable for extended listening
        // (200Hz can feel "heavy", 300Hz+ can feel "sharp")
        const baseFreq = 250;

        // Theta beat frequency (6Hz - deep meditation, reduced mental chatter)
        // This is the difference the brain perceives between left and right ears
        const beatFreq = 6;

        // SAFE VOLUME: 0.05 is very quiet - binaural beats work best at low volume
        // High volume causes ear fatigue and is not necessary for the effect
        const safeVolume = 0.05;

        // Create dedicated gain node for DeepSync (independent from main audio)
        this.deepSyncGain = this.context.createGain();
        this.deepSyncGain.gain.value = 0;
        this.deepSyncGain.connect(this.context.destination);

        // Left ear oscillator
        this.deepSyncLeft = this.context.createOscillator();
        this.deepSyncLeft.type = 'sine';
        this.deepSyncLeft.frequency.value = baseFreq;

        // Right ear oscillator (slightly higher = creates the binaural beat)
        this.deepSyncRight = this.context.createOscillator();
        this.deepSyncRight.type = 'sine';
        this.deepSyncRight.frequency.value = baseFreq + beatFreq;

        // Hard pan to separate ears (critical for binaural effect)
        this.deepSyncPannerLeft = this.context.createStereoPanner();
        this.deepSyncPannerRight = this.context.createStereoPanner();
        this.deepSyncPannerLeft.pan.value = -1;
        this.deepSyncPannerRight.pan.value = 1;

        // Add subtle amplitude modulation to reduce ear fatigue
        // This creates a gentle "breathing" effect that's easier on ears
        const lfo = this.context.createOscillator();
        const lfoGain = this.context.createGain();
        lfo.type = 'sine';
        lfo.frequency.value = 0.1; // Very slow modulation (1 cycle per 10 seconds)
        lfoGain.gain.value = 0.015; // Subtle 30% variation in volume
        lfo.connect(lfoGain);
        lfoGain.connect(this.deepSyncGain.gain);
        lfo.start();

        // Connect the audio graph
        this.deepSyncLeft.connect(this.deepSyncPannerLeft);
        this.deepSyncRight.connect(this.deepSyncPannerRight);
        this.deepSyncPannerLeft.connect(this.deepSyncGain);
        this.deepSyncPannerRight.connect(this.deepSyncGain);

        // Start oscillators
        this.deepSyncLeft.start();
        this.deepSyncRight.start();

        // Gentle fade in over 3 seconds (slower = more comfortable)
        this.deepSyncGain.gain.setValueAtTime(0, this.context.currentTime);
        this.deepSyncGain.gain.linearRampToValueAtTime(safeVolume, this.context.currentTime + 3);

        this.isDeepSyncPlaying = true;
    }

    /**
     * Stop DeepSync with gentle fade out
     */
    async stopDeepSync(): Promise<void> {
        if (!this.context || !this.isDeepSyncPlaying || !this.deepSyncGain) return;

        const now = this.context.currentTime;

        // Fade out over 1.5 seconds
        this.deepSyncGain.gain.cancelScheduledValues(now);
        this.deepSyncGain.gain.setValueAtTime(this.deepSyncGain.gain.value, now);
        this.deepSyncGain.gain.linearRampToValueAtTime(0, now + 1.5);

        // Stop and cleanup after fade completes
        setTimeout(() => {
            try {
                if (this.deepSyncLeft) {
                    this.deepSyncLeft.stop();
                    this.deepSyncLeft.disconnect();
                    this.deepSyncLeft = null;
                }
                if (this.deepSyncRight) {
                    this.deepSyncRight.stop();
                    this.deepSyncRight.disconnect();
                    this.deepSyncRight = null;
                }
                if (this.deepSyncPannerLeft) {
                    this.deepSyncPannerLeft.disconnect();
                    this.deepSyncPannerLeft = null;
                }
                if (this.deepSyncPannerRight) {
                    this.deepSyncPannerRight.disconnect();
                    this.deepSyncPannerRight = null;
                }
                if (this.deepSyncGain) {
                    this.deepSyncGain.disconnect();
                    this.deepSyncGain = null;
                }
            } catch (e) {
                // Nodes may already be stopped
            }
        }, 1600);

        this.isDeepSyncPlaying = false;
    }

    /**
     * Check if DeepSync is currently active
     */
    isDeepSyncActive(): boolean {
        return this.isDeepSyncPlaying;
    }

    /**
     * Play a gentle meditation bell/chime for session completion
     * Synthesizes a realistic bell sound using harmonics
     */
    async playCompletionChime(): Promise<void> {
        await this.init();
        if (!this.context) return;

        const now = this.context.currentTime;

        // Create a gentle bell-like tone using multiple harmonics
        const fundamentalFreq = 528; // Hz - "healing" frequency
        const harmonics = [1, 2, 3, 4.2, 5.4]; // Bell-like harmonic series
        const volumes = [0.5, 0.3, 0.2, 0.1, 0.05];

        harmonics.forEach((harmonic, i) => {
            const oscillator = this.context!.createOscillator();
            const gainNode = this.context!.createGain();

            oscillator.type = 'sine';
            oscillator.frequency.value = fundamentalFreq * harmonic;

            // Bell-like envelope: quick attack, long decay
            gainNode.gain.setValueAtTime(0, now);
            gainNode.gain.linearRampToValueAtTime(volumes[i] * 0.3, now + 0.01);
            gainNode.gain.exponentialRampToValueAtTime(0.001, now + 3 + i * 0.5);

            oscillator.connect(gainNode);
            gainNode.connect(this.context!.destination);

            oscillator.start(now);
            oscillator.stop(now + 4 + i * 0.5);
        });

        // Add a second, softer chime slightly delayed
        setTimeout(() => {
            if (!this.context) return;
            const now2 = this.context.currentTime;

            const osc = this.context.createOscillator();
            const gain = this.context.createGain();

            osc.type = 'sine';
            osc.frequency.value = 396; // Slightly lower for richness

            gain.gain.setValueAtTime(0, now2);
            gain.gain.linearRampToValueAtTime(0.15, now2 + 0.01);
            gain.gain.exponentialRampToValueAtTime(0.001, now2 + 2.5);

            osc.connect(gain);
            gain.connect(this.context.destination);

            osc.start(now2);
            osc.stop(now2 + 3);
        }, 800);
    }

    // ==========================================
    // BINAURAL ARCHITECTURE - Adaptive Brain Control
    // ==========================================

    /**
     * Map slider position (0-1) to brainwave frequency
     * 0 = Delta (2Hz) - deep relaxation
     * 0.25 = Theta (6Hz) - meditation
     * 0.5 = Alpha (10Hz) - calm focus
     * 0.75 = Beta (20Hz) - alertness
     * 1 = Gamma (40Hz) - peak concentration
     */
    private positionToFrequency(position: number): number {
        // Non-linear mapping for more usable range in the middle
        const clampedPos = Math.max(0, Math.min(1, position));

        if (clampedPos <= 0.25) {
            // Delta to Theta (2-6 Hz)
            return 2 + (clampedPos / 0.25) * 4;
        } else if (clampedPos <= 0.5) {
            // Theta to Alpha (6-10 Hz)
            return 6 + ((clampedPos - 0.25) / 0.25) * 4;
        } else if (clampedPos <= 0.75) {
            // Alpha to Beta (10-20 Hz)
            return 10 + ((clampedPos - 0.5) / 0.25) * 10;
        } else {
            // Beta to Gamma (20-40 Hz)
            return 20 + ((clampedPos - 0.75) / 0.25) * 20;
        }
    }

    /**
     * Start the Binaural Architecture - adaptive brainwave control
     * Combines pink noise for comfort with real-time adjustable binaural beats
     */
    async startBinauralArchitecture(): Promise<void> {
        await this.init();
        if (!this.context || this.isArchitecturePlaying) return;

        // === LAYER 1: Pink Noise Base ===
        // Pink noise is comfortable for extended listening and masks tinnitus
        const bufferSize = 2 * this.context.sampleRate;
        const buffer = this.context.createBuffer(2, bufferSize, this.context.sampleRate);

        for (let channel = 0; channel < 2; channel++) {
            const data = buffer.getChannelData(channel);
            let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
            for (let i = 0; i < bufferSize; i++) {
                const white = Math.random() * 2 - 1;
                b0 = 0.99886 * b0 + white * 0.0555179;
                b1 = 0.99332 * b1 + white * 0.0750759;
                b2 = 0.96900 * b2 + white * 0.1538520;
                b3 = 0.86650 * b3 + white * 0.3104856;
                b4 = 0.55000 * b4 + white * 0.5329522;
                b5 = -0.7616 * b5 - white * 0.0168980;
                data[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11;
                b6 = white * 0.115926;
            }
        }

        this.archNoiseNode = this.context.createBufferSource();
        this.archNoiseNode.buffer = buffer;
        this.archNoiseNode.loop = true;

        // Low-pass filter to make it warmer
        this.archNoiseFilter = this.context.createBiquadFilter();
        this.archNoiseFilter.type = 'lowpass';
        this.archNoiseFilter.frequency.value = 800;
        this.archNoiseFilter.Q.value = 0.5;

        this.archNoiseGain = this.context.createGain();
        this.archNoiseGain.gain.value = 0;

        this.archNoiseNode.connect(this.archNoiseFilter);
        this.archNoiseFilter.connect(this.archNoiseGain);
        this.archNoiseGain.connect(this.context.destination);
        this.archNoiseNode.start();

        // === LAYER 2: Adaptive Binaural Beats ===
        const baseFreq = 250; // Comfortable carrier
        const initialBeatFreq = this.positionToFrequency(this.currentBrainwaveTarget);

        this.archBinauralLeft = this.context.createOscillator();
        this.archBinauralLeft.type = 'sine';
        this.archBinauralLeft.frequency.value = baseFreq;

        this.archBinauralRight = this.context.createOscillator();
        this.archBinauralRight.type = 'sine';
        this.archBinauralRight.frequency.value = baseFreq + initialBeatFreq;

        this.archPannerLeft = this.context.createStereoPanner();
        this.archPannerRight = this.context.createStereoPanner();
        this.archPannerLeft.pan.value = -1;
        this.archPannerRight.pan.value = 1;

        this.archBinauralGain = this.context.createGain();
        this.archBinauralGain.gain.value = 0;

        this.archBinauralLeft.connect(this.archPannerLeft);
        this.archBinauralRight.connect(this.archPannerRight);
        this.archPannerLeft.connect(this.archBinauralGain);
        this.archPannerRight.connect(this.archBinauralGain);
        this.archBinauralGain.connect(this.context.destination);

        this.archBinauralLeft.start();
        this.archBinauralRight.start();

        // Fade in both layers
        const now = this.context.currentTime;
        this.archNoiseGain.gain.setValueAtTime(0, now);
        this.archNoiseGain.gain.linearRampToValueAtTime(0.15, now + 2);
        this.archBinauralGain.gain.setValueAtTime(0, now);
        this.archBinauralGain.gain.linearRampToValueAtTime(0.04, now + 2);

        this.isArchitecturePlaying = true;
    }

    /**
     * Set brainwave target - smoothly morphs the binaural frequency
     * @param position - 0 (delta/relaxation) to 1 (gamma/alertness)
     */
    setBrainwaveTarget(position: number): void {
        if (!this.context || !this.archBinauralRight || !this.isArchitecturePlaying) return;

        this.currentBrainwaveTarget = Math.max(0, Math.min(1, position));
        const targetFreq = this.positionToFrequency(this.currentBrainwaveTarget);
        const baseFreq = 250;

        // Smooth transition over 300ms for fluid feel
        const now = this.context.currentTime;
        this.archBinauralRight.frequency.cancelScheduledValues(now);
        this.archBinauralRight.frequency.setValueAtTime(
            this.archBinauralRight.frequency.value,
            now
        );
        this.archBinauralRight.frequency.linearRampToValueAtTime(
            baseFreq + targetFreq,
            now + 0.3
        );

        // Also adjust noise filter based on position (higher = brighter)
        if (this.archNoiseFilter) {
            const filterFreq = 600 + position * 800; // 600Hz to 1400Hz
            this.archNoiseFilter.frequency.cancelScheduledValues(now);
            this.archNoiseFilter.frequency.setValueAtTime(
                this.archNoiseFilter.frequency.value,
                now
            );
            this.archNoiseFilter.frequency.linearRampToValueAtTime(filterFreq, now + 0.3);
        }
    }

    /**
     * Get current brainwave position
     */
    getBrainwaveTarget(): number {
        return this.currentBrainwaveTarget;
    }

    /**
     * Check if Binaural Architecture is playing
     */
    isArchitectureActive(): boolean {
        return this.isArchitecturePlaying;
    }

    /**
     * Stop Binaural Architecture with fade out
     */
    async stopBinauralArchitecture(): Promise<void> {
        if (!this.context || !this.isArchitecturePlaying) return;

        const now = this.context.currentTime;

        // Fade out both layers
        if (this.archNoiseGain) {
            this.archNoiseGain.gain.cancelScheduledValues(now);
            this.archNoiseGain.gain.setValueAtTime(this.archNoiseGain.gain.value, now);
            this.archNoiseGain.gain.linearRampToValueAtTime(0, now + 1.5);
        }
        if (this.archBinauralGain) {
            this.archBinauralGain.gain.cancelScheduledValues(now);
            this.archBinauralGain.gain.setValueAtTime(this.archBinauralGain.gain.value, now);
            this.archBinauralGain.gain.linearRampToValueAtTime(0, now + 1.5);
        }

        // Cleanup after fade
        setTimeout(() => {
            try {
                if (this.archNoiseNode) {
                    this.archNoiseNode.stop();
                    this.archNoiseNode.disconnect();
                    this.archNoiseNode = null;
                }
                if (this.archBinauralLeft) {
                    this.archBinauralLeft.stop();
                    this.archBinauralLeft.disconnect();
                    this.archBinauralLeft = null;
                }
                if (this.archBinauralRight) {
                    this.archBinauralRight.stop();
                    this.archBinauralRight.disconnect();
                    this.archBinauralRight = null;
                }
                if (this.archNoiseFilter) {
                    this.archNoiseFilter.disconnect();
                    this.archNoiseFilter = null;
                }
                if (this.archNoiseGain) {
                    this.archNoiseGain.disconnect();
                    this.archNoiseGain = null;
                }
                if (this.archBinauralGain) {
                    this.archBinauralGain.disconnect();
                    this.archBinauralGain = null;
                }
                if (this.archPannerLeft) {
                    this.archPannerLeft.disconnect();
                    this.archPannerLeft = null;
                }
                if (this.archPannerRight) {
                    this.archPannerRight.disconnect();
                    this.archPannerRight = null;
                }
            } catch (e) {
                // Nodes may already be stopped
            }
        }, 1600);

        this.isArchitecturePlaying = false;
    }

    // ==========================================
    // NEUTRALIZE MODE - Emergency Calming System
    // ==========================================

    /**
     * Start Neutralize Mode - combines brown noise (grounding) with theta binaural (6Hz)
     * Designed for immediate calming during urges or anxiety spikes
     */
    async startNeutralizeMode(): Promise<void> {
        await this.init();
        if (!this.context || this.isNeutralizePlaying) return;

        // Stop any conflicting audio systems
        if (this.isDeepSyncPlaying) {
            await this.stopDeepSync();
        }
        if (this.isArchitecturePlaying) {
            await this.stopBinauralArchitecture();
        }

        // === LAYER 1: Brown Noise (Grounding) ===
        const bufferSize = 2 * this.context.sampleRate;
        const buffer = this.context.createBuffer(2, bufferSize, this.context.sampleRate);

        for (let channel = 0; channel < 2; channel++) {
            const data = buffer.getChannelData(channel);
            let lastOut = 0;
            for (let i = 0; i < bufferSize; i++) {
                const white = Math.random() * 2 - 1;
                lastOut = (lastOut + (0.02 * white)) / 1.02;
                data[i] = lastOut * 3.5;
            }
        }

        this.neutralizeNoiseNode = this.context.createBufferSource();
        this.neutralizeNoiseNode.buffer = buffer;
        this.neutralizeNoiseNode.loop = true;

        // Warm low-pass filter
        this.neutralizeNoiseFilter = this.context.createBiquadFilter();
        this.neutralizeNoiseFilter.type = 'lowpass';
        this.neutralizeNoiseFilter.frequency.value = 400; // Very warm, womb-like
        this.neutralizeNoiseFilter.Q.value = 0.5;

        this.neutralizeNoiseGain = this.context.createGain();
        this.neutralizeNoiseGain.gain.value = 0;

        this.neutralizeNoiseNode.connect(this.neutralizeNoiseFilter);
        this.neutralizeNoiseFilter.connect(this.neutralizeNoiseGain);
        this.neutralizeNoiseGain.connect(this.context.destination);
        this.neutralizeNoiseNode.start();

        // === LAYER 2: Theta Binaural Beats (6Hz - Deep Calm) ===
        const baseFreq = 200; // Lower carrier for deeper feel
        const beatFreq = 6;   // Theta range

        this.neutralizeBinauralLeft = this.context.createOscillator();
        this.neutralizeBinauralLeft.type = 'sine';
        this.neutralizeBinauralLeft.frequency.value = baseFreq;

        this.neutralizeBinauralRight = this.context.createOscillator();
        this.neutralizeBinauralRight.type = 'sine';
        this.neutralizeBinauralRight.frequency.value = baseFreq + beatFreq;

        this.neutralizePannerLeft = this.context.createStereoPanner();
        this.neutralizePannerRight = this.context.createStereoPanner();
        this.neutralizePannerLeft.pan.value = -1;
        this.neutralizePannerRight.pan.value = 1;

        this.neutralizeBinauralGain = this.context.createGain();
        this.neutralizeBinauralGain.gain.value = 0;

        this.neutralizeBinauralLeft.connect(this.neutralizePannerLeft);
        this.neutralizeBinauralRight.connect(this.neutralizePannerRight);
        this.neutralizePannerLeft.connect(this.neutralizeBinauralGain);
        this.neutralizePannerRight.connect(this.neutralizeBinauralGain);
        this.neutralizeBinauralGain.connect(this.context.destination);

        this.neutralizeBinauralLeft.start();
        this.neutralizeBinauralRight.start();

        // Fade in both layers gently over 2 seconds
        const now = this.context.currentTime;
        this.neutralizeNoiseGain.gain.setValueAtTime(0, now);
        this.neutralizeNoiseGain.gain.linearRampToValueAtTime(0.25, now + 2);
        this.neutralizeBinauralGain.gain.setValueAtTime(0, now);
        this.neutralizeBinauralGain.gain.linearRampToValueAtTime(0.06, now + 2);

        this.isNeutralizePlaying = true;
    }

    /**
     * Stop Neutralize Mode with gentle fade out
     */
    async stopNeutralizeMode(): Promise<void> {
        if (!this.context || !this.isNeutralizePlaying) return;

        const now = this.context.currentTime;

        // Fade out both layers
        if (this.neutralizeNoiseGain) {
            this.neutralizeNoiseGain.gain.cancelScheduledValues(now);
            this.neutralizeNoiseGain.gain.setValueAtTime(this.neutralizeNoiseGain.gain.value, now);
            this.neutralizeNoiseGain.gain.linearRampToValueAtTime(0, now + 1.5);
        }
        if (this.neutralizeBinauralGain) {
            this.neutralizeBinauralGain.gain.cancelScheduledValues(now);
            this.neutralizeBinauralGain.gain.setValueAtTime(this.neutralizeBinauralGain.gain.value, now);
            this.neutralizeBinauralGain.gain.linearRampToValueAtTime(0, now + 1.5);
        }

        // Cleanup after fade
        setTimeout(() => {
            try {
                if (this.neutralizeNoiseNode) {
                    this.neutralizeNoiseNode.stop();
                    this.neutralizeNoiseNode.disconnect();
                    this.neutralizeNoiseNode = null;
                }
                if (this.neutralizeBinauralLeft) {
                    this.neutralizeBinauralLeft.stop();
                    this.neutralizeBinauralLeft.disconnect();
                    this.neutralizeBinauralLeft = null;
                }
                if (this.neutralizeBinauralRight) {
                    this.neutralizeBinauralRight.stop();
                    this.neutralizeBinauralRight.disconnect();
                    this.neutralizeBinauralRight = null;
                }
                if (this.neutralizeNoiseFilter) {
                    this.neutralizeNoiseFilter.disconnect();
                    this.neutralizeNoiseFilter = null;
                }
                if (this.neutralizeNoiseGain) {
                    this.neutralizeNoiseGain.disconnect();
                    this.neutralizeNoiseGain = null;
                }
                if (this.neutralizeBinauralGain) {
                    this.neutralizeBinauralGain.disconnect();
                    this.neutralizeBinauralGain = null;
                }
                if (this.neutralizePannerLeft) {
                    this.neutralizePannerLeft.disconnect();
                    this.neutralizePannerLeft = null;
                }
                if (this.neutralizePannerRight) {
                    this.neutralizePannerRight.disconnect();
                    this.neutralizePannerRight = null;
                }
            } catch (e) {
                // Nodes may already be stopped
            }
        }, 1600);

        this.isNeutralizePlaying = false;
    }

    /**
     * Check if Neutralize Mode is active
     */
    isNeutralizeActive(): boolean {
        return this.isNeutralizePlaying;
    }
}

// Singleton instance
export const audioEngine = new AudioEngine();
