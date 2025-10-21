import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Result "mo:core/Result";
import Files "../files";

module {
    public type Service = {
        upload : ([Nat8]) -> ();
        uploadFinalize : (Text, Text, Text) -> Result.Result<Text, Text>;
        getFileChunk : (Text, Files.ChunkId) -> ?{
            chunk : [Nat8];
            totalChunks : Nat;
            contentType : Text;
            title : Text;
            artist : Text;
        };
        listFiles : () -> [(Text, Text, Text)];
        deleteFile : (Text) -> Bool;
        getStoredFileCount : () -> Nat;
    };

    public func make(fileStorage : Files.FileStorage) : Service {
        {
            upload = func (chunk : [Nat8]) {
                fileStorage.upload(chunk);
            };
            uploadFinalize = func (title : Text, artist : Text, contentType : Text) : Result.Result<Text, Text> {
                fileStorage.uploadFinalize(title, artist, contentType);
            };
            getFileChunk = func (title : Text, chunkId : Files.ChunkId) : ?{
                chunk : [Nat8];
                totalChunks : Nat;
                contentType : Text;
                title : Text;
                artist : Text;
            } {
                fileStorage.getFileChunk(title, chunkId);
            };
            listFiles = func () : [(Text, Text, Text)] {
                fileStorage.listFiles();
            };
            deleteFile = func (title : Text) : Bool {
                fileStorage.deleteFile(title);
            };
            getStoredFileCount = func () : Nat {
                fileStorage.getStoredFileCount();
            };
        }
    };
};
