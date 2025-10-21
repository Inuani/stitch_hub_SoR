import Liminal "mo:liminal";
import Principal "mo:core/Principal";
import Error "mo:core/Error";
import AssetsMiddleware "mo:liminal/Middleware/Assets";
import JWTMiddleware "mo:liminal/Middleware/JWT";
import CORSMiddleware "middleware/cors";
import NFCMiddleware "middleware/nfc";
import HttpAssets "mo:http-assets@0";
import AssetCanister "mo:liminal/AssetCanister";
import ProtectedRoutes "nfc_protec_routes";
import Routes "routes";
import Files "files";
import Collection "collection";
import Result "mo:core/Result";
import Debug "mo:base/Debug";
import RouterMiddleware "mo:liminal/Middleware/Router";
import Theme "utils/theme";
import Buttons "utils/buttons";
import FileService "services/file_service";
import CollectionService "services/collection_service";
import StitchingService "services/stitching_service";
import AssetService "services/asset_service";
import JwtHelper "utils/jwt_helper";
import PendingSessions "utils/pending_sessions";

shared ({ caller = initializer }) persistent actor class Actor() = self {

    transient let canisterId = Principal.fromActor(self);
    transient let canisterIdText = Principal.toText(canisterId);
    type ChunkId = Files.ChunkId;

    var assetStableData = HttpAssets.init_stable_store(canisterId, initializer);
    assetStableData := HttpAssets.upgrade_stable_store(assetStableData);

    let protectedRoutesState = ProtectedRoutes.init();
    transient let protected_routes_storage = ProtectedRoutes.RoutesStorage(protectedRoutesState);

    let fileStorageState = Files.init();
    transient let file_storage = Files.FileStorage(fileStorageState);

    let collectionState = Collection.init();
    transient let collection = Collection.Collection(collectionState);

    let themeState = Theme.init();
    transient let themeManager = Theme.ThemeManager(themeState);

    let buttonsState = Buttons.init();
    transient let buttonsManager = Buttons.ButtonsManager(buttonsState);

    transient let fileService = FileService.make(file_storage);
    transient let collectionService = CollectionService.make(initializer, collection);
    transient let stitchingService = StitchingService.make(collection);
    transient let pendingSessions = PendingSessions.PendingSessions();

    transient let setPermissions : HttpAssets.SetPermissions = {
        commit = [initializer];
        manage_permissions = [initializer];
        prepare = [initializer];
    };
    transient var assetStore = HttpAssets.Assets(assetStableData, ?setPermissions);
    transient var assetCanister = AssetCanister.AssetCanister(assetStore);
    transient let assetService = AssetService.make(assetCanister);

    transient let assetMiddlewareConfig : AssetsMiddleware.Config = {
        store = assetStore;
    };
    transient let jwtVerificationKey = switch (JwtHelper.defaultVerificationKey()) {
        case (#ok(key)) key;
        case (#err(err)) Debug.trap("Failed to decode default JWT verification key: " # err);
    };
    transient let app = Liminal.App({
        middleware = [
            CORSMiddleware.createCORSMiddleware(),
            JWTMiddleware.new({
                validation = {
                    expiration = true;
                    notBefore = false;
                    issuer = #one("collection_d_evorev");
                    signature = #key(jwtVerificationKey);
                    // signature = #skip;
                    audience = #skip;
                };
                locations = [
                    #cookie("stitching_jwt"),
                    #header("Authorization"),
                ];
            }),
            NFCMiddleware.createNFCProtectionMiddleware(protected_routes_storage, pendingSessions, themeManager, canisterIdText),
            AssetsMiddleware.new(assetMiddlewareConfig),
            RouterMiddleware.new(Routes.routerConfig(
                canisterIdText,
                fileService.getFileChunk,
                collection,
                themeManager,
                file_storage,
                buttonsManager,
                pendingSessions
            )),
        ];
        errorSerializer = Liminal.defaultJsonErrorSerializer;
        candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
        logger = Liminal.buildDebugLogger(#info);
    });

    // Http server methods

    public query func http_request(request : Liminal.RawQueryHttpRequest) : async Liminal.RawQueryHttpResponse {
        app.http_request(request);
    };

    public func http_request_update(request : Liminal.RawUpdateHttpRequest) : async Liminal.RawUpdateHttpResponse {
        await* app.http_request_update(request);
    };


    public query func http_request_streaming_callback(token : HttpAssets.StreamingToken) : async HttpAssets.StreamingCallbackResponse {
        switch (assetStore.http_request_streaming_callback(token)) {
            case (#err(e)) throw Error.reject(e);
            case (#ok(response)) response;
        };
    };

    public func upload(chunk : [Nat8]) : async () {
        fileService.upload(chunk);
    };

    public func uploadFinalize(title : Text, artist : Text, contentType : Text) : async Result.Result<Text, Text> {
        fileService.uploadFinalize(title, artist, contentType);
    };

    public query func getFileChunk(title : Text, chunkId : ChunkId) : async ?{
        chunk : [Nat8];
        totalChunks : Nat;
        contentType : Text;
        title : Text;
        artist : Text;
    } {
        fileService.getFileChunk(title, chunkId);
    };

    public query func listFiles() : async [(Text, Text, Text)] {
        fileService.listFiles();
    };

    public func deleteFile(title : Text) : async Bool {
        fileService.deleteFile(title);
    };

    public query func getStoredFileCount() : async Nat {
        fileService.getStoredFileCount();
    };

    // Utility to test JWT minting via management canister ECDSA
    public shared func testMintJwt() : async JwtHelper.MintResult {
        await JwtHelper.mintTestToken();
    };

    // ============================================
    // COLLECTION MANAGEMENT FUNCTIONS (Admin Only)
    // ============================================

    public shared ({ caller }) func addCollectionItem(
        name: Text,
        thumbnailUrl: Text,
        imageUrl: Text,
        description: Text,
        rarity: Text,
        attributes: [(Text, Text)]
    ) : async Nat {
        collectionService.addItem(caller, name, thumbnailUrl, imageUrl, description, rarity, attributes)
    };

    public shared ({ caller }) func updateCollectionItem(
        id: Nat,
        name: Text,
        thumbnailUrl: Text,
        imageUrl: Text,
        description: Text,
        rarity: Text,
        attributes: [(Text, Text)]
    ) : async Result.Result<(), Text> {
        collectionService.updateItem(caller, id, name, thumbnailUrl, imageUrl, description, rarity, attributes)
    };

    public shared ({ caller }) func deleteCollectionItem(id: Nat) : async Result.Result<(), Text> {
        collectionService.deleteItem(caller, id)
    };

    public query func getCollectionItem(id: Nat) : async ?Collection.Item {
        collectionService.getItem(id)
    };

    public query func getAllCollectionItems() : async [Collection.Item] {
        collectionService.getAllItems()
    };

    public query func getCollectionItemCount() : async Nat {
        collectionService.getItemCount()
    };

    public shared ({ caller }) func setCollectionName(name: Text) : async () {
        collectionService.setCollectionName(caller, name)
    };

    public shared ({ caller }) func setCollectionDescription(description: Text) : async () {
        collectionService.setCollectionDescription(caller, description)
    };

    public query func getCollectionName() : async Text {
        collectionService.getCollectionName()
    };

    public query func getCollectionDescription() : async Text {
        collectionService.getCollectionDescription()
    };

    // ============================================
    // PROOF-OF-STITCHING API FUNCTIONS
    // ============================================

    // Get item's token balance
    public query func getItemBalance(itemId: Nat) : async Result.Result<Nat, Text> {
        stitchingService.getItemBalance(itemId)
    };

    // Get item's stitching history
    public query func getItemStitchingHistory(itemId: Nat) : async Result.Result<[Collection.StitchingRecord], Text> {
        stitchingService.getItemStitchingHistory(itemId)
    };

    assetStore.set_streaming_callback(http_request_streaming_callback);

    // public shared query func api_version() : async Nat16 {
    //     assetCanister.api_version();
    // };

    // public shared query func get(args : HttpAssets.GetArgs) : async HttpAssets.EncodedAsset {
    //     assetCanister.get(args);
    // };

    // public shared query func get_chunk(args : HttpAssets.GetChunkArgs) : async (HttpAssets.ChunkContent) {
    //     assetCanister.get_chunk(args);
    // };

    // public shared ({ caller }) func grant_permission(args : HttpAssets.GrantPermission) : async () {
    //     await* assetCanister.grant_permission(caller, args);
    // };

    // public shared ({ caller }) func revoke_permission(args : HttpAssets.RevokePermission) : async () {
    //     await* assetCanister.revoke_permission(caller, args);
    // };

    public shared query func list(args : {}) : async [HttpAssets.AssetDetails] {
        assetService.list(args);
    };

    // public shared ({ caller }) func store(args : HttpAssets.StoreArgs) : async () {
    //     assetCanister.store(caller, args);
    // };

    // public shared ({ caller }) func create_asset(args : HttpAssets.CreateAssetArguments) : async () {
    //     assetCanister.create_asset(caller, args);
    // };

    // public shared ({ caller }) func set_asset_content(args : HttpAssets.SetAssetContentArguments) : async () {
    //     await* assetCanister.set_asset_content(caller, args);
    // };

    // public shared ({ caller }) func unset_asset_content(args : HttpAssets.UnsetAssetContentArguments) : async () {
    //     assetCanister.unset_asset_content(caller, args);
    // };

    public shared ({ caller }) func delete_asset(args : HttpAssets.DeleteAssetArguments) : async () {
        assetService.deleteAsset(caller, args);
    };

    // public shared ({ caller }) func set_asset_properties(args : HttpAssets.SetAssetPropertiesArguments) : async () {
    //     assetCanister.set_asset_properties(caller, args);
    // };

    // public shared ({ caller }) func clear(args : HttpAssets.ClearArguments) : async () {
    //     assetCanister.clear(caller, args);
    // };

    public shared ({ caller }) func create_batch(args : {}) : async (HttpAssets.CreateBatchResponse) {
        assetService.createBatch(caller, args);
    };

    public shared ({ caller }) func create_chunk(args : HttpAssets.CreateChunkArguments) : async (HttpAssets.CreateChunkResponse) {
        assetService.createChunk(caller, args);
    };

    public shared ({ caller }) func create_chunks(args : HttpAssets.CreateChunksArguments) : async HttpAssets.CreateChunksResponse {
        await assetService.createChunks(caller, args);
    };

    public shared ({ caller }) func commit_batch(args : HttpAssets.CommitBatchArguments) : async () {
        await assetService.commitBatch(caller, args);
    };

    // public shared ({ caller }) func propose_commit_batch(args : HttpAssets.CommitBatchArguments) : async () {
    //     assetCanister.propose_commit_batch(caller, args);
    // };

    // public shared ({ caller }) func commit_proposed_batch(args : HttpAssets.CommitProposedBatchArguments) : async () {
    //     await* assetCanister.commit_proposed_batch(caller, args);
    // };

    // public shared ({ caller }) func compute_evidence(args : HttpAssets.ComputeEvidenceArguments) : async (?Blob) {
    //     await* assetCanister.compute_evidence(caller, args);
    // };

    // public shared ({ caller }) func delete_batch(args : HttpAssets.DeleteBatchArguments) : async () {
    //     assetCanister.delete_batch(caller, args);
    // };

    // public shared func list_permitted(args : HttpAssets.ListPermitted) : async ([Principal]) {
    //     assetCanister.list_permitted(args);
    // };

    // public shared ({ caller }) func take_ownership() : async () {
    //     await* assetCanister.take_ownership(caller);
    // };

    // public shared ({ caller }) func get_configuration() : async (HttpAssets.ConfigurationResponse) {
    //     assetCanister.get_configuration(caller);
    // };

    // public shared ({ caller }) func configure(args : HttpAssets.ConfigureArguments) : async () {
    //     assetCanister.configure(caller, args);
    // };

    // public shared func certified_tree(args : {}) : async (HttpAssets.CertifiedTree) {
    //     assetCanister.certified_tree(args);
    // };
    // public shared func validate_grant_permission(args : HttpAssets.GrantPermission) : async (Result.Result<Text, Text>) {
    //     assetCanister.validate_grant_permission(args);
    // };

    // public shared func validate_revoke_permission(args : HttpAssets.RevokePermission) : async (Result.Result<Text, Text>) {
    //     assetCanister.validate_revoke_permission(args);
    // };

    // public shared func validate_take_ownership() : async (Result.Result<Text, Text>) {
    //     assetCanister.validate_take_ownership();
    // };

    // public shared func validate_commit_proposed_batch(args : HttpAssets.CommitProposedBatchArguments) : async (Result.Result<Text, Text>) {
    //     assetCanister.validate_commit_proposed_batch(args);
    // };

    // public shared func validate_configure(args : HttpAssets.ConfigureArguments) : async (Result.Result<Text, Text>) {
    //     assetCanister.validate_configure(args);
    // };

    public shared ({ caller }) func add_protected_route(path : Text) : async () {
        assert (caller == initializer);
        ignore protected_routes_storage.addProtectedRoute(path);
    };

    public shared ({ caller }) func update_route_cmacs(path : Text, new_cmacs : [Text]) : async () {
        assert (caller == initializer);
        ignore protected_routes_storage.updateRouteCmacs(path, new_cmacs);
    };

    public shared ({ caller }) func append_route_cmacs(path : Text, new_cmacs : [Text]) : async () {
        assert (caller == initializer);
        ignore protected_routes_storage.appendRouteCmacs(path, new_cmacs);
    };

    public query func get_route_protection(path : Text) : async ?ProtectedRoutes.ProtectedRoute {
        protected_routes_storage.getRoute(path);
    };

    public query func get_route_cmacs(path : Text) : async [Text] {
        protected_routes_storage.getRouteCmacs(path);
    };

    public query func listProtectedRoutesSummary() : async [(Text, Nat)] {
        protected_routes_storage.listProtectedRoutesSummary();
    };

    // ============================================
    // THEME MANAGEMENT FUNCTIONS (Admin Only)
    // ============================================

    public shared ({ caller }) func setTheme(primary: Text, secondary: Text) : async Theme.Theme {
        assert (caller == initializer);
        themeManager.setTheme(primary, secondary)
    };

    public query func getTheme() : async Theme.Theme {
        themeManager.getTheme()
    };

    public shared ({ caller }) func resetTheme() : async Theme.Theme {
        assert (caller == initializer);
        themeManager.resetTheme()
    };

    // ============================================
    // BUTTONS MANAGEMENT FUNCTIONS (Admin Only)
    // ============================================

    public shared ({ caller }) func addButton(buttonText: Text, buttonLink: Text) : async Nat {
        assert (caller == initializer);
        buttonsManager.addButton(buttonText, buttonLink)
    };

    public shared ({ caller }) func updateButton(index: Nat, buttonText: Text, buttonLink: Text) : async Bool {
        assert (caller == initializer);
        buttonsManager.updateButton(index, buttonText, buttonLink)
    };

    public shared ({ caller }) func deleteButton(index: Nat) : async Bool {
        assert (caller == initializer);
        buttonsManager.deleteButton(index)
    };

    public query func getButton(index: Nat) : async ?Buttons.Button {
        buttonsManager.getButton(index)
    };

    public query func getAllButtons() : async [Buttons.Button] {
        buttonsManager.getAllButtons()
    };

    public query func getButtonCount() : async Nat {
        buttonsManager.getButtonCount()
    };

    public shared ({ caller }) func clearAllButtons() : async () {
        assert (caller == initializer);
        buttonsManager.clearAllButtons()
    };

};
