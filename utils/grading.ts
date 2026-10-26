/**
 * Health Domain Grading System
 * Converts numeric scores (0-100) to letter grades (A+ to F)
 */

export type Grade = 'A+' | 'A' | 'A-' | 'B+' | 'B' | 'B-' | 'C+' | 'C' | 'C-' | 'D' | 'F';

export interface GradeInfo {
    grade: Grade;
    label: string;
    color: string;
    bgColor: string;
    borderColor: string;
    textColor: string;
}

/**
 * Convert a numeric score (0-100) to a letter grade
 */
export function scoreToGrade(score: number): Grade {
    if (score >= 97) return 'A+';
    if (score >= 93) return 'A';
    if (score >= 90) return 'A-';
    if (score >= 87) return 'B+';
    if (score >= 83) return 'B';
    if (score >= 80) return 'B-';
    if (score >= 77) return 'C+';
    if (score >= 73) return 'C';
    if (score >= 70) return 'C-';
    if (score >= 60) return 'D';
    return 'F';
}

/**
 * Get the label for a grade (for display)
 */
export function getGradeLabel(grade: Grade): string {
    const labels: Record<Grade, string> = {
        'A+': 'Exceptional',
        'A': 'Excellent',
        'A-': 'Very Good',
        'B+': 'Good',
        'B': 'Above Average',
        'B-': 'Satisfactory',
        'C+': 'Fair',
        'C': 'Average',
        'C-': 'Below Average',
        'D': 'Needs Attention',
        'F': 'Critical'
    };
    return labels[grade];
}

/**
 * Get styling information for a grade
 */
export function getGradeStyles(grade: Grade): GradeInfo {
    const gradeStyles: Record<Grade, Omit<GradeInfo, 'grade'>> = {
        'A+': { label: 'Exceptional', color: 'emerald', bgColor: 'bg-emerald-100', borderColor: 'border-emerald-200', textColor: 'text-emerald-700' },
        'A': { label: 'Excellent', color: 'emerald', bgColor: 'bg-emerald-50', borderColor: 'border-emerald-100', textColor: 'text-emerald-600' },
        'A-': { label: 'Very Good', color: 'green', bgColor: 'bg-green-50', borderColor: 'border-green-100', textColor: 'text-green-600' },
        'B+': { label: 'Good', color: 'teal', bgColor: 'bg-teal-50', borderColor: 'border-teal-100', textColor: 'text-teal-600' },
        'B': { label: 'Above Average', color: 'cyan', bgColor: 'bg-cyan-50', borderColor: 'border-cyan-100', textColor: 'text-cyan-600' },
        'B-': { label: 'Satisfactory', color: 'blue', bgColor: 'bg-blue-50', borderColor: 'border-blue-100', textColor: 'text-blue-600' },
        'C+': { label: 'Fair', color: 'amber', bgColor: 'bg-amber-50', borderColor: 'border-amber-100', textColor: 'text-amber-600' },
        'C': { label: 'Average', color: 'orange', bgColor: 'bg-orange-50', borderColor: 'border-orange-100', textColor: 'text-orange-600' },
        'C-': { label: 'Below Average', color: 'orange', bgColor: 'bg-orange-100', borderColor: 'border-orange-200', textColor: 'text-orange-700' },
        'D': { label: 'Needs Attention', color: 'red', bgColor: 'bg-red-50', borderColor: 'border-red-100', textColor: 'text-red-500' },
        'F': { label: 'Critical', color: 'red', bgColor: 'bg-red-100', borderColor: 'border-red-200', textColor: 'text-red-700' }
    };

    return { grade, ...gradeStyles[grade] };
}

/**
 * Get full grade info from a score
 */
export function getGradeFromScore(score: number): GradeInfo {
    const grade = scoreToGrade(score);
    return getGradeStyles(grade);
}
