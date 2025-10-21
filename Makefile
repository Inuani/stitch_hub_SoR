# http://u6s2n-gx777-77774-qaaba-cai.raw.localhost:4943/api/hello/elie

# icx-asset --replica http://127.0.0.1:4943 --pem ~/.config/dfx/identity/raygen/identity.pem sync $(dfx canister id liminal) ./public

include .env

REPLICA_URL := $(if $(filter ic,$(subst ',,$(DFX_NETWORK))),https://ic0.app,http://127.0.0.1:4943)
CANISTER_NAME := $(shell grep "CANISTER_ID_" .env | grep -v "INTERNET_IDENTITY\|CANISTER_ID='" | head -1 | sed 's/CANISTER_ID_\([^=]*\)=.*/\1/' | tr '[:upper:]' '[:lower:]')
CANISTER_ID := $(CANISTER_ID_$(shell echo $(CANISTER_NAME) | tr '[:lower:]' '[:upper:]'))
CMAC_COUNT ?= 20000

UNAME := $(shell uname)
ifeq ($(UNAME), Darwin)
    OPEN_CMD := open
else ifeq ($(UNAME), Linux)
    OPEN_CMD := xdg-open
else
    OPEN_CMD := start
endif

all:
	dfx deploy $(CANISTER_NAME)

ic:
	dfx deploy $(CANISTER_NAME) --ic

url:
	$(OPEN_CMD) http://$(CANISTER_ID).raw.localhost:4943/

irl:
	$(OPEN_CMD) https://$(CANISTER_ID).raw.icp0.io

sync:
	icx-asset --replica http://127.0.0.1:4943 --pem ~/.config/dfx/identity/raygen/identity.pem sync $(CANISTER_ID) ./public

Isync:
	icx-asset --replica https://ic0.app --pem ~/.config/dfx/identity/raygen/identity.pem sync $(CANISTER_ID) ./public

protect:
	python3 scripts/setup_route.py $(CANISTER_ID) stitch/1 --cmac-count 200 --ic

protect_ic:
	python3 scripts/setup_route.py $(CANISTER_ID) files/certificat_1 --cmac-count $(CMAC_COUNT) --ic --random-key

reinstall:
	dfx deploy $(CANISTER_NAME) --mode reinstall --ic

ls:
	icx-asset --replica https://ic0.app --pem ~/.config/dfx/identity/raygen/identity.pem ls $(CANISTER_ID)

delete_asset:
	dfx canister call --ic $(CANISTER_ID) delete_asset '(record { key = "/logo.webp" })'

upload_file:
	./scripts/upload_file.sh certificats/equipe.png "ekip" "Élie" $(CANISTER_NAME) $(DFX_NETWORK)

download_file:
	./scripts/download_file.sh "ekip" img_downloaded.png $(CANISTER_NAME) $(DFX_NETWORK)

list_files:
	dfx canister call $(CANISTER_NAME) listFiles

file_count:
	dfx canister call $(CANISTER_NAME) getStoredFileCount

delete_file:
	dfx canister call $(CANISTER_NAME) deleteFile '("logo.png")'

# Collection Management
init_collection:
	chmod +x scripts/init_collection.sh
	./scripts/init_collection.sh $(CANISTER_NAME) ic

add_item:
	dfx canister call collection --ic addCollectionItem '("Bleu #6", "/thumb_6.webp", "/item_6.webp", "fermeture dorée", "Rare", vec {record{"Aura"; "+100"}})'

list_items:
	dfx canister call $(CANISTER_NAME) getAllCollectionItems

item_count:
	dfx canister call $(CANISTER_NAME) getCollectionItemCount

collection_name:
	dfx canister call $(CANISTER_NAME) getCollectionName

change_theme:
	dfx canister call $(CANISTER_NAME) setTheme '("#1E3A8A", "#3B82F6")'

check_protect_routes:
	dfx canister call --ic $(CANISTER_NAME) listProtectedRoutesSummary

collection_name_update:
	dfx canister call collection --ic setCollectionName '("Collection Ordre d'\''Évorev")'

button_create:
	dfx canister call $(CANISTER_NAME) addButton '("Instagram", "https://www.instagram.com/collections_evorev/")'

buttons_see_all:
	dfx canister call $(CANISTER_NAME) getAllButtons

top-up:
	dfx cycles top-up --ic $(CANISTER_ID) 1T

wallet top-up:
	dfx wallet send --ic $(CANISTER_ID) 1000000000000

logs:
	dfx canister --ic logs $(CANISTER_NAME)

canister_status:
	 dfx canister status --ic $(CANISTER_NAME)
