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
    isAdmin: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [user, setUser] = useState<User | null>(null);
    const [session, setSession] = useState<Session | null>(null);
    const [loading, setLoading] = useState(true);
    const [isAdmin, setIsAdmin] = useState(false);
    const navigate = useNavigate();

    useEffect(() => {
        // Check for existing session
        checkUser();

        // Listen for auth changes
        const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
            setSession(session);
            setUser(session?.user ?? null);
            if (session?.user) {
                checkAdminStatus(session.user.id);
            } else {
                setIsAdmin(false);
            }
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
                await checkAdminStatus(session.user.id);
                console.log('✅ User session found');
            } else {
                console.log('ℹ️ No active user session');
            }
        } catch (error) {
            console.error('Error checking session:', error);
            setUser(null);
            setSession(null);
            setIsAdmin(false);
        } finally {
            setLoading(false);
        }
    };

    const checkAdminStatus = async (userId: string) => {
        try {
            const { data: profile, error } = await supabase
                .from('profiles')
                .select('role')
                .eq('user_id', userId)
                .maybeSingle();

            // If no profile found or error, silently set non-admin (this is normal for new users)
            if (error || !profile) {
                setIsAdmin(false);
                return;
            }

            const hasAdminRole = profile?.role === 'admin';
            setIsAdmin(hasAdminRole);

            // Debug logging
            console.log('🔐 Admin Status Check:', {
                userId,
                role: profile?.role,
                isAdmin: hasAdminRole
            });
        } catch (error) {
            // Silently handle - user is just not an admin
            setIsAdmin(false);
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

            // Check admin status and wait for it
            console.log('🔍 Checking admin status for user:', data.user.id);
            await checkAdminStatus(data.user.id);

            // Get the admin status from the profile
            const { data: profile } = await supabase
                .from('profiles')
                .select('role')
                .eq('user_id', data.user.id)
                .single();

            console.log('👤 User profile role:', profile?.role);

            if (profile?.role === 'admin') {
                console.log('✅ Admin user detected, redirecting to /admin');
                setIsAdmin(true);
                navigate('/admin');
            } else {
                console.log('👤 Regular user detected, redirecting to /');
                setIsAdmin(false);
                navigate('/');
            }
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
            setIsAdmin(false);
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
