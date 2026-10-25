// Food Database for Nutrition Workbench
export interface FoodItem {
    id: string;
    name: string;
    category: 'protein' | 'carbs' | 'fats' | 'vegetables' | 'fruits' | 'dairy' | 'snacks';
    serving: string;
    calories: number;
    protein: number; // grams
    carbs: number; // grams
    fats: number; // grams
    fiber?: number; // grams
    tags?: string[]; // e.g., 'gluten-free', 'vegan', 'keto'
}

export const FOOD_DATABASE: FoodItem[] = [
    // Proteins
    { id: 'f1', name: 'Grilled Chicken Breast', category: 'protein', serving: '150g', calories: 230, protein: 43, carbs: 0, fats: 5, tags: ['high-protein', 'keto'] },
    { id: 'f2', name: 'Wild Salmon', category: 'protein', serving: '150g', calories: 280, protein: 35, carbs: 0, fats: 14, fiber: 0, tags: ['omega-3', 'keto'] },
    { id: 'f3', name: 'Grass-Fed Beef (Lean)', category: 'protein', serving: '150g', calories: 250, protein: 38, carbs: 0, fats: 10, tags: ['high-protein', 'keto'] },
    { id: 'f4', name: 'Turkey Breast', category: 'protein', serving: '150g', calories: 190, protein: 40, carbs: 0, fats: 2, tags: ['lean', 'high-protein'] },
    { id: 'f5', name: 'Eggs (2 large)', category: 'protein', serving: '100g', calories: 140, protein: 12, carbs: 1, fats: 10, tags: ['keto', 'vegetarian'] },
    { id: 'f6', name: 'Tofu', category: 'protein', serving: '150g', calories: 120, protein: 14, carbs: 3, fats: 6, tags: ['vegan', 'plant-based'] },
    { id: 'f7', name: 'Lentils', category: 'protein', serving: '150g cooked', calories: 165, protein: 12, carbs: 28, fats: 1, fiber: 10, tags: ['vegan', 'high-fiber'] },
    { id: 'f8', name: 'Black Beans', category: 'protein', serving: '150g cooked', calories: 170, protein: 11, carbs: 30, fats: 1, fiber: 11, tags: ['vegan', 'high-fiber'] },
    { id: 'f9', name: 'Tuna (canned in water)', category: 'protein', serving: '100g', calories: 110, protein: 26, carbs: 0, fats: 1, tags: ['lean', 'high-protein'] },
    { id: 'f10', name: 'Shrimp', category: 'protein', serving: '100g', calories: 85, protein: 20, carbs: 0, fats: 1, tags: ['lean', 'keto'] },

    // Carbs
    { id: 'c1', name: 'Quinoa', category: 'carbs', serving: '150g cooked', calories: 180, protein: 6, carbs: 32, fats: 3, fiber: 4, tags: ['gluten-free', 'protein-rich'] },
    { id: 'c2', name: 'Sweet Potato', category: 'carbs', serving: '150g', calories: 130, protein: 2, carbs: 30, fats: 0, fiber: 5, tags: ['gluten-free', 'vitamin-a'] },
    { id: 'c3', name: 'Brown Rice', category: 'carbs', serving: '150g cooked', calories: 165, protein: 4, carbs: 34, fats: 1, fiber: 2, tags: ['gluten-free', 'whole-grain'] },
    { id: 'c4', name: 'Oatmeal', category: 'carbs', serving: '50g dry', calories: 190, protein: 7, carbs: 32, fats: 4, fiber: 5, tags: ['whole-grain', 'heart-healthy'] },
    { id: 'c5', name: 'Whole Wheat Pasta', category: 'carbs', serving: '80g dry', calories: 280, protein: 11, carbs: 56, fats: 2, fiber: 8, tags: ['whole-grain'] },
    { id: 'c6', name: 'Buckwheat', category: 'carbs', serving: '150g cooked', calories: 155, protein: 6, carbs: 33, fats: 1, fiber: 5, tags: ['gluten-free'] },
    { id: 'c7', name: 'Whole Grain Bread', category: 'carbs', serving: '2 slices', calories: 160, protein: 8, carbs: 28, fats: 2, fiber: 6, tags: ['whole-grain'] },
    { id: 'c8', name: 'Basmati Rice (White)', category: 'carbs', serving: '150g cooked', calories: 170, protein: 4, carbs: 36, fats: 0, fiber: 1, tags: [] },

    // Healthy Fats
    { id: 'h1', name: 'Avocado', category: 'fats', serving: '100g', calories: 160, protein: 2, carbs: 9, fats: 15, fiber: 7, tags: ['keto', 'heart-healthy'] },
    { id: 'h2', name: 'Almonds', category: 'fats', serving: '30g', calories: 170, protein: 6, carbs: 6, fats: 15, fiber: 4, tags: ['keto', 'vitamin-e'] },
    { id: 'h3', name: 'Walnuts', category: 'fats', serving: '30g', calories: 185, protein: 4, carbs: 4, fats: 18, fiber: 2, tags: ['omega-3', 'brain-health'] },
    { id: 'h4', name: 'Chia Seeds', category: 'fats', serving: '20g', calories: 100, protein: 3, carbs: 9, fats: 6, fiber: 8, tags: ['omega-3', 'high-fiber'] },
    { id: 'h5', name: 'Olive Oil', category: 'fats', serving: '1 tbsp', calories: 120, protein: 0, carbs: 0, fats: 14, tags: ['heart-healthy', 'keto'] },
    { id: 'h6', name: 'Peanut Butter (Natural)', category: 'fats', serving: '2 tbsp', calories: 190, protein: 8, carbs: 7, fats: 16, fiber: 2, tags: ['protein-rich'] },
    { id: 'h7', name: 'Coconut Oil', category: 'fats', serving: '1 tbsp', calories: 120, protein: 0, carbs: 0, fats: 14, tags: ['mct', 'keto'] },
    { id: 'h8', name: 'Dark Chocolate (85%)', category: 'fats', serving: '30g', calories: 170, protein: 3, carbs: 10, fats: 14, fiber: 4, tags: ['antioxidants'] },

    // Vegetables
    { id: 'v1', name: 'Broccoli', category: 'vegetables', serving: '150g', calories: 50, protein: 4, carbs: 10, fats: 0, fiber: 4, tags: ['cruciferous', 'vitamin-c'] },
    { id: 'v2', name: 'Spinach', category: 'vegetables', serving: '100g', calories: 23, protein: 3, carbs: 4, fats: 0, fiber: 2, tags: ['iron', 'vitamin-k'] },
    { id: 'v3', name: 'Kale', category: 'vegetables', serving: '100g', calories: 35, protein: 3, carbs: 6, fats: 1, fiber: 4, tags: ['superfood', 'vitamin-k'] },
    { id: 'v4', name: 'Bell Peppers', category: 'vegetables', serving: '150g', calories: 45, protein: 1, carbs: 11, fats: 0, fiber: 3, tags: ['vitamin-c', 'colorful'] },
    { id: 'v5', name: 'Asparagus', category: 'vegetables', serving: '150g', calories: 30, protein: 3, carbs: 6, fats: 0, fiber: 3, tags: ['folate'] },
    { id: 'v6', name: 'Cauliflower', category: 'vegetables', serving: '150g', calories: 38, protein: 3, carbs: 8, fats: 0, fiber: 3, tags: ['cruciferous', 'low-carb'] },
    { id: 'v7', name: 'Zucchini', category: 'vegetables', serving: '150g', calories: 25, protein: 2, carbs: 5, fats: 0, fiber: 2, tags: ['low-calorie'] },
    { id: 'v8', name: 'Brussels Sprouts', category: 'vegetables', serving: '150g', calories: 55, protein: 4, carbs: 11, fats: 1, fiber: 4, tags: ['cruciferous'] },
    { id: 'v9', name: 'Carrots', category: 'vegetables', serving: '100g', calories: 41, protein: 1, carbs: 10, fats: 0, fiber: 3, tags: ['vitamin-a', 'beta-carotene'] },
    { id: 'v10', name: 'Tomatoes', category: 'vegetables', serving: '150g', calories: 27, protein: 1, carbs: 6, fats: 0, fiber: 2, tags: ['lycopene', 'vitamin-c'] },
    { id: 'v11', name: 'Cucumber', category: 'vegetables', serving: '150g', calories: 23, protein: 1, carbs: 5, fats: 0, fiber: 1, tags: ['hydrating', 'low-calorie'] },
    { id: 'v12', name: 'Green Beans', category: 'vegetables', serving: '150g', calories: 44, protein: 2, carbs: 10, fats: 0, fiber: 4, tags: ['vitamin-k'] },

    // Fruits
    { id: 'fr1', name: 'Blueberries', category: 'fruits', serving: '100g', calories: 57, protein: 1, carbs: 14, fats: 0, fiber: 2, tags: ['antioxidants', 'brain-health'] },
    { id: 'fr2', name: 'Apple', category: 'fruits', serving: '150g', calories: 78, protein: 0, carbs: 21, fats: 0, fiber: 4, tags: ['fiber', 'vitamin-c'] },
    { id: 'fr3', name: 'Banana', category: 'fruits', serving: '120g', calories: 105, protein: 1, carbs: 27, fats: 0, fiber: 3, tags: ['potassium', 'energy'] },
    { id: 'fr4', name: 'Strawberries', category: 'fruits', serving: '150g', calories: 48, protein: 1, carbs: 12, fats: 0, fiber: 3, tags: ['vitamin-c', 'antioxidants'] },
    { id: 'fr5', name: 'Orange', category: 'fruits', serving: '150g', calories: 62, protein: 1, carbs: 15, fats: 0, fiber: 3, tags: ['vitamin-c', 'immune'] },
    { id: 'fr6', name: 'Raspberries', category: 'fruits', serving: '100g', calories: 52, protein: 1, carbs: 12, fats: 1, fiber: 7, tags: ['high-fiber', 'antioxidants'] },
    { id: 'fr7', name: 'Mango', category: 'fruits', serving: '150g', calories: 90, protein: 1, carbs: 23, fats: 0, fiber: 3, tags: ['vitamin-a', 'tropical'] },
    { id: 'fr8', name: 'Pineapple', category: 'fruits', serving: '150g', calories: 75, protein: 1, carbs: 20, fats: 0, fiber: 2, tags: ['bromelain', 'tropical'] },

    // Dairy & Alternatives
    { id: 'd1', name: 'Greek Yogurt (Plain)', category: 'dairy', serving: '170g', calories: 100, protein: 17, carbs: 6, fats: 0, tags: ['high-protein', 'probiotics'] },
    { id: 'd2', name: 'Cottage Cheese', category: 'dairy', serving: '150g', calories: 120, protein: 20, carbs: 6, fats: 2, tags: ['high-protein', 'casein'] },
    { id: 'd3', name: 'Almond Milk (Unsweetened)', category: 'dairy', serving: '240ml', calories: 30, protein: 1, carbs: 1, fats: 3, tags: ['vegan', 'low-calorie'] },
    { id: 'd4', name: 'Mozzarella Cheese', category: 'dairy', serving: '30g', calories: 85, protein: 6, carbs: 1, fats: 6, tags: ['keto', 'calcium'] },
    { id: 'd5', name: 'Cheddar Cheese', category: 'dairy', serving: '30g', calories: 115, protein: 7, carbs: 0, fats: 9, tags: ['keto', 'calcium'] },

    // Snacks & Misc
    { id: 's1', name: 'Hummus', category: 'snacks', serving: '50g', calories: 90, protein: 3, carbs: 9, fats: 5, fiber: 3, tags: ['vegan', 'protein'] },
    { id: 's2', name: 'Rice Cakes', category: 'snacks', serving: '2 cakes', calories: 70, protein: 2, carbs: 15, fats: 0, tags: ['gluten-free', 'low-fat'] },
    { id: 's3', name: 'Protein Shake', category: 'snacks', serving: '1 scoop + water', calories: 120, protein: 25, carbs: 3, fats: 1, tags: ['high-protein', 'post-workout'] },
    { id: 's4', name: 'Edamame', category: 'snacks', serving: '100g', calories: 120, protein: 11, carbs: 9, fats: 5, fiber: 5, tags: ['vegan', 'protein-rich'] },
    { id: 's5', name: 'Trail Mix (Nuts & Seeds)', category: 'snacks', serving: '30g', calories: 150, protein: 5, carbs: 10, fats: 11, fiber: 3, tags: ['energy', 'portable'] },
    { id: 's6', name: 'Protein Bar', category: 'snacks', serving: '1 bar', calories: 200, protein: 20, carbs: 22, fats: 6, fiber: 4, tags: ['high-protein', 'portable'] },
    { id: 's7', name: 'Coconut Water', category: 'snacks', serving: '240ml', calories: 45, protein: 1, carbs: 11, fats: 0, tags: ['hydrating', 'electrolytes'] },
    { id: 's8', name: 'Green Tea', category: 'snacks', serving: '240ml', calories: 0, protein: 0, carbs: 0, fats: 0, tags: ['antioxidants', 'metabolism'] },
];

