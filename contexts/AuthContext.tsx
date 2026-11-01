import React, { createContext, useContext, useEffect, useState } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import { useNavigate } from 'react-router-dom';

interface AuthContextType {
    user: User | null;
    session: Session | null;
    loading: boolean;
    signIn: (email: string, password: string) => Promise<void>;
    signOut: () => Promise<void>;
    // TC-018 (29 Oct, Clara #16): the profiles table this used to check for
    // an 'admin' role no longer exists. /admin/* has its own role gate
    // (contexts/PortalAuthContext.tsx + components/admin-shell/RequireRole)
    // unrelated to this patient-portal sign-in; no caller here passes
    // requireAdmin=true (components/ProtectedRoute.tsx), so this is kept
    // false for API compatibility rather than removed.
    isAdmin: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [user, setUser] = useState<User | null>(null);
    const [session, setSession] = useState<Session | null>(null);
    const [loading, setLoading] = useState(true);
    const [isAdmin] = useState(false);
    const navigate = useNavigate();

    useEffect(() => {
        // Check for existing session
        checkUser();

        // Listen for auth changes
        const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
            setSession(session);
            setUser(session?.user ?? null);
        });

        return () => subscription.unsubscribe();
    }, []);

    const checkUser = async () => {
        try {
            console.log('🔍 Checking for existing user session...');
            const { data: { session } } = await supabase.auth.getSession();

            setSession(session);
            setUser(session?.user ?? null);

            if (session?.user) {
                console.log('✅ User session found');
            } else {
                console.log('ℹ️ No active user session');
            }
        } catch (error) {
            console.error('Error checking session:', error);
            setUser(null);
            setSession(null);
        } finally {
            setLoading(false);
        }
    };

    const signIn = async (email: string, password: string) => {
        try {
            console.log('🔑 Attempting sign in for:', email);

            const { data, error } = await supabase.auth.signInWithPassword({
                email,
                password
            });

            if (error) throw error;

            setUser(data.user);
            setSession(data.session);
            navigate('/');
        } catch (error: any) {
            console.error('❌ Sign in error:', error);
            const errorMessage = error.message || 'Failed to sign in';

            // Provide more helpful error messages
            if (errorMessage.includes('Invalid login credentials')) {
                throw new Error('Invalid email or password. Please check your credentials and try again.');
            } else if (errorMessage.includes('Email not confirmed')) {
                throw new Error('Please confirm your email address before signing in.');
            }

            throw new Error(errorMessage);
        }
    };


    const signOut = async () => {
        try {
            console.log('👋 Signing out...');
            const { error } = await supabase.auth.signOut();

            if (error) throw error;

            setUser(null);
            setSession(null);
            navigate('/login');
        } catch (error: any) {
            console.error('❌ Sign out error:', error);
            throw new Error(error.message || 'Failed to sign out');
        }
    };

    return (
        <AuthContext.Provider
            value={{
                user,
                session,
                loading,
                signIn,
                signOut,
                isAdmin,
            }}
        >
            {children}
        </AuthContext.Provider>
    );
};

export const useAuth = () => {
    const context = useContext(AuthContext);
    if (context === undefined) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
};
