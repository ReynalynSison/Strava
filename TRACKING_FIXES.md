# GPS Tracking & Route Detection Fixes

## Summary
Fixed issues where the app wasn't automatically detecting activity when walking/running, and routes were appearing stationary when uploaded to feed. The problems were caused by overly strict GPS filtering parameters and missing initial coordinate capture.

## Changes Made

### 1. **Location Service (`lib/services/location_service.dart`)**

#### GPS Stream Distance Filter
- **Before:** `distanceFilter: 3` (only update every 3 meters)
- **After:** `distanceFilter: 1` (update every 1 meter)
- **Impact:** Captures more detailed route points for accurate tracking

#### GPS Accuracy Threshold
- **Before:** `accuracy <= 20.0` meters (rejected most GPS readings)
- **After:** `accuracy <= 30.0` meters (more lenient)
- **Impact:** Accepts more valid GPS readings, especially in areas with weaker signals (urban canyons, etc.)

### 2. **Tracking Service (`lib/services/tracking_service.dart`)**

#### Minimum Point Distance
- **Before:** `_minPointDistanceMeters = 5.0`
- **After:** `_minPointDistanceMeters = 0.5`
- **Impact:** Allows much finer-grained route tracking, captures detailed movement patterns

#### Moving Average Smoothing
- **Before:** `_enableMovingAverageWindow = false`
- **After:** `_enableMovingAverageWindow = true`
- **Impact:** Smooths out GPS noise while preserving actual route shape, creates cleaner route lines in the feed

#### Initial Position Capture
- **Added:** Code to capture the current position immediately when tracking starts
- **Impact:** Ensures the starting point is always recorded, even before the first GPS update arrives

#### Improved Coordinate Addition Logic
- **Before:** Could skip the first point if coordinates list was empty
- **After:** Always adds the first point, then applies distance filtering for subsequent points
- **Impact:** Guarantees at least a starting point is recorded, preventing "stationary dot" appearance

## Why These Changes Fix the Issues

### Problem 1: "App not detecting activity automatically"
**Root Cause:** The 3-meter distance filter meant GPS readings had to be at least 3 meters apart to register. During slow walking or when standing still, this didn't capture enough movement.

**Solution:** Reducing to 1 meter allows natural walking/running movement to be tracked continuously.

### Problem 2: "Tracking line appears stationary in feed"
**Root Cause:** Combination of:
- Sparse GPS points (5m minimum distance)
- Strict accuracy filtering (rejecting valid data)
- No initial point capture (routes starting as empty)

**Solution:** Dense point collection (1m), relaxed accuracy (30m), initial position capture, and smoothing creates a continuous, natural-looking route line.

## Testing Recommendations

1. **Test Walking Slowly**
   - Start a run and walk slowly around your area
   - The route should show continuous movement, not just isolated points

2. **Test in Urban Areas**
   - Test in areas with GPS signal issues (between buildings)
   - Should still capture movement with 30m accuracy threshold

3. **Upload to Feed**
   - Routes should now appear as actual paths, not single points or fragments
   - Line should be smooth and natural-looking

4. **Check Distance Accuracy**
   - Compare recorded distance with known routes
   - Should be more accurate due to better point density

## Technical Details

### GPS Filtering Pipeline
```
Raw GPS Stream (LocationService)
    ↓ (accuracy <= 30m filter)
Accurate Readings
    ↓ (1m distance filter in addCoordinate)
Deduplicated Points (0.5m minimum spacing)
    ↓ (3-point moving average if enabled)
Smoothed Route Coordinates
    ↓
Display & Save to ActivityModel
```

### Performance Impact
- Slightly more memory usage (more coordinates per route)
- Slightly more processing (moving average smoothing)
- Overall negligible on modern devices
- Benefits far outweigh minor performance cost

## Future Improvements
- Consider activity detection (running vs walking) based on speed
- Add adaptive smoothing based on accuracy metrics
- Implement pause detection for natural break points

