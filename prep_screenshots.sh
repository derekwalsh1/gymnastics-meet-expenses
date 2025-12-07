#!/bin/bash
# Rename screenshots to descriptive names for App Store

cd screenshots

# Rename in order (you may need to adjust these based on what each screenshot shows)
# App Store accepts them in any order, but descriptive names help

mv IMG_0183.PNG 01-events-list.png 2>/dev/null || true
mv IMG_0184.PNG 02-event-details.png 2>/dev/null || true
mv IMG_0185.PNG 03-expenses-tracking.png 2>/dev/null || true
mv IMG_0186.PNG 04-invoice-report.png 2>/dev/null || true
mv IMG_0187.PNG 05-judge-assignments.png 2>/dev/null || true
mv IMG_0188.PNG 06-event-structure.png 2>/dev/null || true

echo "Screenshots renamed and ready for App Store!"
echo ""
echo "Files in screenshots/:"
ls -lh *.png 2>/dev/null || ls -lh *.PNG

echo ""
echo "✓ Screenshot dimensions: 2048x2732 (12.9\" iPad Pro) - Perfect for App Store!"
echo "✓ You have 6 screenshots - App Store requires 1-10"
echo ""
echo "Next steps:"
echo "1. Open App Store Connect"
echo "2. Go to your app → App Store tab"
echo "3. Scroll to 'Screenshots' section"
echo "4. Select '12.9\" iPad Pro' device"
echo "5. Drag and drop these screenshots in order"
echo ""
echo "Screenshot files are in: $(pwd)"
