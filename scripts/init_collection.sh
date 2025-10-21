#!/bin/bash

# Script to initialize collection with demo items
# Usage: ./init_collection.sh [canister_name] [network]

CANISTER_NAME=${1:-collection}
NETWORK=${2:-local}

echo "Initializing collection with demo items..."
echo "Canister: $CANISTER_NAME"
echo "Network: $NETWORK"
echo ""

# Add Item 0
echo "Adding Item 0: Hoodie #0..."
dfx canister --network "$NETWORK" call "$CANISTER_NAME" addCollectionItem \
  '("Hoodie #0", "/thumb_0.webp", "/item_0.webp", "pull en lien avec l'\''événement du 30 avril", "Légendaire", vec {record{"Type"; "Sky"}; record{"Intensity"; "Light"}; record{"Mood"; "Calm"}})' \
  && echo "✓ Item 0 added" || echo "✗ Failed to add Item 0"

echo ""

# Add Item 1
echo "Adding Item 1: Hoodie #1..."
dfx canister --network "$NETWORK" call "$CANISTER_NAME" addCollectionItem \
  '("Hoodie #1", "/thumb_1.webp", "/item_1.webp", "The mysterious deep blue of ocean trenches", "Rare", vec {record{"Type"; "Ocean"}; record{"Aura"; "+100"}; record{"Forme"; "Triangle"}})' \
  && echo "✓ Item 1 added" || echo "✗ Failed to add Item 1"

echo ""

# Add Item 2
echo "Adding Item 2: Hoodie #2..."
dfx canister --network "$NETWORK" call "$CANISTER_NAME" addCollectionItem \
  '("Hoodie #2", "/thumb_2.webp", "/item_2.webp", "The intense blue-black of a stormy midnight sky", "Rare", vec {record{"Type"; "Storm"}; record{"Intensity"; "Deep"}; record{"Mood"; "Mysterious"}})' \
  && echo "✓ Item 2 added" || echo "✗ Failed to add Item 2"

echo ""

# Add Item 3
echo "Adding Item 3: Hoodie #3..."
dfx canister --network "$NETWORK" call "$CANISTER_NAME" addCollectionItem \
  '("Hoodie #3", "/thumb_3.webp", "/item_3.webp", "The intense blue-black of a stormy midnight sky", "Rare", vec {record{"Type"; "Storm"}; record{"Intensity"; "Deep"}; record{"Mood"; "Mysterious"}})' \
  && echo "✓ Item 3 added" || echo "✗ Failed to add Item 3"

echo ""
echo "================================================"
echo "Collection initialization complete!"
echo "================================================"
echo ""

# Show collection stats
echo "Collection stats:"
dfx canister --network "$NETWORK" call "$CANISTER_NAME" getCollectionItemCount

echo ""
echo "View collection at: /collection"
