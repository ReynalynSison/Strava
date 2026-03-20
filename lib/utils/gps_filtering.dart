/// Legacy GPS filtering helpers have been retired.
///
/// TrackingService.addCoordinate now owns the single filtering pipeline
/// (accuracy gate, distance filter, speed validation). Keeping this file
/// as an empty placeholder avoids stale references without breaking imports.
///
/// If you need additional filtering in the future, add it directly to
/// TrackingService to maintain a single source of truth.

