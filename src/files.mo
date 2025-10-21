import Text "mo:core/Text";
import Array "mo:core/Array";
import Map "mo:core/Map";
import Result "mo:core/Result";
import Iter "mo:core/Iter";
import List "mo:core/List";
import Nat "mo:core/Nat";
import Option "mo:core/Option";
import Nat32 "mo:core/Nat32";
import Nat8 "mo:core/Nat8";
import Char "mo:core/Char";
import Collection "collection";

module {

    public type ChunkId = Nat;
    public type FileChunk = [Nat8];

    public type StoredFile = {
        title : Text;
        artist : Text;
        contentType : Text;
        totalChunks : Nat;
        data : [FileChunk];
    };

    public type State = {
        var storedFiles : [(Text, StoredFile)];
    };

    public func init() : State = {
        var storedFiles = [];
    };

    public class FileStorage(state : State) {
        private let maxFiles : Nat = 10;
        private let chunkSize : Nat = 2000000;
        private var buffer = List.empty<Nat8>();
        private var storedFiles = Map.fromIter<Text, StoredFile>(
            state.storedFiles.values(),
            Text.compare,
        );

        public func upload(chunk : [Nat8]) {
            for (byte in chunk.vals()) {
                List.add(buffer, byte);
            };
        };

        public func uploadFinalize(title : Text, artist : Text, contentType : Text) : Result.Result<Text, Text> {
            if (Map.size(storedFiles) >= maxFiles and Option.isNull(Map.get(storedFiles, Text.compare, title))) {
                return #err("Maximum number of files reached");
            };

            let data = List.toArray(buffer);
            let totalChunks = Nat.max(1, (data.size() + chunkSize) / chunkSize);
            var chunks : [FileChunk] = [];
            var i = 0;

            while (i < data.size()) {
                let end = Nat.min(i + chunkSize, data.size());
                let chunk = Array.tabulate<Nat8>(end - i, func(j) = data[i + j]);
                chunks := Array.concat(chunks, [chunk]);
                i += chunkSize;
            };

            Map.add(
                storedFiles,
                Text.compare,
                title,
                {
                    title;
                    artist;
                    contentType;
                    totalChunks;
                    data = chunks;
                },
            );

            state.storedFiles := Iter.toArray(Map.entries(storedFiles));
            List.clear(buffer);
            #ok("Upload successful");
        };

        public func getFileChunk(title : Text, chunkId : ChunkId) : ?{
            chunk : [Nat8];
            totalChunks : Nat;
            contentType : Text;
            title : Text;
            artist : Text;
        } {
            switch (Map.get(storedFiles, Text.compare, title)) {
                case (null) { null };
                case (?file) {
                    if (chunkId >= file.data.size()) return null;
                    ?{
                        chunk = file.data[chunkId];
                        totalChunks = file.totalChunks;
                        contentType = file.contentType;
                        title = file.title;
                        artist = file.artist;
                    };
                };
            };
        };

        public func listFiles() : [(Text, Text, Text)] {
            let entries = Iter.toArray(Map.entries(storedFiles));
            Array.map<(Text, StoredFile), (Text, Text, Text)>(
                entries,
                func((title, file)) = (title, file.artist, file.contentType),
            );
        };

        public func deleteFile(title : Text) : Bool {
            switch (Map.take(storedFiles, Text.compare, title)) {
                case (null) { false };
                case (?_) {
                    state.storedFiles := Iter.toArray(Map.entries(storedFiles));
                    true;
                };
            };
        };

        public func getStoredFileCount() : Nat {
            Map.size(storedFiles);
        };

        // Get file as base64 data URL for embedding in HTML
        public func getFileAsDataUrl(title : Text) : ?Text {
            switch (Map.get(storedFiles, Text.compare, title)) {
                case (null) { null };
                case (?file) {
                    // Reconstruct full file from chunks
                    var allBytes : [Nat8] = [];
                    for (chunk in file.data.vals()) {
                        allBytes := Array.concat(allBytes, chunk);
                    };

                    // Convert to base64
                    let base64 = bytesToBase64(allBytes);

                    // Return as data URL
                    ?("data:" # file.contentType # ";base64," # base64);
                };
            };
        };

        // Helper function to convert bytes to base64
        private func bytesToBase64(bytes : [Nat8]) : Text {
            let base64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
            var result = "";
            var i = 0;

            while (i < bytes.size()) {
                let b1 = bytes[i];
                let b2 : Nat8 = if (i + 1 < bytes.size()) bytes[i + 1] else 0;
                let b3 : Nat8 = if (i + 2 < bytes.size()) bytes[i + 2] else 0;

                let n = (Nat32.fromNat(Nat8.toNat(b1)) << 16) |
                        (Nat32.fromNat(Nat8.toNat(b2)) << 8) |
                        Nat32.fromNat(Nat8.toNat(b3));

                let c1 = Nat32.toNat((n >> 18) & 63);
                let c2 = Nat32.toNat((n >> 12) & 63);
                let c3 = Nat32.toNat((n >> 6) & 63);
                let c4 = Nat32.toNat(n & 63);

                result #= Text.fromChar(charAt(base64Chars, c1));
                result #= Text.fromChar(charAt(base64Chars, c2));

                if (i + 1 < bytes.size()) {
                    result #= Text.fromChar(charAt(base64Chars, c3));
                } else {
                    result #= "=";
                };

                if (i + 2 < bytes.size()) {
                    result #= Text.fromChar(charAt(base64Chars, c4));
                } else {
                    result #= "=";
                };

                i += 3;
            };

            result;
        };

        private func charAt(str : Text, index : Nat) : Char {
            var i = 0;
            for (c in str.chars()) {
                if (i == index) return c;
                i += 1;
            };
            ' '; // Should never reach here with valid input
        };

        // Generate HTML page for file display
        public func generateFilePage(
            filename: Text,
            fileInfo: {
                chunk : [Nat8];
                totalChunks : Nat;
                contentType : Text;
                title : Text;
                artist : Text;
            },
            collection: Collection.Collection
        ) : Text {
            // Extract item number from filename (e.g., certificat_0 -> 0)
            let itemNumberText = Text.replace(filename, #text("certificat_"), "");

            // Get item name from collection
            let itemDisplay = switch (Nat.fromText(itemNumberText)) {
                case (?itemId) {
                    switch (collection.getItem(itemId)) {
                        case (?item) item.name;
                        case null itemNumberText;
                    };
                };
                case null itemNumberText;
            };

            // Generate HTML based on file size (single chunk vs multi-chunk)
            if (fileInfo.totalChunks == 1) {
                generateSingleChunkPage(filename, itemNumberText, itemDisplay, fileInfo)
            } else {
                generateMultiChunkPage(filename, itemNumberText, itemDisplay, fileInfo)
            }
        };

        // Generate page for single chunk files (< 2MB)
        private func generateSingleChunkPage(
            filename: Text,
            itemNumberText: Text,
            itemDisplay: Text,
            fileInfo: {
                chunk : [Nat8];
                totalChunks : Nat;
                contentType : Text;
                title : Text;
                artist : Text;
            }
        ) : Text {
            "<!DOCTYPE html><html><head>"
            # "<meta charset='UTF-8'>"
            # "<meta name='viewport' content='width=device-width,initial-scale=1.0'>"
            # "<title>" # filename # "</title>"
            # "<style>"
            # "*{margin:0;padding:0;box-sizing:border-box;}"
            # "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#fff;min-height:100vh;display:flex;flex-direction:column;}"
            # ".container{flex:1;display:flex;flex-direction:column;width:100%;max-width:100vw;padding:20px;}"
            # ".back-link{display:inline-block;margin-bottom:1rem;color:#2563eb;text-decoration:none;font-weight:500;}"
            # ".back-link:hover{text-decoration:underline;}"
            # ".certificate-text{text-align:center;margin-bottom:1rem;font-size:16px;color:#1f2937;}"
            # ".media-container{flex:1;display:flex;justify-content:center;align-items:center;background:#fff;}"
            # "#media{width:100%;height:100%;display:flex;justify-content:center;align-items:center;}"
            # "img{max-width:100%;max-height:calc(100vh - 120px);width:auto;height:auto;object-fit:contain;display:block;}"
            # "audio,video{max-width:100%;}"
            # "</style>"
            # "</head><body>"
            # "<div class='container'>"
            # "<a href='/item/" # itemNumberText # "' class='back-link'>Retour à " # itemDisplay # "</a>"
            # "<div class='certificate-text'>Scan valide - certificat d'authenticité pour l'item " # itemDisplay # " :</div>"
            # "<div class='media-container'><div id='media'></div></div>"
            # "</div>"
            # "<script>"
            # "const filename='" # filename # "';"
            # "const contentType='" # fileInfo.contentType # "';"
            # "const baseUrl=window.location.protocol+'//'+window.location.host;"
            # "async function load(){"
            # "const media=document.getElementById('media');"
            # "try{"
            # "const url=baseUrl+'/files/'+filename+'/chunk/0';"
            # "const response=await fetch(url);"
            # "if(!response.ok)throw new Error('Failed to load: HTTP '+response.status);"
            # "const arrayBuffer=await response.arrayBuffer();"
            # "const bytes=new Uint8Array(arrayBuffer);"
            # "const blob=new Blob([bytes],{type:contentType});"
            # "const blobUrl=URL.createObjectURL(blob);"
            # "let element;"
            # "if(contentType.startsWith('image/')){element=document.createElement('img');}"
            # "else if(contentType.startsWith('audio/')){element=document.createElement('audio');element.controls=true;}"
            # "else if(contentType.startsWith('video/')){element=document.createElement('video');element.controls=true;}"
            # "else{element=document.createElement('img');}"
            # "element.src=blobUrl;"
            # "media.appendChild(element);"
            # "}catch(e){console.error(e);}"
            # "}"
            # "load();"
            # "</script>"
            # "</body></html>"
        };

        // Generate page for multi-chunk files (> 2MB)
        private func generateMultiChunkPage(
            filename: Text,
            itemNumberText: Text,
            itemDisplay: Text,
            fileInfo: {
                chunk : [Nat8];
                totalChunks : Nat;
                contentType : Text;
                title : Text;
                artist : Text;
            }
        ) : Text {
            "<!DOCTYPE html><html><head>"
            # "<meta charset='UTF-8'>"
            # "<meta name='viewport' content='width=device-width,initial-scale=1.0'>"
            # "<title>" # filename # "</title>"
            # "<style>"
            # "*{margin:0;padding:0;box-sizing:border-box;}"
            # "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#fff;min-height:100vh;display:flex;flex-direction:column;}"
            # ".container{flex:1;display:flex;flex-direction:column;width:100%;max-width:100vw;padding:20px;}"
            # ".back-link{display:inline-block;margin-bottom:1rem;color:#2563eb;text-decoration:none;font-weight:500;}"
            # ".back-link:hover{text-decoration:underline;}"
            # ".certificate-text{text-align:center;margin-bottom:1rem;font-size:16px;color:#1f2937;}"
            # ".media-container{flex:1;display:flex;justify-content:center;align-items:center;background:#fff;}"
            # "#media{width:100%;height:100%;display:flex;justify-content:center;align-items:center;}"
            # "img{max-width:100%;max-height:calc(100vh - 120px);width:auto;height:auto;object-fit:contain;display:block;}"
            # "audio,video{max-width:100%;}"
            # "</style>"
            # "</head><body>"
            # "<div class='container'>"
            # "<a href='/item/" # itemNumberText # "' class='back-link'>Retour à " # itemDisplay # "</a>"
            # "<div class='certificate-text'>Scan valide - certificat d'authenticité pour l'item " # itemDisplay # " :</div>"
            # "<div class='media-container'><div id='media'></div></div>"
            # "</div>"
            # "<script>"
            # "const filename='" # filename # "';"
            # "const totalChunks=" # Nat.toText(fileInfo.totalChunks) # ";"
            # "const contentType='" # fileInfo.contentType # "';"
            # "const baseUrl=window.location.protocol+'//'+window.location.host;"
            # "async function load(){"
            # "const media=document.getElementById('media');"
            # "try{"
            # "const chunks=[];"
            # "for(let i=0;i<totalChunks;i++){"
            # "const url=baseUrl+'/files/'+filename+'/chunk/'+i;"
            # "const response=await fetch(url);"
            # "if(!response.ok)throw new Error('Chunk '+i+' failed: HTTP '+response.status);"
            # "const arrayBuffer=await response.arrayBuffer();"
            # "const bytes=new Uint8Array(arrayBuffer);"
            # "chunks.push(bytes);"
            # "}"
            # "const totalBytes=chunks.reduce((acc,chunk)=>acc+chunk.length,0);"
            # "const combined=new Uint8Array(totalBytes);"
            # "let offset=0;"
            # "for(const chunk of chunks){combined.set(chunk,offset);offset+=chunk.length;}"
            # "const blob=new Blob([combined],{type:contentType});"
            # "const blobUrl=URL.createObjectURL(blob);"
            # "let element;"
            # "if(contentType.startsWith('image/')){element=document.createElement('img');}"
            # "else if(contentType.startsWith('audio/')){element=document.createElement('audio');element.controls=true;}"
            # "else if(contentType.startsWith('video/')){element=document.createElement('video');element.controls=true;}"
            # "else{element=document.createElement('img');}"
            # "element.src=blobUrl;"
            # "media.appendChild(element);"
            # "}catch(e){console.error(e);}"
            # "}"
            # "load();"
            # "</script>"
            # "</body></html>"
        };
    };
};