// Meal Templates for Quick Generation
export const MEAL_TEMPLATES = {
    keto: {
        breakfast: ['f5', 'h1', 'v2'], // Eggs, Avocado, Spinach
        lunch: ['f2', 'v1', 'h5'], // Salmon, Broccoli, Olive Oil
        dinner: ['f1', 'v6', 'h2'], // Chicken, Cauliflower, Almonds
        snack: ['h8', 'h3'] // Dark Chocolate, Walnuts
    },
    balanced: {
        breakfast: ['c4', 'fr1', 'd1'], // Oatmeal, Blueberries, Greek Yogurt
        lunch: ['f1', 'c3', 'v4'], // Chicken, Brown Rice, Bell Peppers
        dinner: ['f2', 'c2', 'v1'], // Salmon, Sweet Potato, Broccoli
        snack: ['h2', 'fr2'] // Almonds, Apple
    },
    vegan: {
        breakfast: ['c4', 'h4', 'fr1'], // Oatmeal, Chia Seeds, Blueberries
        lunch: ['f7', 'c1', 'v3'], // Lentils, Quinoa, Kale
        dinner: ['f6', 'c3', 'v8'], // Tofu, Brown Rice, Brussels Sprouts
        snack: ['s1', 'v11'] // Hummus, Cucumber
    },
    highProtein: {
        breakfast: ['f5', 'd2', 'v2'], // Eggs, Cottage Cheese, Spinach
        lunch: ['f1', 'c1', 'v1'], // Chicken, Quinoa, Broccoli
        dinner: ['f3', 'c2', 'v5'], // Beef, Sweet Potato, Asparagus
        snack: ['s3', 'h2'] // Protein Shake, Almonds
    }
};
