# 🍺 Alcohol Tracking Feature - Complete Integration Guide

## Overview

The alcohol tracking feature allows users to log alcoholic beverages as part of their nutrition tracking, with dedicated alcohol cards and category-based browsing. This feature integrates seamlessly with the existing food tracking system.

## 📊 Dataset Summary

- **Total Beverages**: 435 alcoholic beverages
- **Categories**: 6 distinct categories with icons
- **Coverage**: Comprehensive US market beverages

### Category Breakdown:

- 🍺 **Beer (bottle/can or pint)**: 143 beverages
- 🍷 **Wine (standard still wine)**: 100 beverages
- 🥂 **Champagne/Sparkling wine (flute)**: 47 beverages
- 🍷 **Fortified wine/Dessert wine (small glass)**: 59 beverages
- 🥃 **Shot of liquor (straight spirit)**: 44 beverages
- 🍸 **Mixed drink/Cocktail**: 42 beverages

---

## 🚀 API Endpoints

### Base URL: `/api/`

### 1. Get All Alcohol Categories

```http
GET /api/alcoholic-beverages/categories/
```

**Response:**

```json
{
  "categories": [
    {
      "key": "beer",
      "name": "Beer (bottle/can or pint)",
      "icon": "🍺",
      "count": 143
    },
    {
      "key": "wine",
      "name": "Glass of wine",
      "icon": "🍷",
      "count": 100
    },
    {
      "key": "champagne",
      "name": "Champagne / sparkling wine (flute)",
      "icon": "🥂",
      "count": 47
    },
    {
      "key": "fortified_wine",
      "name": "Fortified wine / dessert wine (small glass)",
      "icon": "🍷",
      "count": 59
    },
    {
      "key": "liquor",
      "name": "Shot of liquor (straight spirit)",
      "icon": "🥃",
      "count": 44
    },
    {
      "key": "cocktail",
      "name": "Mixed drink / Cocktail",
      "icon": "🍸",
      "count": 42
    }
  ]
}
```

### 2. Search Alcoholic Beverages

```http
GET /api/alcoholic-beverages/search/?q={query}&category={category}&limit={limit}
```

**Parameters:**

- `q` (required): Search query (minimum 2 characters)
- `category` (optional): Filter by category key
- `limit` (optional): Number of results (default: 25)

**Example:**

```http
GET /api/alcoholic-beverages/search/?q=bud&category=beer&limit=10
```

**Response:**

```json
{
  "results": [
    {
      "_id": "beer_001",
      "name": "Bud Light",
      "brand": "Anheuser-Busch",
      "category": "beer",
      "category_display": "Beer (bottle/can or pint)",
      "category_icon": "🍺",
      "alcohol_content_percent": 4.2,
      "calories": 110,
      "carbs_grams": 6.6,
      "alcohol_grams": 14.0,
      "serving_size_ml": 355,
      "serving_description": "12 oz bottle/can",
      "popularity_score": 100
    }
  ],
  "count": 1
}
```

### 3. Get Beverages by Category

```http
GET /api/alcoholic-beverages/category/{category_key}/?limit={limit}&offset={offset}
```

**Example:**

```http
GET /api/alcoholic-beverages/category/wine/?limit=20
```

**Response:**

```json
{
  "results": [
    {
      "_id": "wine_001",
      "name": "Cabernet Sauvignon (Napa Valley)",
      "brand": "Generic",
      "category": "wine",
      "category_display": "Glass of wine",
      "category_icon": "🍷",
      "alcohol_content_percent": 14.5,
      "calories": 130,
      "carbs_grams": 4.0,
      "alcohol_grams": 14.0,
      "serving_size_ml": 148,
      "serving_description": "5 oz glass",
      "popularity_score": 100
    }
  ],
  "count": 100,
  "next": "http://localhost:8000/api/alcoholic-beverages/category/wine/?limit=20&offset=20",
  "previous": null
}
```

### 4. Get Beverage Details

