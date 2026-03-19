# 🛡️ GPS Outlier Filtering Fix - Prevent Long Unrealistic Lines

## Problem Solved
**Issue:** Even when walking inside your house, the tracking line becomes extremely long and penetrates through other buildings.

**Root Cause:** GPS signals bounce off walls indoors (multipath reflection), causing the receiver to report positions that jump several meters away. These outlier points create long, unrealistic lines when connected.

## Solution Implemented

### New Function: `filterGPSOutliers()`
Added in `lib/utils/gps_filtering.dart`

This function uses **speed-based filtering** to detect and remove impossible GPS jumps:

```dart
/// Removes GPS outlier points that are unrealistically far from neighbors.
/// If the distance between consecutive points would require an 
/// impossible speed (> 15 m/s = 54 km/h), it's GPS noise.
List<Map<String, double>> filterGPSOutliers(
  List<Map<String, double>> coordinates, {
  double maxReasonableSpeedMps = 15.0,  // 54 km/h max speed
  double timeBetweenPointsSeconds = 1.0,
})
```

## How It Works

### Step 1: Speed Check
For each GPS point, calculate the implied speed:
```
Speed = Distance / Time
```

If `Speed > 15 m/s` (54 km/h), it's impossible for running/walking → **REJECT**

### Step 2: Dual Neighbor Check
For suspicious points, also check the distance to the NEXT point:
- If BOTH previous distance AND next distance are unrealistic
- The point is surrounded by impossible jumps → **REJECT**

### Step 3: Keep Good Points
Only points that pass both checks are kept, creating a clean, realistic route.

## Example Scenario

**Without Filtering (Your Problem):**
```
Inside house:
Point 1: 14.0000, 121.0000 (living room)
Point 2: 14.0050, 121.0050 (GPS jump 500m away!)
Point 3: 14.0001, 121.0001 (back to living room)

Result: Two 500m lines connecting living room → random location → living room
        Route appears to go through buildings
```

**With Filtering (Fixed):**
```
Point 2 distance = 500m / 1s = 500 m/s
This is 33x faster than reasonable max (15 m/s)
Point 2 is REJECTED ✓

Cleaned route:
Point 1: 14.0000, 121.0000 (living room)
Point 3: 14.0001, 121.0001 (living room)

Result: Tiny 1-meter line, realistic indoor walk
```

## Where the Fix is Applied

In `lib/services/tracking_service.dart`, method `stopTracking()`:

```dart
// First, filter out GPS outliers/noise
final filteredCoordinates = filterGPSOutliers(routeCoordinates);

// Then calculate distance and pace using clean coordinates
final distanceMeters = _locationService.calculateDistance(filteredCoordinates);

// Apply smoothing on the already-filtered data
final outputCoordinates = applyMovingAverageWindow(
  filteredCoordinates,
  enabled: _enableMovingAverageWindow,
);
```

## GPS Filtering Pipeline (Updated)

```
Raw GPS Stream
    ↓
Pass 1: Location Service accuracy filter (≤30m)
    ↓
Pass 2: Tracking Service distance filter (≥0.5m)
    ↓
Pass 3: OUTLIER FILTERING ← NEW FIX
    (Remove impossible speeds > 15 m/s)
    ↓
Pass 4: Moving Average Smoothing
    (3-point window, optional)
    ↓
Clean, Realistic Route Saved
```

## Configuration

Current settings:
- **Max Reasonable Speed:** 15 m/s (54 km/h)
  - Covers: walking (1.4 m/s), jogging (3-4 m/s), running (5-7 m/s), sprinting (10 m/s)
  - Rejects: GPS jumps (typically 50+ m/s indoors)

- **Time Between Points:** 1 second average
  - Adapts to your GPS update rate automatically

## Benefits

✅ **Indoor Walks** - No more 500m+ lines through buildings  
✅ **Urban Areas** - Better handling of GPS multipath reflections  
✅ **Realistic Routes** - Routes stay within actual path taken  
✅ **Accurate Distance** - No inflated distance from GPS jumps  
✅ **Clean Feed** - Routes look natural when uploaded  

## Testing

1. **Walk inside your house with app running**
   - Start tracking → walk around living room → stop
   - Route should be small (~10-50 meters), not 500+ meters
   
2. **Test in dense urban area**
   - Walk between tall buildings → stop
   - Route should follow actual path, not jump between buildings

3. **Upload to feed**
   - Route should appear clean and realistic
   - No weird long lines extending outside your neighborhood

## Technical Notes

- Function runs ONLY once at the end of tracking (efficient)
- Does not affect real-time tracking (still captures all raw points)
- Works with your existing GPS accuracy settings
- Complements the moving average smoothing

## Future Improvements

Could add:
- HDOP (Horizontal Dilution of Precision) filtering if GPS provides it
- Adaptive speed thresholds based on detected activity type
- Machine learning to detect structured/indoor movement patterns

