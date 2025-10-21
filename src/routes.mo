
import Router       "mo:liminal/Router";
import RouteContext "mo:liminal/RouteContext";
import Liminal      "mo:liminal";
import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Blob "mo:core/Blob";
import Array "mo:core/Array";
// import Route "mo:liminal/Route";
import Collection "collection";
import CollectionView "collection_view";
import Home "home";
import Theme "utils/theme";
import Files "files";
import Buttons "utils/buttons";
import StitchingRoutes "stitching_routes";
import PendingSessions "utils/pending_sessions";

module Routes {
   public func routerConfig(
       canisterId: Text,
       getFileChunk: (Text, Nat) -> ?{
           chunk : [Nat8];
           totalChunks : Nat;
           contentType : Text;
           title : Text;
           artist : Text;
       },
       collection: Collection.Collection,
       themeManager: Theme.ThemeManager,
       fileStorage: Files.FileStorage,
       buttonsManager: Buttons.ButtonsManager,
       pendingSessions: PendingSessions.PendingSessions
   ) : Router.Config {
    {
      prefix              = null;
      identityRequirement = null;
      routes = Array.flatten([
        [Router.getQuery("/",
          func(ctx: RouteContext.RouteContext) : Liminal.HttpResponse {
            Home.homePage(ctx, canisterId, collection.getCollectionName(), themeManager, buttonsManager.getAllButtons())
          }
        ),
        Router.getQuery("/item/{id}", func(ctx: RouteContext.RouteContext) : Liminal.HttpResponse {
                   let idText = ctx.getRouteParam("id");

                   let id = switch (Nat.fromText(idText)) {
                       case (?num) num;
                       case null {
                           let html = CollectionView.generateNotFoundPage(0, themeManager);
                           return ctx.buildResponse(#notFound, #html(html));
                       };
                   };

                   let html = CollectionView.generateItemPage(collection, id, themeManager);
                   ctx.buildResponse(#ok, #html(html))
               }),
               Router.getQuery("/collection", func(ctx: RouteContext.RouteContext) : Liminal.HttpResponse {
                   let html = CollectionView.generateCollectionPage(collection, themeManager);
                   ctx.buildResponse(#ok, #html(html))
               }),

        ],

        // Stitching routes (extracted to separate module)
        StitchingRoutes.getStitchingRoutes(collection, themeManager, pendingSessions, canisterId),

        [

        // Serve individual file chunks as raw bytes for reconstruction
        // MUST come before /files/{filename} route to match correctly
        Router.getQuery("/files/{filename}/chunk/{chunkId}", func(ctx: RouteContext.RouteContext) : Liminal.HttpResponse {
            let filename = ctx.getRouteParam("filename");
            let chunkIdText = ctx.getRouteParam("chunkId");

            switch (Nat.fromText(chunkIdText)) {
                case (?chunkId) {
                    switch (getFileChunk(filename, chunkId)) {
                        case (?chunkData) {
                            {
                                statusCode = 200;
                                headers = [
                                    ("Content-Type", "application/octet-stream"),
                                    ("Cache-Control", "public, max-age=31536000")
                                ];
                                body = ?Blob.fromArray(chunkData.chunk);
                                streamingStrategy = null;
                            }
                        };
                        case null {
                            ctx.buildResponse(#notFound, #error(#message("Chunk not found")))
                        };
                    }
                };
                case null {
                    ctx.buildResponse(#badRequest, #error(#message("Invalid chunk ID")))
                };
            }

        }),

        // Serve backend-stored files with NFC protection support
        // Works with query parameters for NFC: /files/filename?uid=...&cmac=...&ctr=...
        Router.getQuery("/files/{filename}", func(ctx: RouteContext.RouteContext) : Liminal.HttpResponse {
            let filename = ctx.getRouteParam("filename");

            // Get first chunk to check if file exists
            switch (getFileChunk(filename, 0)) {
                case (?fileInfo) {
                    // Generate HTML page using files.mo
                    let html = fileStorage.generateFilePage(filename, fileInfo, collection);
                    ctx.buildResponse(#ok, #html(html))
                };
                case null {
                    ctx.buildResponse(#notFound, #error(#message("File not found")))
                };
            };
        }),

        Router.getQuery("/{path}",
          func(ctx) : Liminal.HttpResponse {
            ctx.buildResponse(#notFound, #error(#message("Not found")))
          }
        ),
      ]]);
    }
  }
}
