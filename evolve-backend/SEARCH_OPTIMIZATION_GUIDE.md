# Food Search Performance Optimization Guide

## Backend Optimizations Implemented

### 1. **Database Level Optimizations**

- ✅ **Trigram Similarity**: Replaced slow `icontains` with PostgreSQL `%%` operator
- ✅ **Weighted Search Vectors**: Product names (A), brands (B), categories (C), ingredients (D)
- ✅ **Functional Indexes**: Added `text_pattern_ops` indexes for prefix searches
- ✅ **Composite Indexes**: Combined popularity + name indexes for better sorting

### 2. **Query Optimizations**

- ✅ **Explicit Index Usage**: Using `search_vector__match` instead of `search_vector=`
- ✅ **Trigram Threshold**: Lowered to 0.2 for more comprehensive results
- ✅ **Smart Fallback**: Full-text search → Trigram similarity → No more slow `icontains`

### 3. **Caching Improvements**

- ✅ **Popular Foods Cache**: Pre-cached suggestions for empty queries
- ✅ **Sliding Window Rate Limiting**: More intelligent rate limiting (15/min)
- ✅ **Extended Cache Times**: 20 minutes for search, 1 hour for popular foods

## Frontend Integration (iOS SwiftUI)

### **Critical: Implement Debouncing**

```swift
// Add to your search ViewModel
import Combine

class FoodSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [FoodProduct] = []
    @Published var isLoading = false

    private var cancellables = Set<AnyCancellable>()
    private let debounceTime: Double = 0.3 // 300ms debounce

    init() {
        // Debounce search queries
        $searchText
            .debounce(for: .milliseconds(Int(debounceTime * 1000)), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                if searchText.isEmpty {
                    self?.loadPopularFoods() // Use the empty-query endpoint
                } else if searchText.count >= 2 {
                    self?.performSearch(query: searchText)
                }
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) {
        // Your existing search API call
        // Uses: /api/food-products/search/?query=\(query)
    }

    private func loadPopularFoods() {
        // Call search endpoint with no query to get popular foods
        // Uses: /api/food-products/search/ (no query parameter)
    }
}
```

### **Autocomplete for Type-Ahead**

```swift
// For instant autocomplete dropdown
class AutocompleteViewModel: ObservableObject {
    @Published var suggestions: [FoodSuggestion] = []

    private var autocompleteTimer: Timer?

    func updateSuggestions(for query: String) {
        autocompleteTimer?.invalidate()

        guard query.count >= 2 else {
            suggestions = []
            return
        }

        // Shorter debounce for autocomplete (150ms)
        autocompleteTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
            self.fetchAutocomplete(query: query)
        }
    }

    private func fetchAutocomplete(query: String) {
        // Uses: /api/food-products/autocomplete/?query=\(query)
        // Returns minimal data: id, name, brand
    }
}
```

## Performance Testing

### **Run Diagnostics**

```bash
# Check search vector coverage
python manage.py check_search_performance

# Apply new optimizations
python manage.py migrate

# Repopulate with weighted vectors
python manage.py populate_search_vectors --max-batches 100
```

### **Expected Performance**

- **Empty Query**: < 50ms (cached popular foods)
- **Autocomplete**: < 100ms (prefix matching)
- **Full Search**: < 300ms (trigram similarity)
- **Cached Results**: < 10ms

## API Endpoints Overview

| Endpoint                                | Purpose       | Cache Time | Rate Limit |
| --------------------------------------- | ------------- | ---------- | ---------- |
| `/api/food-products/search/`            | Main search   | 20 min     | 15/min     |
| `/api/food-products/autocomplete/`      | Type-ahead    | 20 min     | No limit   |
| `/api/food-products/search/` (no query) | Popular foods | 1 hour     | No limit   |

## Next Steps if Still Slow

### **Option A: Elasticsearch Integration**

If PostgreSQL optimizations aren't enough:

```python
# Install: pip install elasticsearch-dsl django-elasticsearch-dsl
# Add to settings.py:
ELASTICSEARCH_DSL = {
    'default': {
        'hosts': 'localhost:9200'
    },
}

# Create search document:
from elasticsearch_dsl import Document, Text, Keyword, Integer

class FoodProductDocument(Document):
    product_name = Text(analyzer='standard')
    brands = Text(analyzer='standard')

    class Index:
        name = 'food_products'
```

### **Option B: Algolia/MeiliSearch**

For instant search as a service:

- Sub-10ms response times
- Built-in typo tolerance
- Geo-distributed edge locations

## Monitoring

Add these metrics to track search performance:

- Average search response time
- Cache hit rate
- Most searched terms
- Failed searches (no results)

## Troubleshooting

### **If searches are still slow:**

1. Check `EXPLAIN ANALYZE` output for sequential scans
2. Verify search vector coverage is 100%
3. Ensure trigram indexes exist
4. Monitor cache hit rates

### **If getting too many/few results:**

- Adjust trigram threshold: `SELECT set_limit(0.1);` (more results) or `SELECT set_limit(0.3);` (fewer results)
- Modify search vector weights in the trigger function
