import React from 'react';

interface LoadingSkeletonProps {
    variant?: 'text' | 'circular' | 'rectangular' | 'card';
    width?: string | number;
    height?: string | number;
    className?: string;
    count?: number;
}

const LoadingSkeleton: React.FC<LoadingSkeletonProps> = ({
    variant = 'rectangular',
    width = '100%',
    height = '20px',
    className = '',
    count = 1
}) => {
    const getVariantClasses = () => {
        switch (variant) {
            case 'text':
                return 'h-4 rounded';
            case 'circular':
                return 'rounded-full';
            case 'card':
                return 'rounded-2xl';
            case 'rectangular':
            default:
                return 'rounded-xl';
        }
    };

    const skeletonStyle: React.CSSProperties = {
        width: typeof width === 'number' ? `${width}px` : width,
        height: typeof height === 'number' ? `${height}px` : height,
        backgroundImage: 'linear-gradient(90deg, #e2e8f0 0px, #f1f5f9 40px, #e2e8f0 80px)',
        backgroundSize: '200% 100%',
        animation: 'shimmer 1.5s infinite linear',
    };

    const skeletonElement = (
        <>
            <style>{`
                @keyframes shimmer {
                    0% { background-position: 200% 0;  }
                    100% { background-position: -200% 0; }
                }
            `}</style>
            <div
                className={`${getVariantClasses()} ${className}`}
                style={skeletonStyle}
            />
        </>
    );

    if (count === 1) {
        return skeletonElement;
    }

    return (
        <div className="space-y-3">
            {Array.from({ length: count }).map((_, index) => (
                <div key={index}>{skeletonElement}</div>
            ))}
        </div>
    );
};

// Preset skeleton components for common use cases
export const SkeletonCard: React.FC<{ className?: string }> = ({ className = '' }) => (
    <div className={`bg-white rounded-2xl shadow-sm border border-slate-200 p-6 ${className}`}>
        <LoadingSkeleton variant="text" width="60%" height={24} className="mb-4" />
        <LoadingSkeleton variant="text" width="100%" count={3} />
        <LoadingSkeleton variant="rectangular" width="100%" height={120} className="mt-4" />
    </div>
);

export const SkeletonStat: React.FC<{ className?: string }> = ({ className = '' }) => (
    <div className={`bg-white rounded-2xl shadow-sm border border-slate-200 p-6 ${className}`}>
        <LoadingSkeleton variant="circular" width={48} height={48} className="mb-4" />
        <LoadingSkeleton variant="text" width="40%" height={16} className="mb-2" />
        <LoadingSkeleton variant="text" width="60%" height={32} />
    </div>
);

export const SkeletonTable: React.FC<{ rows?: number; className?: string }> = ({
    rows = 5,
    className = ''
}) => (
    <div className={`bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden ${className}`}>
        <div className="p-4 border-b border-slate-200">
            <LoadingSkeleton variant="text" width="30%" height={20} />
        </div>
        <div className="divide-y divide-slate-200">
            {Array.from({ length: rows }).map((_, index) => (
                <div key={index} className="p-4 flex items-center gap-4">
                    <LoadingSkeleton variant="circular" width={40} height={40} />
                    <div className="flex-1 space-y-2">
                        <LoadingSkeleton variant="text" width="80%" />
                        <LoadingSkeleton variant="text" width="60%" height={14} />
                    </div>
                    <LoadingSkeleton variant="rectangular" width={100} height={36} />
                </div>
            ))}
        </div>
    </div>
);

export default LoadingSkeleton;
