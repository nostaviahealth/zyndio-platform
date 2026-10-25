import '../models/meal_plan.dart';

/// 4 rotating weeks of Indian vegetarian meals designed for longevity.
/// The plan auto-rotates based on the current ISO week number.

MealPlan getFreeMealPlan() {
  final now = DateTime.now();
  // Calculate ISO week number
  final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
  final weekNumber = ((dayOfYear - now.weekday + 10) / 7).floor();
  final weekIndex = weekNumber % 4; // Rotate through 4 weeks

  final weekData = _allWeeks[weekIndex];

  // Calculate actual dates for the current week (Monday to Sunday)
  final monday = now.subtract(Duration(days: now.weekday - 1));

  final weeklyPlan = <DayPlan>[];
  const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  for (int i = 0; i < 7; i++) {
    final date = monday.add(Duration(days: i));
    weeklyPlan.add(DayPlan(
      day: dayNames[i],
      date: '${date.day}',
      meals: weekData[i],
    ));
  }

  return MealPlan(
    id: 'free-plan-week-$weekIndex',
    weekStartDate: monday.toIso8601String().substring(0, 10),
    approved: true,
    weeklyPlan: weeklyPlan,
  );
}

// ─── WEEK 1 ──────────────────────────────────────────────
final List<List<Meal>> _week1 = [
  // Monday
  [
    Meal(time: '08:00 AM', name: 'Moong Dal Chilla', desc: 'Protein-rich moong dal crepe with mint chutney, sliced cucumber & a glass of buttermilk.', calories: 320, protein: '18g', carbs: '38g', fats: '10g'),
    Meal(time: '01:00 PM', name: 'Dal Chawal + Lauki Sabzi', desc: 'Yellow toor dal with steamed rice, bottle gourd sabzi, roti & salad.', calories: 480, protein: '16g', carbs: '72g', fats: '12g'),
    Meal(time: '07:30 PM', name: 'Palak Paneer + Roti', desc: 'Creamy spinach paneer curry with 2 whole wheat rotis & raita.', calories: 450, protein: '20g', carbs: '48g', fats: '18g'),
  ],
  // Tuesday
  [
    Meal(time: '08:00 AM', name: 'Poha with Peanuts', desc: 'Flattened rice tempered with mustard seeds, curry leaves, turmeric, peanuts & lemon.', calories: 340, protein: '10g', carbs: '52g', fats: '12g'),
    Meal(time: '01:00 PM', name: 'Rajma Chawal', desc: 'Kidney bean curry with steamed rice, onion-tomato salad & pickle.', calories: 520, protein: '18g', carbs: '78g', fats: '14g'),
    Meal(time: '07:30 PM', name: 'Mixed Veg Paratha + Curd', desc: 'Stuffed whole wheat paratha with mixed vegetables, served with fresh curd.', calories: 420, protein: '14g', carbs: '56g', fats: '16g'),
  ],
  // Wednesday
  [
    Meal(time: '08:00 AM', name: 'Idli Sambar', desc: '3 steamed rice-lentil idlis with sambar & coconut chutney.', calories: 310, protein: '12g', carbs: '54g', fats: '6g'),
    Meal(time: '01:00 PM', name: 'Chole + Roti + Salad', desc: 'Spiced chickpea curry with 2 rotis, cucumber-onion salad & lemon wedge.', calories: 500, protein: '20g', carbs: '68g', fats: '14g'),
    Meal(time: '07:30 PM', name: 'Bhindi Masala + Dal + Roti', desc: 'Dry okra stir-fry with moong dal & 2 whole wheat rotis.', calories: 430, protein: '16g', carbs: '58g', fats: '14g'),
  ],
  // Thursday
  [
    Meal(time: '08:00 AM', name: 'Sprouts Salad + Toast', desc: 'Mixed sprouts with onion, tomato, lemon dressing & whole wheat toast.', calories: 290, protein: '16g', carbs: '40g', fats: '8g'),
    Meal(time: '01:00 PM', name: 'Kadhi Chawal', desc: 'Besan-curd curry with pakoras, steamed rice & achar.', calories: 480, protein: '14g', carbs: '68g', fats: '16g'),
    Meal(time: '07:30 PM', name: 'Aloo Gobi + Roti + Raita', desc: 'Potato-cauliflower dry curry with 2 rotis & cucumber raita.', calories: 440, protein: '12g', carbs: '62g', fats: '16g'),
  ],
  // Friday
  [
    Meal(time: '08:00 AM', name: 'Upma + Coconut Chutney', desc: 'Semolina porridge with vegetables, tempered with mustard seeds & curry leaves.', calories: 330, protein: '10g', carbs: '50g', fats: '12g'),
    Meal(time: '01:00 PM', name: 'Matar Paneer + Jeera Rice', desc: 'Peas & paneer curry with cumin-tempered basmati rice & salad.', calories: 530, protein: '22g', carbs: '64g', fats: '18g'),
    Meal(time: '07:30 PM', name: 'Tinda Sabzi + Dal + Roti', desc: 'Apple gourd curry with masoor dal & 2 whole wheat rotis.', calories: 400, protein: '14g', carbs: '56g', fats: '12g'),
  ],
  // Saturday
  [
    Meal(time: '08:30 AM', name: 'Besan Ka Cheela', desc: 'Gram flour crepe with green chutney, sliced onion & a cup of masala chai.', calories: 310, protein: '14g', carbs: '36g', fats: '12g'),
    Meal(time: '01:00 PM', name: 'Baingan Bharta + Roti', desc: 'Smoky roasted eggplant mash with 2 rotis, dal fry & salad.', calories: 470, protein: '16g', carbs: '60g', fats: '16g'),
    Meal(time: '07:30 PM', name: 'Khichdi + Kadhi', desc: 'Comforting moong dal khichdi with light besan kadhi & papad.', calories: 420, protein: '16g', carbs: '64g', fats: '10g'),
  ],
  // Sunday
  [
    Meal(time: '09:00 AM', name: 'Aloo Paratha + Curd', desc: '2 stuffed potato parathas with fresh curd, pickle & butter.', calories: 440, protein: '12g', carbs: '58g', fats: '18g'),
    Meal(time: '01:30 PM', name: 'Paneer Butter Masala + Naan', desc: 'Rich paneer curry with 1 whole wheat naan & green salad.', calories: 560, protein: '22g', carbs: '60g', fats: '24g'),
    Meal(time: '07:30 PM', name: 'Vegetable Dalia', desc: 'Broken wheat porridge with mixed vegetables, tempered with cumin & ghee.', calories: 360, protein: '12g', carbs: '56g', fats: '10g'),
  ],
];

