# Button Management Documentation

## Overview

The button management system allows you to dynamically add, update, and delete buttons on your home page. These buttons can link to external services like Discord, Instagram, your website, or any other URL you want to promote.

## Layout Changes

The home page now features:
- **Logo and Title** at the top
- **Responsive Design**: 
  - On desktop (>768px): Logo and title are side-by-side
  - On mobile (≤768px): Logo stacks above the title
- **Dynamic Buttons** below the header
- **Collection Button** automatically added as the first button, followed by your custom buttons

## Button Structure

Each button has two fields:
- `text`: The label displayed on the button (e.g., "Follow us on Instagram")
- `link`: The URL the button links to (e.g., "https://instagram.com/yourpage")

## Available Functions

### Query Functions (Read-only)

#### Get All Buttons
```bash
dfx canister call collection getAllButtons
```
Returns an array of all configured buttons.

#### Get Button Count
```bash
dfx canister call collection getButtonCount
```
Returns the total number of buttons.

#### Get Specific Button
```bash
dfx canister call collection getButton '(0)'
```
Returns the button at the specified index (0-based).

### Update Functions (Admin-only)

#### Add a New Button
```bash
dfx canister call collection addButton '("Follow us on Instagram", "https://instagram.com/yourpage")'
```
Adds a new button to the end of the list. Returns the index of the new button.

**Examples:**
```bash
# Discord button
dfx canister call collection addButton '("Join our Discord", "https://discord.gg/yourinvite")'

# Website button
dfx canister call collection addButton '("Visit our Website", "https://yourwebsite.com")'

# Twitter button
dfx canister call collection addButton '("Follow on Twitter", "https://twitter.com/yourhandle")'

# Telegram button
dfx canister call collection addButton '("Join Telegram", "https://t.me/yourchannel")'
```

#### Update an Existing Button
```bash
dfx canister call collection updateButton '(0, "New Button Text", "https://newlink.com")'
```
Updates the button at the specified index. Returns `true` if successful, `false` if the index doesn't exist.

#### Delete a Button
```bash
dfx canister call collection deleteButton '(0)'
```
Removes the button at the specified index. Returns `true` if successful, `false` if the index doesn't exist.

#### Clear All Buttons
```bash
dfx canister call collection clearAllButtons
```
Removes all custom buttons. Use with caution!

## Default Configuration

By default, the system includes one button:
- **"Rejoins la communauté d'Évorev"** → `https://discord.gg/`

You can update or remove this button using the management functions.

## Button Order

Buttons appear in the order they were added. The index starts at 0:
- Index 0: First button
- Index 1: Second button
- Index 2: Third button
- etc.

The "Voir la collection" (View Collection) button is automatically added as the first button and doesn't count in the index.

## Styling

All buttons automatically use your theme's primary color (configurable via theme management). They have:
- Consistent padding and sizing
- Rounded corners
- Hover effects
- Mobile-responsive layout

## Common Workflows

### Replacing the Default Discord Button

```bash
# First, get all buttons to see current state
dfx canister call collection getAllButtons

# Update button at index 0
dfx canister call collection updateButton '(0, "Your Custom Text", "https://your-link.com")'
```

### Adding Multiple Social Media Buttons

```bash
# Add Instagram
dfx canister call collection addButton '("Instagram", "https://instagram.com/yourpage")'

# Add Twitter
dfx canister call collection addButton '("Twitter", "https://twitter.com/yourhandle")'

# Add TikTok
dfx canister call collection addButton '("TikTok", "https://tiktok.com/@yourhandle")'
```

### Starting Fresh

```bash
# Clear all existing buttons
dfx canister call collection clearAllButtons

# Add your new buttons
dfx canister call collection addButton '("Discord", "https://discord.gg/yourinvite")'
dfx canister call collection addButton '("Website", "https://yourwebsite.com")'
```

## Tips

1. **Test Your Links**: Make sure URLs are complete and correct before adding them
2. **Button Text Length**: Keep button text concise for better mobile display
3. **Button Order**: Add buttons in the priority order you want them displayed
4. **Backup**: Use `getAllButtons` to save your configuration before making changes

## Permissions

All update functions require admin access (initializer principal). Only the canister owner can modify buttons.

## Technical Details

- Buttons are stored in persistent stable memory
- Changes take effect immediately
- No redeployment needed when updating buttons
- State survives canister upgrades