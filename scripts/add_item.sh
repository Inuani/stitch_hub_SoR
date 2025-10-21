#!/bin/bash

# Script to add items to the collection
# Usage: ./add_item.sh

CANISTER_NAME=${1:-collection}
NETWORK=${2:-local}

# Check if canister name is provided
if [ -z "$CANISTER_NAME" ]; then
    echo "Error: Canister name is required"
    echo "Usage: $0 [canister_name] [network]"
    exit 1
fi

echo "Adding item to collection..."
echo "Canister: $CANISTER_NAME"
echo "Network: $NETWORK"
echo ""

# Prompt for item details
read -p "Item name: " NAME
read -p "Thumbnail URL (e.g., /item0_thumb.webp): " THUMBNAIL
read -p "Image URL (e.g., /item0.webp): " IMAGE
read -p "Description: " DESCRIPTION
read -p "Rarity (e.g., Rare, Légendaire, Epic): " RARITY

echo ""
echo "Adding attributes (enter empty key to finish):"
ATTRIBUTES="vec {"

while true; do
    read -p "Attribute key (or press Enter to finish): " KEY
    if [ -z "$KEY" ]; then
        break
    fi
    read -p "Attribute value: " VALUE
    ATTRIBUTES="${ATTRIBUTES}record{\"${KEY}\"; \"${VALUE}\"};"
done

ATTRIBUTES="${ATTRIBUTES}}"

echo ""
echo "Adding item with:"
echo "  Name: $NAME"
echo "  Thumbnail: $THUMBNAIL"
echo "  Image: $IMAGE"
echo "  Description: $DESCRIPTION"
echo "  Rarity: $RARITY"
echo ""

# Call the canister function
RESULT=$(dfx canister --network "$NETWORK" call "$CANISTER_NAME" addCollectionItem \
  "(\"$NAME\", \"$THUMBNAIL\", \"$IMAGE\", \"$DESCRIPTION\", \"$RARITY\", $ATTRIBUTES)")

if [ $? -eq 0 ]; then
    echo "✓ Item added successfully!"
    echo "Result: $RESULT"

    # Extract ID from result
    ID=$(echo $RESULT | grep -o '[0-9]*' | head -1)
    if [ -n "$ID" ]; then
        echo ""
        echo "Item ID: $ID"
        echo "View at: /item/$ID"
    fi
else
    echo "✗ Failed to add item"
    exit 1
fi
