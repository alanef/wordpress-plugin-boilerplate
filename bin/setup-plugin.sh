#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 \"Plugin Name\" \"plugin-slug\""
    echo ""
    echo "Example: $0 \"My Awesome Plugin\" \"my-awesome-plugin\""
    echo ""
    echo "This script will:"
    echo "  - Rename the plugin directory and main file"
    echo "  - Replace all placeholders with your plugin name"
    echo "  - Update configuration files"
    exit 1
}

# Check if correct number of arguments
if [ $# -ne 2 ]; then
    usage
fi

PLUGIN_NAME="$1"
PLUGIN_SLUG="$2"
PLUGIN_SLUG_UNDERSCORE="${PLUGIN_SLUG//-/_}"
PLUGIN_CONSTANT="${PLUGIN_SLUG_UNDERSCORE^^}"
PLUGIN_NAMESPACE="$(echo $PLUGIN_NAME | sed 's/ //g')"

echo -e "${GREEN}Setting up plugin: $PLUGIN_NAME ($PLUGIN_SLUG)${NC}"
echo ""

# Validate plugin slug (should contain only lowercase letters, numbers, and hyphens)
if ! [[ "$PLUGIN_SLUG" =~ ^[a-z0-9-]+$ ]]; then
    echo -e "${RED}Error: Plugin slug should only contain lowercase letters, numbers, and hyphens${NC}"
    exit 1
fi

# Check if we're in the right directory
if [ ! -d "plugin-name" ]; then
    echo -e "${RED}Error: 'plugin-name' directory not found. Please run this script from the boilerplate root directory.${NC}"
    exit 1
fi

echo "Configuration:"
echo "  Plugin Name: $PLUGIN_NAME"
echo "  Plugin Slug: $PLUGIN_SLUG"
echo "  Text Domain: $PLUGIN_SLUG"
echo "  Function Prefix: $PLUGIN_SLUG_UNDERSCORE"
echo "  Constant Prefix: $PLUGIN_CONSTANT"
echo "  Namespace: $PLUGIN_NAMESPACE"
echo ""

read -p "Do you want to continue? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 1
fi

echo -e "${YELLOW}Processing files...${NC}"

# Rename plugin directory
if [ -d "$PLUGIN_SLUG" ]; then
    echo -e "${RED}Error: Directory '$PLUGIN_SLUG' already exists${NC}"
    exit 1
fi

mv plugin-name "$PLUGIN_SLUG"
echo "  ✓ Renamed plugin directory"

# Rename main plugin file
mv "$PLUGIN_SLUG/plugin-name.php" "$PLUGIN_SLUG/$PLUGIN_SLUG.php"
echo "  ✓ Renamed main plugin file"

# Replace placeholders in all files
echo -e "${YELLOW}Replacing placeholders...${NC}"

# Files to process
find . -type f \( \
    -name "*.php" -o \
    -name "*.json" -o \
    -name "*.txt" -o \
    -name "*.xml" -o \
    -name "*.xml.dist" -o \
    -name "*.md" -o \
    -name "*.yml" -o \
    -name "*.yml.example" -o \
    -name ".wp-env.json" \
\) ! -path "./vendor/*" ! -path "./node_modules/*" ! -path "./.git/*" -print0 | while IFS= read -r -d '' file; do
    # Use temporary file for replacements
    temp_file=$(mktemp)
    
    # Perform replacements
    sed \
        -e "s/Plugin Name/$PLUGIN_NAME/g" \
        -e "s/PluginName/$PLUGIN_NAMESPACE/g" \
        -e "s/plugin-name/$PLUGIN_SLUG/g" \
        -e "s/plugin_name/$PLUGIN_SLUG_UNDERSCORE/g" \
        -e "s/PLUGIN_NAME/$PLUGIN_CONSTANT/g" \
        "$file" > "$temp_file"
    
    # Move temp file back
    mv "$temp_file" "$file"
done

echo "  ✓ Replaced placeholders in files"

# Update .wp-env.json specifically
sed -i "s|\"./plugin-name\"|\"./\$PLUGIN_SLUG\"|g" .wp-env.json
echo "  ✓ Updated .wp-env.json"

# Make scripts executable
chmod +x bin/*.sh
echo "  ✓ Made scripts executable"

echo ""
echo -e "${GREEN}✓ Plugin setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Update plugin header information in $PLUGIN_SLUG/$PLUGIN_SLUG.php"
echo "  2. Update author information in composer.json and package.json"
echo "  3. Run 'composer install' to install PHP dependencies"
echo "  4. Run 'npm install' to install Node dependencies"
echo "  5. Run 'npm run env:start' to start the development environment"
echo "  6. Update the README.md with your plugin information"
echo ""
echo "Optional:"
echo "  - Configure deployment workflows in .github/workflows/"
echo "  - Set up your preferred version control (git init)"
echo "  - Add your business logic to $PLUGIN_SLUG/$PLUGIN_SLUG.php"
echo ""
echo -e "${GREEN}Happy coding!${NC}"