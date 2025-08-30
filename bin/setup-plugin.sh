#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 \"Plugin Name\" \"plugin-slug\" [constant-prefix]"
    echo ""
    echo "Example: $0 \"My Awesome Plugin\" \"my-awesome-plugin\""
    echo "Example: $0 \"My Awesome Plugin\" \"my-awesome-plugin\" \"MYAP\""
    echo ""
    echo "Arguments:"
    echo "  Plugin Name     - The human-readable name of your plugin"
    echo "  plugin-slug     - The slug for your plugin (lowercase, hyphens)"
    echo "  constant-prefix - Optional: Custom prefix for constants (min 4 chars, uppercase)"
    echo "                    If not provided, will auto-generate from slug"
    echo ""
    echo "This script will:"
    echo "  - Rename the plugin directory and main file"
    echo "  - Replace all placeholders with your plugin name"
    echo "  - Generate WordPress-compliant constant prefixes (min 4 chars)"
    echo "  - Update configuration files"
    exit 1
}

# Function to generate WordPress-compliant prefix from slug
generate_prefix() {
    local slug="$1"
    local prefix=""
    
    # Method 1: Take first letter of each hyphenated word
    IFS='-' read -ra PARTS <<< "$slug"
    for part in "${PARTS[@]}"; do
        if [ -n "$part" ]; then
            prefix="${prefix}${part:0:1}"
        fi
    done
    
    # Convert to uppercase
    prefix="${prefix^^}"
    
    # If prefix is less than 4 characters, add digits
    if [ ${#prefix} -lt 4 ]; then
        # Calculate how many digits needed
        local needed=$((4 - ${#prefix}))
        local digits=""
        for ((i=1; i<=needed; i++)); do
            digits="${digits}${i}"
        done
        prefix="${prefix}${digits}"
    fi
    
    echo "$prefix"
}

# Check if correct number of arguments
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    usage
fi

PLUGIN_NAME="$1"
PLUGIN_SLUG="$2"
PLUGIN_SLUG_UNDERSCORE="${PLUGIN_SLUG//-/_}"

# Handle custom prefix or generate one
if [ $# -eq 3 ]; then
    CUSTOM_PREFIX="$3"
    # Convert to uppercase
    CUSTOM_PREFIX="${CUSTOM_PREFIX^^}"
    
    # Validate custom prefix
    if [ ${#CUSTOM_PREFIX} -lt 4 ]; then
        echo -e "${RED}Error: Custom prefix must be at least 4 characters long (WordPress requirement)${NC}"
        exit 1
    fi
    
    if ! [[ "$CUSTOM_PREFIX" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
        echo -e "${RED}Error: Custom prefix must start with a letter and contain only uppercase letters, numbers, and underscores${NC}"
        exit 1
    fi
    
    PLUGIN_CONSTANT="$CUSTOM_PREFIX"
else
    # Auto-generate prefix from slug
    PLUGIN_CONSTANT=$(generate_prefix "$PLUGIN_SLUG")
fi

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
if [ $# -eq 3 ]; then
    echo "  Constant Prefix: $PLUGIN_CONSTANT (user-provided)"
else
    echo "  Constant Prefix: $PLUGIN_CONSTANT (auto-generated)"
fi
echo "  Namespace: $PLUGIN_NAMESPACE"
echo ""
echo -e "${YELLOW}Note: WordPress requires constant prefixes to be at least 4 characters.${NC}"
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
        -e "s/My Awesome WP Boilerplate/$PLUGIN_NAME/g" \
        -e "s/MyAwesomeWPBoilerplate/$PLUGIN_NAMESPACE/g" \
        -e "s/my-awesome-wp-boilerplate/$PLUGIN_SLUG/g" \
        -e "s/my_awesome_wp_boilerplate/$PLUGIN_SLUG_UNDERSCORE/g" \
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

# Update phpcs.xml.dist with the correct prefixes for WPCS
if [ -f "phpcs.xml.dist" ]; then
    # Update the file path to scan
    sed -i "s|<file>./plugin-name</file>|<file>./$PLUGIN_SLUG</file>|g" phpcs.xml.dist
    
    # Update the text domain
    sed -i "s|<element value=\"plugin-name\"/>|<element value=\"$PLUGIN_SLUG\"/>|g" phpcs.xml.dist
    
    # Update the function/constant prefixes
    sed -i "s|<element value=\"plugin_name\"/>|<element value=\"${PLUGIN_SLUG_UNDERSCORE}\"/>|g" phpcs.xml.dist
    sed -i "s|<element value=\"PLUGIN_NAME\"/>|<element value=\"${PLUGIN_CONSTANT}\"/>|g" phpcs.xml.dist
    
    echo "  ✓ Updated phpcs.xml.dist with correct prefixes"
fi

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