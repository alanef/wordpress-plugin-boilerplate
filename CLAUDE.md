# Claude Code Instructions for WordPress Plugin Development

When working on WordPress plugin development in this repository, please follow these guidelines:

## Required Reading

Before starting any WordPress plugin development work:

1. **Read the README.md** - Contains the overall project structure, setup instructions, and deployment strategies
2. **Read AI-WORDPRESS-PLUGIN-PROMPT.md** - Contains comprehensive WordPress.org compliance requirements including:
   - Security best practices (input sanitization, output escaping, nonces)
   - Proper namespacing and unique prefixes (minimum 4 characters)
   - WordPress coding standards
   - Common review failures to avoid
   - Proper enqueueing of scripts and styles
   - Translation and internationalization requirements

## Key Development Principles

### Security First
- ALWAYS sanitize all inputs
- ALWAYS escape all outputs at the last possible moment
- ALWAYS use nonces for forms and AJAX requests
- ALWAYS check user capabilities

### WordPress Standards
- Use WordPress functions instead of PHP natives (e.g., `wp_remote_get()` not `curl`)
- Enqueue scripts/styles properly - never include directly
- Use WordPress bundled libraries (jQuery, etc.) - don't download your own
- Follow WordPress naming conventions and coding standards

### Unique Prefixes
- All global functions, constants, and classes must have unique prefixes of at least 4 characters
- Example: Use `MYAWESOMEPLUGIN_` not `MY_` for constants
- Namespaces should also be unique: `MyAwesomePlugin\` not `MyPlugin\`

### No Trademark Violations
- Never use "WordPress" in plugin names (use "WP" instead)
- Avoid using trademarked names unless creating official integrations

### Clean Code
- Use Composer autoloading with classmap
- Organize code into logical directories (admin/, public/, includes/)
- Include proper PHPDoc comments
- Add translator comments for translatable strings with placeholders

## Running Quality Checks

Before committing any code:

```bash
# Check PHP coding standards
npm run lint:php

# Fix PHP coding standards automatically
npm run lint:php:fix

# Run tests
npm run test
```

## Development Workflow

1. Start the development environment: `npm run env:start`
2. Make your changes following the guidelines
3. Test thoroughly in the local environment
4. Run PHPCS to ensure code quality
5. Commit with clear, descriptive messages

## Important Files

- `phpcs.xml.dist` - WordPress coding standards configuration
- `.distignore` - Files to exclude from distribution builds
- `.wp-env.json` - Local development environment configuration

Remember: The goal is to create secure, efficient plugins that will pass WordPress.org review on first submission.