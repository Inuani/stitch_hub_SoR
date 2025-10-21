# Collection Management Guide

## Overview

The collection system has been refactored from hardcoded arrays to a dynamic, admin-managed system with:

- ✅ **HashMap-based storage** (efficient lookups)
- ✅ **Auto-incrementing IDs** (no manual ID management)
- ✅ **Admin functions** (add/update/delete items)
- ✅ **Persistent state** (survives canister upgrades)
- ✅ **Core library compatible** (updated for latest Motoko)

---

## Architecture

### State Management

```motoko
// Stable state persists across upgrades
stable let collectionState = Collection.init();
transient let collection = Collection.Collection(collectionState);
```

Items are stored in:
- **HashMap** for fast lookups during runtime
- **Array** in stable storage for persistence

### Auto-Incrementing IDs

- IDs start at 0 and increment automatically
- No need to manually manage IDs
- IDs never conflict or get reused

---

## Admin Functions (Owner Only)

All admin functions require caller to be the canister owner (initializer).

### Add Item

```bash
dfx canister call collection addCollectionItem \
  '("Item Name", "/thumb.webp", "/image.webp", "Description", "Rarity", vec {record{"Key"; "Value"}})'
```

**Returns:** `Nat` (the new item's ID)

**Example:**
```bash
dfx canister call collection addCollectionItem \
  '("Blue Hoodie", "/hoodie_thumb.webp", "/hoodie.webp", "A cool blue hoodie", "Rare", vec {record{"Size"; "L"}; record{"Color"; "Blue"}})'
# Returns: (4 : nat)
```

### Update Item

```bash
dfx canister call collection updateCollectionItem \
  '(0, "Updated Name", "/thumb.webp", "/image.webp", "New description", "Epic", vec {record{"Key"; "Value"}})'
```

**Returns:** `Result<(), Text>` (success or error message)

**Example:**
```bash
dfx canister call collection updateCollectionItem \
  '(0, "Updated Hoodie #0", "/item0_thumb.webp", "/item0.webp", "Updated description", "Légendaire", vec {record{"Type"; "Updated"}})'
# Returns: (variant { ok })
```

### Delete Item

```bash
dfx canister call collection deleteCollectionItem '(0)'
```

**Returns:** `Result<(), Text>` (success or error message)

**Example:**
```bash
dfx canister call collection deleteCollectionItem '(3)'
# Returns: (variant { ok })
```

---

## Query Functions (Public)

### Get Single Item

```bash
dfx canister call collection getCollectionItem '(0)'
```

**Returns:** `?Item` (optional item)

### Get All Items

```bash
dfx canister call collection getAllCollectionItems
```

**Returns:** `[Item]` (array of all items, sorted by ID)

### Get Item Count

```bash
dfx canister call collection getCollectionItemCount
```

**Returns:** `Nat` (total number of items)

### Get Collection Name

```bash
dfx canister call collection getCollectionName
```

**Returns:** `Text`

### Get Collection Description

```bash
dfx canister call collection getCollectionDescription
```

**Returns:** `Text`

---

## Collection Settings (Admin Only)

### Set Collection Name

```bash
dfx canister call collection setCollectionName '("My Collection")'
```

### Set Collection Description

```bash
dfx canister call collection setCollectionDescription '("A description of my collection")'
```

---

## Helper Scripts

### Initialize with Demo Items

Populate the collection with 4 demo hoodie items:

```bash
make init_collection
```

Or manually:
```bash
./scripts/init_collection.sh [canister_name] [network]
```

### Add Item Interactively

Interactive prompt to add a new item:

```bash
make add_item
```

Or manually:
```bash
./scripts/add_item.sh [canister_name] [network]
```

The script will prompt for:
- Item name
- Thumbnail URL
- Image URL
- Description
- Rarity
- Attributes (key-value pairs)

### List All Items

```bash
make list_items
```

### Get Item Count

```bash
make item_count
```

### Get Collection Name

```bash
make collection_name
```

---

## Item Structure

```motoko
type Item = {
    id: Nat;                      // Auto-generated, unique
    name: Text;                   // Item name
    thumbnailUrl: Text;           // URL for grid view
    imageUrl: Text;               // URL for detail page
    description: Text;            // Item description
    rarity: Text;                 // e.g., "Rare", "Epic", "Légendaire"
    attributes: [(Text, Text)];   // Key-value pairs
};
```

---

## Rarity System

Supported rarity levels (with CSS styling):

- **Common** (`common`) - Green
- **Rare** (`rare`) - Blue
- **Epic** (`epic`) - Purple
- **Légendaire** (`légendaire`) - Amber/Gold

Rarity is case-insensitive in HTML rendering.

---

## URLs

### Collection Page
```
/collection
```

Shows all items in a grid layout.

### Item Detail Page
```
/item/{id}
```

Shows full details for a specific item by ID.

---

## Examples

### Complete Workflow

```bash
# 1. Deploy canister
make all

# 2. Initialize with demo items
make init_collection

# 3. Check items were added
make item_count
# Output: (4 : nat)

# 4. View collection in browser
make url
# Navigate to /collection

# 5. Add a new item
dfx canister call collection addCollectionItem \
  '("New Item", "/new_thumb.webp", "/new.webp", "A new item", "Epic", vec {})'
# Output: (4 : nat)

# 6. Update collection name
dfx canister call collection setCollectionName '("My Custom Collection")'

# 7. View updated collection
# Refresh /collection in browser
```

### Add Item with Multiple Attributes

```bash
dfx canister call collection addCollectionItem \
  '(
    "Special Edition Hoodie",
    "/special_thumb.webp",
    "/special.webp",
    "Limited edition collectible",
    "Légendaire",
    vec {
      record{"Edition"; "Limited"};
      record{"Year"; "2024"};
      record{"Serial"; "001/100"};
      record{"Artist"; "John Doe"}
    }
  )'
```

### Batch Operations

```bash
# Add multiple items
for i in {5..10}; do
  dfx canister call collection addCollectionItem \
    "(\"Item #$i\", \"/item${i}_thumb.webp\", \"/item${i}.webp\", \"Description $i\", \"Rare\", vec {})"
done

# Check total
make item_count
```

---

## Migration from Old System

The old hardcoded array system has been replaced. If you have existing items:

1. Items are **no longer hardcoded** in `collection.mo`
2. Use `make init_collection` to add the original 4 demo items
3. Or manually add items using the admin functions

---

## Persistence & Upgrades

### Data Persistence

Items are stored in **stable variables**:
- Survives canister upgrades
- Data preserved during `dfx deploy`
- State is maintained across restarts

### Upgrade Safety

```bash
# Safe upgrade (preserves data)
dfx deploy collection

# Full reinstall (loses all data!)
dfx deploy collection --mode reinstall
```

**⚠️ Warning:** Using `--mode reinstall` will delete all items!

---

## Access Control

### Owner-Only Functions

These functions check `caller == initializer`:
- `addCollectionItem`
- `updateCollectionItem`
- `deleteCollectionItem`
- `setCollectionName`
- `setCollectionDescription`

### Public Functions

These can be called by anyone:
- `getCollectionItem`
- `getAllCollectionItems`
- `getCollectionItemCount`
- `getCollectionName`
- `getCollectionDescription`
- `generateItemPage` (via HTTP routes)
- `generateCollectionPage` (via HTTP routes)

---

## Troubleshooting

### "Item not found" error

```bash
# Check if item exists
dfx canister call collection getCollectionItem '(0)'
# Returns: (null) if not found

# List all items to see IDs
make list_items
```

### Empty collection

```bash
# Check count
make item_count
# Output: (0 : nat) means empty

# Initialize with demo items
make init_collection
```

### Permission denied

```bash
# Error: assertion failed
# Solution: Must be called by canister owner
# Check your dfx identity:
dfx identity whoami
```

### Items not appearing on webpage

1. Check items exist: `make item_count`
2. Redeploy: `dfx deploy collection`
3. Clear browser cache
4. Check console for errors

---

## Next Steps

Future enhancements to consider:

1. **Pagination** - For collections with 100+ items
2. **Search/Filter** - By name, rarity, attributes
3. **Sorting** - By date added, name, rarity
4. **Categories** - Group items by type
5. **Bulk Import** - Upload CSV/JSON
6. **Image Upload Integration** - Link to `files.mo`
7. **Admin Dashboard** - Web UI for management
8. **Per-Item Visibility** - Draft/published status
9. **Item History** - Track edits and changes
10. **Multiple Collections** - Support for sub-collections

---

## API Reference

See `src/collection.mo` for full type definitions and function signatures.

### Key Types

```motoko
// Item definition
type Item = {
    id: Nat;
    name: Text;
    thumbnailUrl: Text;
    imageUrl: Text;
    description: Text;
    rarity: Text;
    attributes: [(Text, Text)];
};

// State for persistence
type State = {
    var items : [(Nat, Item)];
    var nextId : Nat;
    var collectionName : Text;
    var collectionDescription : Text;
};
```

### Main Class

```motoko
public class Collection(state : State) {
    // Admin functions
    public func addItem(...) : Nat
    public func updateItem(...) : Result<(), Text>
    public func deleteItem(id: Nat) : Result<(), Text>
    
    // Query functions
    public func getItem(id: Nat) : ?Item
    public func getAllItems() : [Item]
    public func getItemCount() : Nat
    
    // Settings
    public func setCollectionName(name: Text)
    public func setCollectionDescription(description: Text)
    public func getCollectionName() : Text
    public func getCollectionDescription() : Text
    
    // HTML generation
    public func generateItemPage(id: Nat) : Text
    public func generateCollectionPage() : Text
}
```

---

## Support

For issues or questions:
1. Check this documentation
2. Review `src/collection.mo` source code
3. Test with `make init_collection` for a working baseline
4. Check canister logs: `dfx canister logs collection`
