/**
 * Habit Sync Hook - Syncs habits between localStorage and Supabase
 */

import { useCallback, useRef } from 'react';
import { supabase } from '../lib/supabase';
import type { User } from '@supabase/supabase-js';

interface HabitData {
    todayMinutes: number;
    currentStreak: number;
    lifetimeMinutes: number;
    weeklyMinutes: number;
    dailyGoal: number;
    history: { date: string; minutes: number }[];
}

interface SyncResult {
    syncToCloud: (data: HabitData, mode?: string) => Promise<void>;
    loadFromCloud: () => Promise<HabitData | null>;
    syncPreferences: (spaceTheme: boolean, dailyGoal: number) => Promise<void>;
}

export function useHabitSync(user: User | null): SyncResult {
    const lastSyncRef = useRef<number>(0);

    // Sync session to Supabase
    const syncToCloud = useCallback(async (data: HabitData, mode?: string) => {
        if (!user) return;

        // Rate limit syncs (max once per 5 seconds)
        const now = Date.now();
        if (now - lastSyncRef.current < 5000) return;
        lastSyncRef.current = now;

        try {
            // Get today's date
            const today = new Date().toISOString().split('T')[0];

            // Check if we already have a session for today
            const { data: existing } = await supabase
                .from('meditation_sessions')
                .select('minutes')
                .eq('user_id', user.id)
                .eq('date', today)
                .single();

            if (existing) {
                // Update existing session
                await supabase
                    .from('meditation_sessions')
                    .update({ minutes: data.todayMinutes, mode: mode || 'void' })
                    .eq('user_id', user.id)
                    .eq('date', today);
            } else {
                // Insert new session
                await supabase
                    .from('meditation_sessions')
                    .insert({
                        user_id: user.id,
                        date: today,
                        minutes: data.todayMinutes,
                        mode: mode || 'void'
                    });
            }
        } catch (error) {
            console.error('Sync to cloud failed:', error);
        }
    }, [user]);

    // Load data from Supabase
    const loadFromCloud = useCallback(async (): Promise<HabitData | null> => {
        if (!user) return null;

        try {
            // Get all sessions
            const { data: sessions, error } = await supabase
                .from('meditation_sessions')
                .select('date, minutes')
                .eq('user_id', user.id)
                .order('date', { ascending: false });

            if (error) throw error;
            if (!sessions || sessions.length === 0) return null;

            // Get preferences
            const { data: prefs } = await supabase
                .from('user_habits')
                .select('daily_goal, space_theme')
                .eq('user_id', user.id)
                .single();

            // Calculate stats from sessions
            const today = new Date().toISOString().split('T')[0];
            const weekStart = getWeekStart();

            const todayMinutes = sessions
                .filter(s => s.date === today)
                .reduce((sum, s) => sum + s.minutes, 0);

            const weeklyMinutes = sessions
                .filter(s => s.date >= weekStart)
                .reduce((sum, s) => sum + s.minutes, 0);

            const lifetimeMinutes = sessions.reduce((sum, s) => sum + s.minutes, 0);

            const currentStreak = calculateStreak(sessions);

            return {
                todayMinutes,
                currentStreak,
                lifetimeMinutes,
                weeklyMinutes,
                dailyGoal: prefs?.daily_goal || 10,
                history: sessions.map(s => ({ date: s.date, minutes: s.minutes }))
            };
        } catch (error) {
            console.error('Load from cloud failed:', error);
            return null;
        }
    }, [user]);

    // Sync preferences
    const syncPreferences = useCallback(async (spaceTheme: boolean, dailyGoal: number) => {
        if (!user) return;

        try {
            await supabase
                .from('user_habits')
                .upsert({
                    user_id: user.id,
                    space_theme: spaceTheme,
                    daily_goal: dailyGoal,
                    updated_at: new Date().toISOString()
                }, { onConflict: 'user_id' });
        } catch (error) {
            console.error('Sync preferences failed:', error);
        }
    }, [user]);

    return { syncToCloud, loadFromCloud, syncPreferences };
}

// Helper functions
function getWeekStart(): string {
    const now = new Date();
    const day = now.getDay();
    const diff = now.getDate() - day + (day === 0 ? -6 : 1);
    return new Date(now.setDate(diff)).toISOString().split('T')[0];
}

function calculateStreak(sessions: { date: string; minutes: number }[]): number {
    if (sessions.length === 0) return 0;

    const today = new Date().toISOString().split('T')[0];
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

    // Get unique dates
    const dates = [...new Set(sessions.map(s => s.date))].sort().reverse();

    if (dates[0] !== today && dates[0] !== yesterday) return 0;

    let streak = 1;
    let currentDate = new Date(dates[0]);

    for (let i = 1; i < dates.length; i++) {
        const prevDate = new Date(currentDate.getTime() - 86400000);
        const prevDateStr = prevDate.toISOString().split('T')[0];

        if (dates[i] === prevDateStr) {
            streak++;
            currentDate = prevDate;
        } else {
            break;
        }
    }

    return streak;
}
