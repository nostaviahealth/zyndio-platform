import React, { useState } from 'react';
import { FileText, ChevronRight, AlertCircle, CheckCircle, Download, TrendingUp, TrendingDown, Minus, Calendar, Activity, Sparkles, Search, Filter, BarChart3 } from 'lucide-react';
import { LAB_REPORTS } from '../constants';

const HealthData: React.FC = () => {
    const [selectedReportId, setSelectedReportId] = useState<string>(LAB_REPORTS[0].id);
    const [selectedCategory, setSelectedCategory] = useState<string>('All');
    const [searchQuery, setSearchQuery] = useState<string>('');

    const activeReport = LAB_REPORTS.find(r => r.id === selectedReportId);

    // Category definitions
    const categoryConfig = [
        { name: 'Metabolic', icon: Activity, color: 'emerald', start: 0, end: 15 },
        { name: 'Cardiovascular', icon: Activity, color: 'red', start: 15, end: 23 },
        { name: 'Liver', icon: Activity, color: 'amber', start: 23, end: 33 },
        { name: 'Kidney', icon: Activity, color: 'blue', start: 33, end: 39 },
        { name: 'Thyroid', icon: Activity, color: 'purple', start: 39, end: 45 },
        { name: 'Hormones', icon: Activity, color: 'pink', start: 45, end: 57 },
        { name: 'Vitamins', icon: Sparkles, color: 'orange', start: 57, end: 70 },
        { name: 'Minerals', icon: Activity, color: 'teal', start: 70, end: 80 },
        { name: 'Blood Count', icon: Activity, color: 'rose', start: 80, end: 90 },
        { name: 'Longevity', icon: Sparkles, color: 'indigo', start: 90, end: 100 },
    ];

    if (!activeReport) return null;

    const filteredMarkers = activeReport.markers.filter(marker => {
        const matchesSearch = marker.name.toLowerCase().includes(searchQuery.toLowerCase());
        if (selectedCategory === 'All') return matchesSearch;

        const category = categoryConfig.find(cat => {
            const index = activeReport.markers.indexOf(marker);
            return index >= cat.start && index < cat.end;
        });
        return matchesSearch && category?.name === selectedCategory;
    });

    return (
        <div className="flex flex-col h-[calc(100vh-140px)] gap-4 md:gap-6">

            {/* Top Header with Reports Tabs */}
            <div className="bg-white rounded-2xl md:rounded-3xl shadow-sm border border-stone-100 p-4 md:p-6">
                <div className="flex flex-col md:flex-row md:items-center justify-between mb-4 gap-3">
                    <div>
                        <h1 className="text-2xl md:text-3xl font-serif font-bold text-brand-dark flex items-center gap-2 md:gap-3">
                            <BarChart3 className="w-6 h-6 md:w-8 md:h-8 text-brand-sage" />
                            Health Data
                        </h1>
                        <p className="text-xs md:text-sm text-stone-500 mt-1">{LAB_REPORTS.length} comprehensive reports on file</p>
                    </div>
                    <button className="px-3 py-2 md:px-4 md:py-2 bg-brand-dark text-white rounded-xl hover:bg-opacity-90 transition-all flex items-center gap-2 text-sm md:text-base">
                        <Download className="w-4 h-4" />
                        <span className="hidden sm:inline">Upload New Report</span>
                        <span className="sm:hidden">Upload</span>
                    </button>
                </div>

                {/* Report Tabs */}
                <div className="flex gap-2 overflow-x-auto pb-2 -mx-2 px-2 scrollbar-hide">
                    {LAB_REPORTS.map((report) => {
                        const hasAbnormal = report.markers.some(m => m.status === 'Abnormal');
                        const isSelected = selectedReportId === report.id;

                        return (
                            <button
                                key={report.id}
                                onClick={() => setSelectedReportId(report.id)}
                                className={`px-3 py-2 md:px-4 md:py-3 rounded-xl transition-all flex-shrink-0 ${isSelected
                                    ? 'bg-brand-dark text-white'
                                    : 'bg-stone-50 text-stone-700 hover:bg-stone-100'
                                    }`}
                            >
                                <div className="flex items-center gap-2">
                                    <Calendar className="w-3 h-3 md:w-4 md:h-4" />
                                    <div className="text-left">
                                        <div className="font-semibold text-xs md:text-sm">{report.date}</div>
                                        <div className={`text-xs ${isSelected ? 'text-white/70' : 'text-stone-500'}`}>
                                            {report.markers.length} markers
                                        </div>
                                    </div>
                                    {hasAbnormal && (
                                        <div className="w-2 h-2 bg-red-500 rounded-full" />
                                    )}
                                </div>
                            </button>
                        );
                    })}
                </div>
            </div>

            {/* Main Content */}
            <div className="flex-1 bg-white rounded-2xl md:rounded-3xl shadow-sm border border-stone-100 overflow-hidden flex flex-col">

                {/* Report Header & Stats */}
                <div className="p-4 md:p-6 border-b border-stone-100 bg-gradient-to-br from-stone-50 to-white">
                    <h2 className="text-xl md:text-2xl font-serif font-bold text-brand-dark mb-3 md:mb-4">{activeReport.title}</h2>

                    {/* Stats Cards */}
                    <div className="grid grid-cols-3 gap-2 md:gap-4">
                        <div className="bg-emerald-50 rounded-lg md:rounded-xl p-3 md:p-4 border-2 border-emerald-100">
                            <div className="text-2xl md:text-3xl font-bold text-emerald-700">
                                {activeReport.markers.filter(m => m.status === 'Optimal').length}
                            </div>
                            <div className="text-xs text-emerald-600 font-medium mt-1 flex items-center gap-1">
                                <CheckCircle className="w-3 h-3 hidden sm:block" />
                                Optimal
                            </div>
                        </div>
                        <div className="bg-blue-50 rounded-lg md:rounded-xl p-3 md:p-4 border-2 border-blue-100">
                            <div className="text-2xl md:text-3xl font-bold text-blue-700">
                                {activeReport.markers.filter(m => m.status === 'Normal').length}
                            </div>
                            <div className="text-xs text-blue-600 font-medium mt-1 flex items-center gap-1">
                                <Activity className="w-3 h-3 hidden sm:block" />
                                <span className="hidden sm:inline">Normal Range</span>
                                <span className="sm:hidden">Normal</span>
                            </div>
                        </div>
                        <div className="bg-red-50 rounded-lg md:rounded-xl p-3 md:p-4 border-2 border-red-100">
                            <div className="text-2xl md:text-3xl font-bold text-red-700">
                                {activeReport.markers.filter(m => m.status === 'Abnormal').length}
                            </div>
                            <div className="text-xs text-red-600 font-medium mt-1 flex items-center gap-1">
                                <AlertCircle className="w-3 h-3 hidden sm:block" />
                                <span className="hidden sm:inline">Needs Attention</span>
                                <span className="sm:hidden">Alert</span>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Search & Category Filter */}
                <div className="px-4 md:px-6 py-3 md:py-4 border-b border-stone-100 bg-stone-50/50">
                    <div className="flex gap-2 md:gap-3 items-center">
                        <div className="flex-1 relative">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-stone-400" />
                            <input
                                type="text"
                                placeholder="Search biomarkers..."
                                value={searchQuery}
                                onChange={(e) => setSearchQuery(e.target.value)}
                                className="w-full pl-10 pr-4 py-2 border border-stone-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-brand-dark text-sm md:text-base"
                            />
                        </div>
                        <button className="px-3 py-2 md:px-4 border border-stone-200 rounded-xl hover:bg-stone-100 transition-all flex items-center gap-2">
                            <Filter className="w-4 h-4" />
                            <span className="hidden md:inline">Filter</span>
                        </button>
                    </div>

                    {/* Category Pills */}
                    <div className="flex flex-wrap gap-2 mt-3">
                        <button
                            onClick={() => setSelectedCategory('All')}
                            className={`px-2 py-1 md:px-3 md:py-1.5 text-xs rounded-full font-medium transition-all ${selectedCategory === 'All'
                                ? 'bg-brand-dark text-white'
                                : 'bg-white border border-stone-200 text-stone-600 hover:border-brand-dark'
                                }`}
                        >
                            All ({activeReport.markers.length})
                        </button>
                        {categoryConfig.map((cat) => {
                            const count = activeReport.markers.slice(cat.start, cat.end).length;
                            if (count === 0) return null;

                            return (
                                <button
                                    key={cat.name}
                                    onClick={() => setSelectedCategory(cat.name)}
                                    className={`px-2 py-1 md:px-3 md:py-1.5 text-xs rounded-full font-medium transition-all whitespace-nowrap ${selectedCategory === cat.name
                                        ? 'bg-brand-dark text-white'
                                        : 'bg-white border border-stone-200 text-stone-600 hover:border-brand-dark'
                                        }`}
                                >
                                    {cat.name} ({count})
                                </button>
                            );
                        })}
                    </div>
                </div>

                {/* Biomarkers List */}
                <div className="flex-1 overflow-y-auto p-4 md:p-6">
                    <div className="space-y-2">
                        {filteredMarkers.length === 0 ? (
                            <div className="text-center py-12 text-stone-500">
                                <Search className="w-12 h-12 mx-auto mb-3 opacity-30" />
                                <p className="text-sm md:text-base">No biomarkers found matching your search.</p>
                            </div>
                        ) : (
                            filteredMarkers.map((marker, idx) => (
                                <div
                                    key={idx}
                                    className="bg-stone-50 rounded-xl p-3 md:p-4 hover:bg-stone-100 transition-all group cursor-pointer"
                                >
                                    <div className="flex flex-col sm:flex-row items-start sm:justify-between gap-3 sm:gap-0">
                                        <div className="flex-1 w-full">
                                            <h4 className="font-bold text-stone-900 text-sm md:text-base">{marker.name}</h4>
                                            <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4 mt-2 text-xs md:text-sm">
                                                <div>
                                                    <span className="text-stone-500">Value: </span>
                                                    <span className="font-semibold text-stone-900">{marker.value}</span>
                                                </div>
                                                <div>
                                                    <span className="text-stone-500">Range: </span>
                                                    <span className="font-medium text-stone-700">{marker.range}</span>
                                                </div>
                                            </div>
                                            {marker.insight && (
                                                <p className="text-xs text-stone-600 mt-2 italic line-clamp-2">{marker.insight}</p>
                                            )}
                                        </div>
                                        <div className="w-full sm:w-auto">
                                            <span
                                                className={`inline-flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium w-full sm:w-auto ${marker.status === 'Abnormal'
                                                    ? 'bg-red-100 text-red-700 border-2 border-red-200'
                                                    : marker.status === 'Optimal'
                                                        ? 'bg-emerald-100 text-emerald-700 border-2 border-emerald-200'
                                                        : 'bg-blue-100 text-blue-700 border-2 border-blue-200'
                                                    }`}
                                            >
                                                {marker.status === 'Abnormal' && <AlertCircle className="w-3 h-3" />}
                                                {marker.status === 'Optimal' && <CheckCircle className="w-3 h-3" />}
                                                {marker.status}
                                            </span>
                                        </div>
                                    </div>
                                </div>
                            ))
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
};

export default HealthData;