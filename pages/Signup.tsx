import React, { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import { Mail, Lock, User as UserIcon, AlertCircle, ArrowRight } from 'lucide-react';

const Signup: React.FC = () => {
    const { signUp } = useAuth();
    const navigate = useNavigate();
    const [firstName, setFirstName] = useState('');
    const [lastName, setLastName] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');

        if (password.length < 8) {
            setError('Password must be at least 8 characters');
            return;
        }

        setLoading(true);

        try {
            const fullName = `${firstName} ${lastName}`.trim();
            await signUp(email, password, fullName);
        } catch (err: any) {
            setError(err.message || 'Failed to create account');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen bg-[#F2F4F7] flex items-center justify-center p-4 font-sans">
            <div className="bg-white rounded-[32px] shadow-xl w-full max-w-[480px] p-8 md:p-10 relative overflow-hidden">



                {/* Toggle */}
                <div className="flex bg-gray-100 p-1 rounded-full w-fit mb-8">
                    <button className="px-6 py-2 rounded-full bg-white text-slate-900 shadow-sm text-sm font-medium transition-all">
                        Sign up
                    </button>
                    <button
                        onClick={() => navigate('/login')}
                        className="px-6 py-2 rounded-full text-slate-500 hover:text-slate-900 text-sm font-medium transition-all"
                    >
                        Sign in
                    </button>
                </div>

                <h1 className="text-3xl font-bold text-slate-900 mb-8">Create an account</h1>

                <form onSubmit={handleSubmit} className="space-y-4">
                    {error && (
                        <div className="bg-red-50 text-red-600 text-sm p-3 rounded-xl flex items-center gap-2">
                            <AlertCircle className="w-4 h-4" />
                            {error}
                        </div>
                    )}

                    <div className="grid grid-cols-2 gap-4">
                        <div className="space-y-1">
                            <input
                                type="text"
                                placeholder="First name"
                                value={firstName}
                                onChange={(e) => setFirstName(e.target.value)}
                                required
                                className="w-full bg-gray-50 border border-gray-200 text-slate-900 placeholder:text-slate-400 rounded-xl px-4 py-3.5 outline-none focus:ring-2 focus:ring-slate-900/10 focus:border-slate-900 transition-all"
                            />
                        </div>
                        <div className="space-y-1">
                            <input
                                type="text"
                                placeholder="Last name"
                                value={lastName}
                                onChange={(e) => setLastName(e.target.value)}
                                required
                                className="w-full bg-gray-50 border border-gray-200 text-slate-900 placeholder:text-slate-400 rounded-xl px-4 py-3.5 outline-none focus:ring-2 focus:ring-slate-900/10 focus:border-slate-900 transition-all"
                            />
                        </div>
                    </div>

                    <div className="space-y-1">
                        <input
                            type="email"
                            placeholder="Enter your email"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            required
                            className="w-full bg-gray-50 border border-gray-200 text-slate-900 placeholder:text-slate-400 rounded-xl px-4 py-3.5 outline-none focus:ring-2 focus:ring-slate-900/10 focus:border-slate-900 transition-all"
                        />
                    </div>

                    <div className="space-y-1">
                        <input
                            type="password"
                            placeholder="Create a password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            required
                            className="w-full bg-gray-50 border border-gray-200 text-slate-900 placeholder:text-slate-400 rounded-xl px-4 py-3.5 outline-none focus:ring-2 focus:ring-slate-900/10 focus:border-slate-900 transition-all"
                        />
                    </div>

                    <button
                        type="submit"
                        disabled={loading}
                        className="w-full bg-slate-900 hover:bg-slate-800 text-white font-semibold rounded-xl py-4 mt-2 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-slate-900/20"
                    >
                        {loading ? 'Creating account...' : 'Create an account'}
                    </button>
                </form>



                <p className="text-center text-xs text-slate-400 mt-8">
                    By creating an account, you agree to our <a href="#" className="underline hover:text-slate-600">Terms & Service</a>
                </p>
            </div>
        </div>
    );
};

export default Signup;