```http
GET /api/alcoholic-beverages/{beverage_id}/
```

**Example:**

```http
GET /api/alcoholic-beverages/beer_001/
```

**Response:**

```json
{
  "_id": "beer_001",
  "name": "Bud Light",
  "brand": "Anheuser-Busch",
  "category": "beer",
  "category_display": "Beer (bottle/can or pint)",
  "category_icon": "🍺",
  "alcohol_content_percent": 4.2,
  "calories": 110,
  "carbs_grams": 6.6,
  "alcohol_grams": 14.0,
  "serving_size_ml": 355,
  "serving_description": "12 oz bottle/can",
  "description": "Light beer",
  "popularity_score": 100,
  "created_at": "2024-01-20T10:30:00Z",
  "updated_at": "2024-01-20T10:30:00Z"
}
```

### 5. Log Alcoholic Beverage (Create Food Entry)

```http
POST /api/food-entries/
```

**Request Body:**

```json
{
  "user": 1,
  "alcoholic_beverage": "beer_001",
  "food_name": "Bud Light",
  "serving_unit": "standard drink",
  "quantity": 1,
  "meal_type": "dinner"
}
```

**Response:**

```json
{
  "id": 123,
  "user": 1,
  "alcoholic_beverage": "beer_001",
  "food_name": "Bud Light",
  "serving_unit": "standard drink",
  "quantity": 1,
  "calories": 110,
  "carbs": 6.6,
  "alcohol_grams": 14.0,
  "standard_drinks": 1.0,
  "alcohol_category": "beer",
  "meal_type": "dinner",
  "date_consumed": "2024-01-20",
  "created_at": "2024-01-20T15:30:00Z"
}
```

### 6. Get Daily Calorie Tracker (includes alcohol totals)

```http
GET /api/daily-calorie-tracker/?user={user_id}&date={date}
```

**Response includes new alcohol fields:**

```json
{
  "id": 456,
  "user": 1,
  "date": "2024-01-20",
  "total_calories": 2150,
  "carbs_grams": 245.6,
  "alcohol_grams": 28.0,
  "standard_drinks": 2.0,
  "food_entries": [
    {
      "id": 123,
      "food_name": "Bud Light",
      "alcoholic_beverage": "beer_001",
      "alcohol_category": "beer",
      "calories": 110,
      "standard_drinks": 1.0
    }
  ]
}
```

---

## 📱 Frontend Integration Guide

### User Journey Flow

1. **Alcohol Card Display**

   - Show alcohol card on nutrition tracking screen
   - Display category icons for beverages tracked today
   - Show total standard drinks consumed

2. **Category Selection**

   - When user taps alcohol card, show 6 category icons
   - Each icon shows category name and emoji
   - Tap category to browse beverages

3. **Beverage Browse/Search**

   - List view showing beverages in selected category
   - Search functionality within category
   - Sort by popularity score (highest first)

4. **Beverage Details**

   - Pop-up showing calories, carbs, alcohol content
   - "Add" button to log the beverage
   - Serving size information

5. **Logging**
   - Create FoodEntry with alcoholic_beverage reference
   - Always use "standard drink" as serving_unit
   - Update daily totals automatically

### Key Frontend Implementation Notes

#### Alcohol Card Logic

```swift
// Display logic for alcohol card icons
func getAlcoholCardIcons(dailyTracker: DailyCalorieTracker) -> [String] {
    let alcoholEntries = dailyTracker.foodEntries.filter { $0.alcoholicBeverage != nil }
    let categories = alcoholEntries.compactMap { $0.alcoholCategory }
    let uniqueCategories = Array(Set(categories))

    return uniqueCategories.map { category in
        switch category {
        case "beer": return "🍺"
        case "wine": return "🍷"
        case "champagne": return "🥂"
        case "fortified_wine": return "🍷"
        case "liquor": return "🥃"
        case "cocktail": return "🍸"
        default: return "🍹"
        }
    }
}
```

#### Standard Drinks Display

