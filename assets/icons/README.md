# Custom Apparatus Icons

This directory is for custom apparatus icons used throughout the app.

## Adding Custom Icons

The app is configured to use SVG icons. Add SVG files to this directory with these exact names:

1. **Required SVG files:**
   - `vault.svg` - For Vault apparatus
   - `bars.svg` - For Bars apparatus (uneven bars)
   - `beam.svg` - For Beam apparatus (balance beam)
   - `floor_exercise.svg` - For Floor Exercise apparatus
   - `other.svg` - For Other/unspecified apparatus

2. **Recommended specifications:**
   - Format: SVG (Scalable Vector Graphics)
   - ViewBox: 0 0 24 24 or similar square ratio
   - Color: Single path color (preferably black) - the app will automatically tint them to match the theme
   - Style: Simple, recognizable silhouettes work best
   - Keep file size small (optimize with SVGO or similar tools)

3. **Testing:**
   - After adding SVG files, run `flutter pub get`
   - Hot restart the app (hot reload may not work for new assets)
   - Icons will automatically appear in the Floor/Pod Details screen

## Creating Icons

You can create or find icons using:
- **Design tools:** Figma, Sketch, Adobe Illustrator
- **Icon libraries:** Material Icons, FontAwesome, or custom designs
- **Export as SVG** with a single color path

## Current State

Currently using Material Design icon fallbacks:
- Vault: `Icons.table_chart`
- Bars: `Icons.event`
- Beam: `Icons.straighten`
- Floor: `Icons.dashboard`
- Other: `Icons.category`

Custom icons will automatically replace these once added and enabled.
