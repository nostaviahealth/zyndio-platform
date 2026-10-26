// Form validation utilities

export interface ValidationResult {
    isValid: boolean;
    error?: string;
}

// Email validation
export const validateEmail = (email: string): ValidationResult => {
    if (!email) {
        return { isValid: false, error: 'Email is required' };
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
        return { isValid: false, error: 'Please enter a valid email address' };
    }

    return { isValid: true };
};

// Phone number validation
export const validatePhone = (phone: string): ValidationResult => {
    if (!phone) {
        return { isValid: false, error: 'Phone number is required' };
    }

    const phoneRegex = /^\+?[\d\s\-()]{10,}$/;
    if (!phoneRegex.test(phone)) {
        return { isValid: false, error: 'Please enter a valid phone number' };
    }

    return { isValid: true };
};

// Age validation
export const validateAge = (age: string | number): ValidationResult => {
    const ageNum = typeof age === 'string' ? parseInt(age) : age;

    if (!age || isNaN(ageNum)) {
        return { isValid: false, error: 'Age is required' };
    }

    if (ageNum < 18 || ageNum > 120) {
        return { isValid: false, error: 'Age must be between 18 and 120' };
    }

    return { isValid: true };
};

// Height validation (cm)
export const validateHeight = (height: string | number): ValidationResult => {
    const heightNum = typeof height === 'string' ? parseFloat(height) : height;

    if (!height || isNaN(heightNum)) {
        return { isValid: false, error: 'Height is required' };
    }

    if (heightNum < 100 || heightNum > 250) {
        return { isValid: false, error: 'Height must be between 100cm and 250cm' };
    }

    return { isValid: true };
};

// Weight validation (kg)
export const validateWeight = (weight: string | number): ValidationResult => {
    const weightNum = typeof weight === 'string' ? parseFloat(weight) : weight;

    if (!weight || isNaN(weightNum)) {
        return { isValid: false, error: 'Weight is required' };
    }

    if (weightNum < 30 || weightNum > 300) {
        return { isValid: false, error: 'Weight must be between 30kg and 300kg' };
    }

    return { isValid: true };
};

// Required field validation
export const validateRequired = (value: any, fieldName: string): ValidationResult => {
    if (!value || (typeof value === 'string' && value.trim() === '')) {
        return { isValid: false, error: `${fieldName} is required` };
    }

    if (Array.isArray(value) && value.length === 0) {
        return { isValid: false, error: `Please select at least one ${fieldName}` };
    }

    return { isValid: true };
};

// Date validation (no past dates)
export const validateFutureDate = (date: string): ValidationResult => {
    if (!date) {
        return { isValid: false, error: 'Date is required' };
    }

    const selectedDate = new Date(date);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (selectedDate < today) {
        return { isValid: false, error: 'Please select a future date' };
    }

    return { isValid: true };
};

// Password strength validation
export const validatePassword = (password: string): ValidationResult => {
    if (!password) {
        return { isValid: false, error: 'Password is required' };
    }

    if (password.length < 8) {
        return { isValid: false, error: 'Password must be at least 8 characters' };
    }

    if (!/[A-Z]/.test(password)) {
        return { isValid: false, error: 'Password must contain at least one uppercase letter' };
    }

    if (!/[a-z]/.test(password)) {
        return { isValid: false, error: 'Password must contain at least one lowercase letter' };
    }

    if (!/[0-9]/.test(password)) {
        return { isValid: false, error: 'Password must contain at least one number' };
    }

    return { isValid: true };
};

// Validate multiple fields at once
export const validateForm = (
    fields: Record<string, any>,
    validators: Record<string, (value: any) => ValidationResult>
): { isValid: boolean; errors: Record<string, string> } => {
    const errors: Record<string, string> = {};
    let isValid = true;

    Object.entries(validators).forEach(([fieldName, validator]) => {
        const result = validator(fields[fieldName]);
        if (!result.isValid) {
            isValid = false;
            if (result.error) {
                errors[fieldName] = result.error;
            }
        }
    });

    return { isValid, errors };
};
