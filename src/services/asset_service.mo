import Principal "mo:core/Principal";
import HttpAssets "mo:http-assets@0";
import AssetCanister "mo:liminal/AssetCanister";

module {
    public type Service = {
        list : ({}) -> [HttpAssets.AssetDetails];
        deleteAsset : (Principal, HttpAssets.DeleteAssetArguments) -> ();
        createBatch : (Principal, {}) -> HttpAssets.CreateBatchResponse;
        createChunk : (Principal, HttpAssets.CreateChunkArguments) -> HttpAssets.CreateChunkResponse;
        createChunks : (Principal, HttpAssets.CreateChunksArguments) -> async HttpAssets.CreateChunksResponse;
        commitBatch : (Principal, HttpAssets.CommitBatchArguments) -> async ();
    };

    public func make(assetCanister : AssetCanister.AssetCanister) : Service {
        {
            list = func (args : {}) : [HttpAssets.AssetDetails] {
                assetCanister.list(args);
            };
            deleteAsset = func (caller : Principal, args : HttpAssets.DeleteAssetArguments) {
                assetCanister.delete_asset(caller, args);
            };
            createBatch = func (caller : Principal, args : {}) : HttpAssets.CreateBatchResponse {
                assetCanister.create_batch(caller, args);
            };
            createChunk = func (caller : Principal, args : HttpAssets.CreateChunkArguments) : HttpAssets.CreateChunkResponse {
                assetCanister.create_chunk(caller, args);
            };
            createChunks = func (caller : Principal, args : HttpAssets.CreateChunksArguments) : async HttpAssets.CreateChunksResponse {
                await* assetCanister.create_chunks(caller, args);
            };
            commitBatch = func (caller : Principal, args : HttpAssets.CommitBatchArguments) : async () {
                await* assetCanister.commit_batch(caller, args);
            };
        }
    };
};