```swift
// In diary entry, show "1 standard drink" on the right
func formatDiaryEntry(entry: FoodEntry) -> String {
    if entry.alcoholicBeverage != nil {
        return "\(entry.calories) cal • \(entry.standardDrinks) standard drink"
    }
    return "\(entry.calories) cal • \(entry.servingUnit)"
}
```

#### Search Implementation

```swift
func searchAlcoholicBeverages(query: String, category: String? = nil) async {
    var urlComponents = URLComponents(string: "\(baseURL)/alcoholic-beverages/search/")!
    urlComponents.queryItems = [
        URLQueryItem(name: "q", value: query),
        URLQueryItem(name: "limit", value: "25")
    ]

    if let category = category {
        urlComponents.queryItems?.append(URLQueryItem(name: "category", value: category))
    }

    // Make API call...
}
```

---

## 🔄 Data Flow

### 1. User Tracks Alcohol

```
User Selects Beverage → POST /api/food-entries/ → Creates FoodEntry with:
├── alcoholic_beverage: "beer_001"
├── food_name: "Bud Light"
├── serving_unit: "standard drink"
├── quantity: 1
├── calories: 110 (from AlcoholicBeverage)
├── carbs: 6.6 (from AlcoholicBeverage)
├── alcohol_grams: 14.0 (always 14g per standard drink)
├── standard_drinks: 1.0
└── alcohol_category: "beer"
```

### 2. Daily Totals Update

```
FoodEntry.save() → DailyCalorieTracker.update_totals() → Aggregates:
├── total_calories: sum(all food + alcohol calories)
├── carbs_grams: sum(all food + alcohol carbs)
├── alcohol_grams: sum(alcohol_grams from alcohol entries)
└── standard_drinks: sum(standard_drinks from alcohol entries)
```

### 3. Macro Integration

- Alcohol calories count toward daily calorie goal
- Alcohol carbs count toward daily carb total
- Alcohol tracking separate from macros (protein/fat)

---

## 🧪 Testing Examples

### Test Search Functionality

```bash
curl -X GET "http://localhost:8000/api/alcoholic-beverages/search/?q=wine&category=wine&limit=5"
```

### Test Category Browse

```bash
curl -X GET "http://localhost:8000/api/alcoholic-beverages/category/beer/?limit=10"
```

### Test Alcohol Logging

```bash
curl -X POST "http://localhost:8000/api/food-entries/" \
  -H "Content-Type: application/json" \
  -d '{
    "user": 1,
    "alcoholic_beverage": "beer_001",
    "food_name": "Bud Light",
    "serving_unit": "standard drink",
    "quantity": 1,
    "meal_type": "dinner"
  }'
```

---

## ⚠️ Important Notes

### Standard Drink Definition

- **1 standard drink = 14 grams of pure alcohol**
- All beverages in dataset represent 1 standard drink
- Serving sizes calibrated to standard drink equivalents

### Data Integrity

- `food_name` auto-set from `AlcoholicBeverage.name` when logging alcohol
- `serving_unit` always "standard drink" for alcohol entries
- `alcohol_grams` always 14.0 for alcohol entries
- `standard_drinks` always equals `quantity` for alcohol entries

### Frontend Requirements

- Alcohol card must show category icons of tracked beverages
- Diary entries show "standard drink" instead of serving units
- Category icons clickable to browse beverages
- Search within categories for better UX

---

## 🚀 Deployment Status

✅ **Database Models**: Created and migrated  
✅ **API Endpoints**: Implemented and tested  
✅ **Dataset**: 435 beverages populated  
✅ **Admin Interface**: Configured for management  
✅ **Documentation**: Complete integration guide

**Status: Ready for Frontend Integration** 🎉

---

## 📞 Support

For technical questions about the alcohol tracking integration:

- Check API endpoint responses match expected formats
- Verify alcohol_grams and standard_drinks calculations
- Test category icon display logic
- Validate diary entry formatting

The system is production-ready and fully integrated with existing nutrition tracking! 🍺🍷🥂