// ─── WEEK 2 ──────────────────────────────────────────────
final List<List<Meal>> _week2 = [
  // Monday
  [
    Meal(time: '08:00 AM', name: 'Ragi Dosa + Chutney', desc: 'Finger millet dosa with tomato chutney & a glass of warm turmeric milk.', calories: 300, protein: '10g', carbs: '48g', fats: '8g'),
    Meal(time: '01:00 PM', name: 'Arhar Dal + Rice + Sabzi', desc: 'Pigeon pea dal with rice, seasonal green beans sabzi & roti.', calories: 490, protein: '16g', carbs: '74g', fats: '12g'),
    Meal(time: '07:30 PM', name: 'Chana Masala + Roti', desc: 'Spiced chickpea curry with 2 whole wheat rotis & onion salad.', calories: 440, protein: '18g', carbs: '60g', fats: '14g'),
  ],
  // Tuesday
  [
    Meal(time: '08:00 AM', name: 'Sabudana Khichdi', desc: 'Tapioca pearls stir-fried with peanuts, potato & curry leaves.', calories: 350, protein: '8g', carbs: '58g', fats: '12g'),
    Meal(time: '01:00 PM', name: 'Sambar Rice + Papad', desc: 'Lentil-vegetable sambar over rice with roasted papad & pickle.', calories: 470, protein: '16g', carbs: '72g', fats: '10g'),
    Meal(time: '07:30 PM', name: 'Tofu Bhurji + Roti', desc: 'Scrambled tofu with onion, tomato & spices, served with 2 rotis.', calories: 400, protein: '22g', carbs: '42g', fats: '16g'),
  ],
  // Wednesday
  [
    Meal(time: '08:00 AM', name: 'Oats Uttapam', desc: 'Oats-based uttapam with onion, tomato topping & green chutney.', calories: 300, protein: '12g', carbs: '44g', fats: '10g'),
    Meal(time: '01:00 PM', name: 'Dal Makhani + Rice', desc: 'Creamy black lentil dal with steamed rice, salad & raita.', calories: 530, protein: '18g', carbs: '70g', fats: '18g'),
    Meal(time: '07:30 PM', name: 'Stuffed Capsicum + Roti', desc: 'Bell peppers stuffed with paneer-peas mixture, served with 2 rotis.', calories: 420, protein: '16g', carbs: '50g', fats: '16g'),
  ],
  // Thursday
  [
    Meal(time: '08:00 AM', name: 'Multigrain Paratha + Curd', desc: 'Paratha made with wheat, bajra & jowar flour, served with fresh curd.', calories: 380, protein: '12g', carbs: '52g', fats: '14g'),
    Meal(time: '01:00 PM', name: 'Palak Dal + Jeera Rice', desc: 'Spinach-lentil curry with cumin rice & cucumber-carrot salad.', calories: 460, protein: '18g', carbs: '66g', fats: '12g'),
    Meal(time: '07:30 PM', name: 'Mushroom Matar + Roti', desc: 'Mushroom & peas curry with 2 whole wheat rotis & mint raita.', calories: 410, protein: '16g', carbs: '52g', fats: '14g'),
  ],
  // Friday
  [
    Meal(time: '08:00 AM', name: 'Vegetable Dalia', desc: 'Broken wheat porridge with carrots, peas & beans, tempered with ghee.', calories: 310, protein: '10g', carbs: '52g', fats: '8g'),
    Meal(time: '01:00 PM', name: 'Lobia Curry + Roti', desc: 'Black-eyed pea curry with 2 rotis, onion-tomato salad & pickle.', calories: 490, protein: '20g', carbs: '68g', fats: '14g'),
    Meal(time: '07:30 PM', name: 'Methi Thepla + Sabzi', desc: 'Fenugreek flatbread with dry potato sabzi & curd.', calories: 400, protein: '12g', carbs: '54g', fats: '14g'),
  ],
  // Saturday
  [
    Meal(time: '08:30 AM', name: 'Pesarattu + Ginger Chutney', desc: 'Green moong dal crepe with ginger-garlic chutney & upma filling.', calories: 320, protein: '16g', carbs: '42g', fats: '10g'),
    Meal(time: '01:00 PM', name: 'Veg Biryani + Raita', desc: 'Fragrant vegetable biryani with mixed veg raita & boiled egg (optional).', calories: 540, protein: '14g', carbs: '78g', fats: '16g'),
    Meal(time: '07:30 PM', name: 'Moong Dal Soup + Khichdi', desc: 'Light moong dal soup followed by simple rice-dal khichdi with ghee.', calories: 380, protein: '16g', carbs: '58g', fats: '10g'),
  ],
  // Sunday
  [
    Meal(time: '09:00 AM', name: 'Masala Dosa + Sambar', desc: 'Crispy rice-lentil crepe with spiced potato filling, sambar & 3 chutneys.', calories: 420, protein: '12g', carbs: '62g', fats: '14g'),
    Meal(time: '01:30 PM', name: 'Shahi Paneer + Tandoori Roti', desc: 'Rich paneer curry with 2 tandoori rotis & green salad.', calories: 550, protein: '24g', carbs: '52g', fats: '26g'),
    Meal(time: '07:30 PM', name: 'Vegetable Soup + Toast', desc: 'Mixed vegetable soup with whole wheat garlic toast & fruit.', calories: 280, protein: '8g', carbs: '42g', fats: '8g'),
  ],
];

