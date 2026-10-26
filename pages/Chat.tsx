import React, { useState, useRef, useEffect } from 'react';
import { Send, Sparkles, User, Settings, Plus, X, ChevronLeft, ChevronRight, Crown, Lock } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useUser } from '../contexts/UserContext';
import { supabase } from '../lib/supabase';

interface Message {
    role: 'user' | 'assistant';
    content: string;
}

interface ChatSession {
    id: string;
    title: string;
    timestamp: string;
}

const Chat: React.FC = () => {
    const navigate = useNavigate();
    const { isPro } = useUser();
    const [messages, setMessages] = useState<Message[]>([
        { role: 'assistant', content: "Hello! I'm your Zyndio AI health assistant. I can help analyze your biomarkers, suggest protocol optimizations, and answer questions about your health data." }
    ]);
    const [input, setInput] = useState('');
    const [isTyping, setIsTyping] = useState(false);
    const [showSidebar, setShowSidebar] = useState(true);
    const messagesEndRef = useRef<HTMLDivElement>(null);

    const [history] = useState<ChatSession[]>([
        { id: '1', title: 'Blood Work Analysis', timestamp: '2 hours ago' },
        { id: '2', title: 'Sleep Optimization Tips', timestamp: 'Yesterday' },
        { id: '3', title: 'Zone 2 Cardio Plan', timestamp: '2 days ago' },
    ]);

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    };

    useEffect(() => {
        scrollToBottom();
    }, [messages, isTyping]);

    const handleSend = async () => {
        if (!input.trim()) return;

        const userMessage = input;
        setMessages(prev => [...prev, { role: 'user', content: userMessage }]);
        setInput('');
        setIsTyping(true);

        try {
            const { data, error } = await supabase.functions.invoke('intelligence', {
                body: {
                    messages: [
                        { role: "system", content: "You are Zyndio, an advanced health AI assistant. Keep responses concise and actionable." },
                        ...messages.map(m => ({ role: m.role, content: m.content })),
                        { role: "user", content: userMessage }
                    ],
                    max_completion_tokens: 4096
                }
            });

            if (error) {
                throw error;
            }

            if (data.error) {
                throw new Error(data.error);
            }

            const aiResponse = data.choices[0].message.content;
            setMessages(prev => [...prev, { role: 'assistant', content: aiResponse }]);
        } catch (error) {
            setMessages(prev => [...prev, { role: 'assistant', content: `Error: ${error instanceof Error ? error.message : 'Failed to fetch response'}.` }]);
        } finally {
            setIsTyping(false);
        }
    };

    // Pro user upgrade screen - show this instead of chat for Pro users
    if (isPro()) {
        return (
            <div className="flex items-center justify-center min-h-[70vh]">
                <div className="text-center max-w-md">
                    <div className="w-24 h-24 bg-gradient-to-br from-amber-100 to-amber-200 rounded-full flex items-center justify-center mx-auto mb-6 shadow-lg">
                        <Lock className="w-12 h-12 text-amber-600" />
                    </div>
                    <h2 className="text-2xl font-serif text-slate-900 mb-3">Concierge is an Ultimate Feature</h2>
                    <p className="text-slate-600 mb-6 leading-relaxed">
                        Get 24/7 access to your personal AI health concierge, real-time protocol optimization,
                        and personalized insights by upgrading to Ultimate.
                    </p>

                    <div className="bg-gradient-to-br from-amber-50 to-amber-100 rounded-2xl p-6 mb-6 border border-amber-200">
                        <div className="flex items-center justify-center gap-2 mb-4">
                            <Crown className="w-5 h-5 text-amber-600" />
                            <span className="font-bold text-amber-900">Ultimate Plan Includes:</span>
                        </div>
                        <ul className="text-sm text-amber-800 space-y-2 text-left">
                            <li className="flex items-center gap-2">
                                <div className="w-1.5 h-1.5 rounded-full bg-amber-500"></div>
                                AI Health Concierge (24/7)
                            </li>
                            <li className="flex items-center gap-2">
                                <div className="w-1.5 h-1.5 rounded-full bg-amber-500"></div>
                                Dynamic Protocol (evolves monthly)
                            </li>
                            <li className="flex items-center gap-2">
                                <div className="w-1.5 h-1.5 rounded-full bg-amber-500"></div>
                                Weekly Personalized Meal Plans
                            </li>
                            <li className="flex items-center gap-2">
                                <div className="w-1.5 h-1.5 rounded-full bg-amber-500"></div>
                                Multi-Phase Health Journey
                            </li>
                        </ul>
                    </div>

                    <button
                        onClick={() => window.location.href = 'https://member.zyndio.example/'}
                        className="w-full bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-600 hover:to-amber-700 text-white py-4 px-8 rounded-2xl font-semibold transition-all shadow-lg shadow-amber-500/30 flex items-center justify-center gap-2"
                    >
                        <Crown className="w-5 h-5" />
                        Upgrade to Ultimate
                    </button>

                    <button
                        onClick={() => navigate('/')}
                        className="text-slate-500 hover:text-slate-700 text-sm mt-4 font-medium"
                    >
                        Back to Dashboard
                    </button>
                </div>
            </div>
        );
    }

    // Ultimate users get full chat
    return (
        <div className="flex h-[calc(100vh-6rem)] w-full max-w-7xl mx-auto gap-4 overflow-hidden">

            {/* Sidebar */}
            <div className={`${showSidebar ? 'w-80' : 'w-0'} bg-white rounded-3xl shadow-soft overflow-hidden transition-all duration-300 flex flex-col flex-shrink-0`}>
                <div className="p-6 border-b border-slate-100">
                    <button
                        onClick={() => setMessages([{ role: 'assistant', content: "Hello! I'm your Zyndio AI health assistant. I can help analyze your biomarkers, suggest protocol optimizations, and answer questions about your health data." }])}
                        className="w-full flex items-center justify-center gap-2 bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700 text-white py-3 rounded-2xl font-medium transition-all shadow-lg shadow-emerald-500/20"
                    >
                        <Plus className="w-4 h-4" />
                        New Conversation
                    </button>
                </div>

                <div className="flex-1 overflow-y-auto p-4 space-y-2 custom-scrollbar">
                    <h3 className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-3 px-2">Recent Chats</h3>
                    {history.map(session => (
                        <button
                            key={session.id}
                            className="w-full text-left px-4 py-3 rounded-2xl bg-slate-50 hover:bg-emerald-50/50 border border-transparent hover:border-emerald-100 transition-all group"
                        >
                            <div className="font-medium text-sm text-slate-700 group-hover:text-emerald-700 truncate mb-1">
                                {session.title}
                            </div>
                            <div className="text-xs text-slate-400">{session.timestamp}</div>
                        </button>
                    ))}
                </div>

                <div className="p-4 border-t border-slate-100 flex items-center justify-center">
                    <span className="text-xs text-slate-400">Powered by Gemini AI</span>
                </div>
            </div>

            {/* Main Chat */}
            <div className="flex-1 flex flex-col bg-white rounded-3xl shadow-soft overflow-hidden min-w-0">
                {/* Header */}
                <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between bg-gradient-to-b from-white to-slate-50/30">
                    <div className="flex items-center gap-3">
                        <button
                            onClick={() => setShowSidebar(!showSidebar)}
                            className="p-2 hover:bg-white rounded-xl text-slate-400 hover:text-slate-600 transition-all"
                        >
                            {showSidebar ? <ChevronLeft className="w-5 h-5" /> : <ChevronRight className="w-5 h-5" />}
                        </button>
                        <div className="flex items-center gap-2">
                            <div className="w-8 h-8 rounded-full bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center shadow-lg shadow-emerald-500/30">
                                <Sparkles className="w-4 h-4 text-white" />
                            </div>
                            <div>
                                <h1 className="font-serif text-slate-900 font-semibold">Zyndio Concierge</h1>
                            </div>
                        </div>
                        <div className="px-2 py-1 rounded-full bg-amber-50 border border-amber-100 text-[10px] font-semibold text-amber-700 uppercase tracking-wide flex items-center gap-1">
                            <Crown className="w-3 h-3" />
                            Ultimate
                        </div>
                    </div>
                    <button
                        onClick={() => navigate('/intelligence')}
                        className="p-2 hover:bg-slate-100 rounded-full text-slate-400 hover:text-slate-600 transition-colors"
                    >
                        <X className="w-5 h-5" />
                    </button>
                </div>

                {/* Messages */}
                <div className="flex-1 overflow-y-auto p-6 space-y-6 bg-gradient-to-b from-slate-50/30 to-white custom-scrollbar">
                    {messages.map((msg, idx) => (
                        <div key={idx} className={`flex items-start gap-4 max-w-3xl mx-auto animate-fade-in ${msg.role === 'user' ? 'flex-row-reverse' : ''}`}>
                            <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 shadow-sm ${msg.role === 'assistant'
                                ? 'bg-gradient-to-br from-emerald-400 to-emerald-600 shadow-emerald-500/30'
                                : 'bg-gradient-to-br from-slate-100 to-slate-200'
                                }`}>
                                {msg.role === 'assistant' ? (
                                    <Sparkles className="w-4 h-4 text-white" />
                                ) : (
                                    <User className="w-4 h-4 text-slate-600" />
                                )}
                            </div>
                            <div className={`max-w-[80%] ${msg.role === 'user'
                                ? 'bg-slate-900 text-white px-5 py-3 rounded-3xl rounded-tr-md shadow-lg shadow-slate-900/10'
                                : 'text-slate-700'
                                } text-[15px] leading-relaxed`}>
                                {msg.content}
                            </div>
                        </div>
                    ))}
                    {isTyping && (
                        <div className="flex items-start gap-4 max-w-3xl mx-auto">
                            <div className="w-9 h-9 rounded-full bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center flex-shrink-0 shadow-sm shadow-emerald-500/30">
                                <Sparkles className="w-4 h-4 text-white" />
                            </div>
                            <div className="flex gap-1.5 items-center pt-2">
                                <div className="w-2 h-2 bg-emerald-400 rounded-full animate-bounce"></div>
                                <div className="w-2 h-2 bg-emerald-400 rounded-full animate-bounce" style={{ animationDelay: '0.1s' }}></div>
                                <div className="w-2 h-2 bg-emerald-400 rounded-full animate-bounce" style={{ animationDelay: '0.2s' }}></div>
                            </div>
                        </div>
                    )}
                    <div ref={messagesEndRef} />
                </div>

                {/* Input */}
                <div className="p-6 border-t border-slate-100 bg-white">
                    <div className="max-w-3xl mx-auto">
                        <div className="flex items-end gap-3 bg-slate-50 rounded-3xl p-2 shadow-sm border border-slate-100 focus-within:border-emerald-200 focus-within:ring-4 focus-within:ring-emerald-500/10 transition-all">
                            <input
                                type="text"
                                value={input}
                                onChange={(e) => setInput(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter' && !e.shiftKey) {
                                        e.preventDefault();
                                        handleSend();
                                    }
                                }}
                                placeholder="Ask about your health data..."
                                className="flex-1 bg-transparent border-none px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:ring-0 focus:outline-none text-[15px]"
                            />
                            <button
                                onClick={handleSend}
                                disabled={!input.trim()}
                                className="p-3 bg-gradient-to-r from-emerald-500 to-emerald-600 text-white rounded-2xl hover:from-emerald-600 hover:to-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg shadow-emerald-500/20 transform hover:scale-105 active:scale-95"
                            >
                                <Send className="w-4 h-4" />
                            </button>
                        </div>
                        <div className="text-center mt-3">
                            <span className="text-[11px] text-slate-400">
                                AI responses may contain errors. Verify important medical information.
                            </span>
                        </div>
                    </div>
                </div>

            </div>
        </div>
    );
};

export default Chat;
