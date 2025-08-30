#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}WordPress Plugin Build Script${NC}"
echo "================================"
echo ""

# Find the plugin directory (should be the only directory that's not bin, tests, vendor, node_modules, etc.)
PLUGIN_SLUG=$(find . -maxdepth 1 -type d ! -name ".*" ! -name "bin" ! -name "tests" ! -name "vendor" ! -name "node_modules" ! -name "dist" ! -name "build" | grep -v "^\.$" | head -1 | sed 's|^\./||')

if [ -z "$PLUGIN_SLUG" ]; then
    echo -e "${RED}Error: Could not find plugin directory${NC}"
    echo "Please ensure you have a plugin directory (not bin, tests, vendor, or node_modules)"
    exit 1
fi

# Check if plugin directory exists
if [ ! -d "$PLUGIN_SLUG" ]; then
    echo -e "${RED}Error: Plugin directory '$PLUGIN_SLUG' not found${NC}"
    exit 1
fi

# Find the main plugin file
MAIN_FILE=$(find "$PLUGIN_SLUG" -maxdepth 1 -name "*.php" -exec grep -l "Plugin Name:" {} \; | head -1)

if [ -z "$MAIN_FILE" ]; then
    echo -e "${RED}Error: Could not find main plugin file in $PLUGIN_SLUG/${NC}"
    exit 1
fi

# Extract version from plugin header
VERSION=$(grep -i "Version:" "$MAIN_FILE" | head -1 | awk -F':' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')

if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Could not extract version from $MAIN_FILE${NC}"
    exit 1
fi

echo "Plugin: $PLUGIN_SLUG"
echo "Version: $VERSION"
echo "Main File: $MAIN_FILE"
echo ""

# Check for .distignore file
DISTIGNORE="$PLUGIN_SLUG/.distignore"
if [ ! -f "$DISTIGNORE" ]; then
    echo -e "${YELLOW}Warning: .distignore file not found at $DISTIGNORE${NC}"
    echo "Using default exclude patterns..."
    DISTIGNORE=""
fi

# Create dist directory
echo -e "${YELLOW}Creating distribution directory...${NC}"
mkdir -p dist

# Create temporary build directory
BUILD_DIR=$(mktemp -d)
if [ ! -d "$BUILD_DIR" ]; then
    echo -e "${RED}Error: Could not create temporary build directory${NC}"
    exit 1
fi

echo "Build directory: $BUILD_DIR"

# Create plugin directory in build
mkdir -p "$BUILD_DIR/$PLUGIN_SLUG"

# Copy files to build directory
echo -e "${YELLOW}Copying plugin files...${NC}"

if [ -f "$DISTIGNORE" ]; then
    # Use .distignore file
    rsync -av --exclude-from="$DISTIGNORE" "$PLUGIN_SLUG/" "$BUILD_DIR/$PLUGIN_SLUG/"
else
    # Use default excludes
    rsync -av \
        --exclude='.git' \
        --exclude='.gitignore' \
        --exclude='.gitattributes' \
        --exclude='.github' \
        --exclude='.editorconfig' \
        --exclude='*.md' \
        --exclude='composer.json' \
        --exclude='composer.lock' \
        --exclude='package.json' \
        --exclude='package-lock.json' \
        --exclude='phpcs.xml*' \
        --exclude='phpunit.xml*' \
        --exclude='.phpcs.xml*' \
        --exclude='tests' \
        --exclude='bin' \
        --exclude='.wp-env.json' \
        --exclude='node_modules' \
        --exclude='vendor' \
        --exclude='.DS_Store' \
        --exclude='Thumbs.db' \
        --exclude='*.log' \
        --exclude='*.sql' \
        --exclude='*.zip' \
        --exclude='.distignore' \
        "$PLUGIN_SLUG/" "$BUILD_DIR/$PLUGIN_SLUG/"
fi

# Check if composer autoload is needed
if [ -f "composer.json" ] && grep -q '"autoload"' composer.json; then
    echo -e "${YELLOW}Generating optimized autoloader...${NC}"
    composer dump-autoload --no-dev --optimize -d "$BUILD_DIR/$PLUGIN_SLUG" 2>/dev/null
fi

# Create zip file
echo -e "${YELLOW}Creating zip archive...${NC}"
cd "$BUILD_DIR" || exit 1

ZIP_FILE="$PLUGIN_SLUG-$VERSION.zip"
zip -r "$ZIP_FILE" "$PLUGIN_SLUG" -q

# Move zip to dist directory
mv "$ZIP_FILE" "$OLDPWD/dist/"

# Calculate file size
FILE_SIZE=$(du -h "$OLDPWD/dist/$ZIP_FILE" | cut -f1)

# Cleanup
echo -e "${YELLOW}Cleaning up...${NC}"
cd "$OLDPWD" || exit 1
rm -rf "$BUILD_DIR"

echo ""
echo -e "${GREEN}✓ Build complete!${NC}"
echo ""
echo "Package: dist/$ZIP_FILE"
echo "Size: $FILE_SIZE"
echo ""

# Generate file list
echo "Package contents:"
unzip -l "dist/$ZIP_FILE" | tail -n +4 | head -n -2 | awk '{print "  - " $4}' | head -20
TOTAL_FILES=$(unzip -l "dist/$ZIP_FILE" | tail -1 | awk '{print $2}')
if [ "$TOTAL_FILES" -gt 20 ]; then
    echo "  ... and $((TOTAL_FILES - 20)) more files"
fi

echo ""
echo -e "${GREEN}Ready for distribution!${NC}"
echo ""
echo "You can now:"
echo "  - Upload to WordPress.org SVN repository"
echo "  - Create a GitHub release with this zip file"
echo "  - Deploy to Freemius"
echo "  - Distribute to users"