// ─── WEEK 3 ──────────────────────────────────────────────
final List<List<Meal>> _week3 = [
  // Monday
  [
    Meal(time: '08:00 AM', name: 'Sattu Paratha + Pickle', desc: 'Roasted gram flour stuffed paratha with mango pickle & curd.', calories: 380, protein: '16g', carbs: '50g', fats: '14g'),
    Meal(time: '01:00 PM', name: 'Moong Dal + Rice + Sabzi', desc: 'Yellow moong dal with rice, seasonal cabbage sabzi & roti.', calories: 470, protein: '18g', carbs: '68g', fats: '12g'),
    Meal(time: '07:30 PM', name: 'Paneer Tikka + Salad', desc: 'Grilled paneer cubes with bell peppers, onion & mint chutney.', calories: 400, protein: '24g', carbs: '28g', fats: '22g'),
  ],
  // Tuesday
  [
    Meal(time: '08:00 AM', name: 'Bajra Roti + Jaggery + Ghee', desc: 'Pearl millet roti with a dollop of ghee & jaggery, served with buttermilk.', calories: 360, protein: '10g', carbs: '54g', fats: '14g'),
    Meal(time: '01:00 PM', name: 'Masoor Dal + Roti + Bhindi', desc: 'Red lentil dal with rotis, crispy okra fry & salad.', calories: 490, protein: '18g', carbs: '66g', fats: '14g'),
    Meal(time: '07:30 PM', name: 'Paneer Paratha + Raita', desc: 'Paneer-stuffed whole wheat paratha with boondi raita.', calories: 460, protein: '20g', carbs: '52g', fats: '18g'),
  ],
  // Wednesday
  [
    Meal(time: '08:00 AM', name: 'Jowar Flakes Porridge', desc: 'Sorghum flakes cooked in warm milk with cardamom, nuts & honey.', calories: 310, protein: '10g', carbs: '48g', fats: '10g'),
    Meal(time: '01:00 PM', name: 'Dum Aloo + Puri', desc: 'Baby potato curry with 3 whole wheat puris & mixed pickle.', calories: 520, protein: '12g', carbs: '68g', fats: '22g'),
    Meal(time: '07:30 PM', name: 'Sprouts Tikki + Soup', desc: 'Pan-fried sprout patties with tomato soup & whole wheat bread.', calories: 380, protein: '18g', carbs: '46g', fats: '14g'),
  ],
  // Thursday
  [
    Meal(time: '08:00 AM', name: 'Dahi Vada (Light)', desc: 'Lentil fritters soaked in spiced yogurt with tamarind chutney.', calories: 320, protein: '14g', carbs: '42g', fats: '12g'),
    Meal(time: '01:00 PM', name: 'Veg Pulao + Raita', desc: 'Fragrant vegetable pulao with mint raita & papad.', calories: 480, protein: '12g', carbs: '72g', fats: '14g'),
    Meal(time: '07:30 PM', name: 'Lauki Chana Dal + Roti', desc: 'Bottle gourd with split chickpea dal & 2 whole wheat rotis.', calories: 410, protein: '16g', carbs: '58g', fats: '12g'),
  ],
  // Friday
  [
    Meal(time: '08:00 AM', name: 'Rava Idli + Sambar', desc: 'Semolina idlis with sambar & coconut chutney.', calories: 300, protein: '10g', carbs: '50g', fats: '6g'),
    Meal(time: '01:00 PM', name: 'Toor Dal + Rice + Aloo Matar', desc: 'Pigeon pea dal with rice, potato-peas dry curry & salad.', calories: 510, protein: '16g', carbs: '76g', fats: '14g'),
    Meal(time: '07:30 PM', name: 'Vegetable Stew + Appam', desc: 'South Indian coconut milk vegetable stew with 2 appams.', calories: 420, protein: '10g', carbs: '60g', fats: '16g'),
  ],
  // Saturday
  [
    Meal(time: '08:30 AM', name: 'Nachni Porridge', desc: 'Ragi porridge with warm milk, dates & almonds.', calories: 330, protein: '12g', carbs: '52g', fats: '10g'),
    Meal(time: '01:00 PM', name: 'Chole Bhature (Baked)', desc: 'Chickpea curry with baked whole wheat bhature & onion salad.', calories: 530, protein: '18g', carbs: '72g', fats: '18g'),
    Meal(time: '07:30 PM', name: 'Palak Soup + Khichdi', desc: 'Spinach soup followed by dal-rice khichdi with pickle.', calories: 380, protein: '14g', carbs: '56g', fats: '10g'),
  ],
  // Sunday
  [
    Meal(time: '09:00 AM', name: 'Curd Rice + Pickle', desc: 'Comforting curd rice with tempering of curry leaves & mustard seeds, with mango pickle.', calories: 350, protein: '10g', carbs: '56g', fats: '10g'),
    Meal(time: '01:30 PM', name: 'Malai Kofta + Pulao', desc: 'Paneer-potato kofta in creamy gravy with vegetable pulao.', calories: 580, protein: '18g', carbs: '66g', fats: '26g'),
    Meal(time: '07:30 PM', name: 'Moong Dal Halwa (Small) + Roti', desc: 'Light dinner with 1 roti, dal & a small portion of moong dal halwa.', calories: 420, protein: '14g', carbs: '60g', fats: '14g'),
  ],
];

// ─── WEEK 4 ──────────────────────────────────────────────
final List<List<Meal>> _week4 = [
  // Monday
  [
    Meal(time: '08:00 AM', name: 'Dhokla + Green Chutney', desc: 'Steamed gram flour cake with mustard tempering & coriander chutney.', calories: 280, protein: '12g', carbs: '40g', fats: '8g'),
    Meal(time: '01:00 PM', name: 'Urad Dal + Rice + Karela', desc: 'Black gram dal with rice, bitter gourd sabzi & roti.', calories: 470, protein: '18g', carbs: '66g', fats: '14g'),
    Meal(time: '07:30 PM', name: 'Veg Kathi Roll', desc: 'Whole wheat roll with paneer-capsicum filling, mint mayo & salad.', calories: 420, protein: '18g', carbs: '48g', fats: '16g'),
  ],
  // Tuesday
  [
    Meal(time: '08:00 AM', name: 'Rava Upma + Fruits', desc: 'Semolina upma with peanuts & vegetables, served with seasonal fruit.', calories: 340, protein: '10g', carbs: '52g', fats: '12g'),
    Meal(time: '01:00 PM', name: 'Mix Dal + Roti + Gajar Sabzi', desc: 'Five-lentil mix dal with rotis, carrot stir-fry & salad.', calories: 480, protein: '20g', carbs: '64g', fats: '14g'),
    Meal(time: '07:30 PM', name: 'Paneer Bhurji + Paratha', desc: 'Scrambled paneer with onion & tomato, served with 1 paratha.', calories: 440, protein: '22g', carbs: '44g', fats: '20g'),
  ],
  // Wednesday
  [
    Meal(time: '08:00 AM', name: 'Muesli + Curd + Fruits', desc: 'Homemade muesli with fresh curd, banana slices & honey drizzle.', calories: 320, protein: '12g', carbs: '50g', fats: '10g'),
    Meal(time: '01:00 PM', name: 'Aloo Matar + Puri + Dal', desc: 'Potato-peas curry with 3 whole wheat puris & light dal.', calories: 520, protein: '14g', carbs: '72g', fats: '18g'),
    Meal(time: '07:30 PM', name: 'Vegetable Tikki + Soup', desc: 'Pan-fried mixed veg tikkis with tomato-lentil soup.', calories: 380, protein: '14g', carbs: '50g', fats: '14g'),
  ],
  // Thursday
  [
    Meal(time: '08:00 AM', name: 'Khandvi', desc: 'Rolled gram flour snack with coconut-mustard tempering & chai.', calories: 280, protein: '12g', carbs: '36g', fats: '10g'),
    Meal(time: '01:00 PM', name: 'Chana Dal + Rice + Sabzi', desc: 'Split chickpea dal with rice, seasonal pumpkin sabzi & roti.', calories: 490, protein: '18g', carbs: '70g', fats: '14g'),
    Meal(time: '07:30 PM', name: 'Dahi Wale Aloo + Roti', desc: 'Yogurt-based potato curry with 2 whole wheat rotis.', calories: 430, protein: '12g', carbs: '62g', fats: '14g'),
  ],
  // Friday
  [
    Meal(time: '08:00 AM', name: 'Pongal + Sambar', desc: 'South Indian rice-lentil porridge with sambar & coconut chutney.', calories: 350, protein: '12g', carbs: '56g', fats: '10g'),
    Meal(time: '01:00 PM', name: 'Rajma + Roti + Raita', desc: 'Kidney bean curry with rotis & boondi raita.', calories: 500, protein: '20g', carbs: '68g', fats: '14g'),
    Meal(time: '07:30 PM', name: 'Palak Paratha + Curd', desc: 'Spinach-stuffed whole wheat paratha with fresh curd.', calories: 400, protein: '14g', carbs: '52g', fats: '14g'),
  ],
  // Saturday
  [
    Meal(time: '08:30 AM', name: 'Misal Pav', desc: 'Sprouted moth bean curry with pav, farsan & lemon wedge.', calories: 380, protein: '16g', carbs: '52g', fats: '12g'),
    Meal(time: '01:00 PM', name: 'Kadhi Pakora + Rice', desc: 'Yogurt-gram flour curry with onion pakoras over steamed rice.', calories: 500, protein: '14g', carbs: '70g', fats: '16g'),
    Meal(time: '07:30 PM', name: 'Sweet Potato Chaat + Roti', desc: 'Roasted sweet potato salad with spices, served with 1 roti & dal.', calories: 400, protein: '12g', carbs: '60g', fats: '12g'),
  ],
  // Sunday
  [
    Meal(time: '09:00 AM', name: 'Uttapam + Chutney', desc: 'Thick rice-lentil pancake topped with vegetables & served with 3 chutneys.', calories: 360, protein: '10g', carbs: '56g', fats: '10g'),
    Meal(time: '01:30 PM', name: 'Dal Baati Churma', desc: 'Rajasthani baked wheat balls with panchmel dal & churma (small portion).', calories: 580, protein: '18g', carbs: '74g', fats: '22g'),
    Meal(time: '07:30 PM', name: 'Light Khichdi + Papad', desc: 'Simple moong dal-rice khichdi with ghee, papad & pickle.', calories: 360, protein: '14g', carbs: '56g', fats: '10g'),
  ],
];

/// Master list of all 4 weeks
final List<List<List<Meal>>> _allWeeks = [_week1, _week2, _week3, _week4];
