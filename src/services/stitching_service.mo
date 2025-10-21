import Nat "mo:core/Nat";
import Text "mo:core/Text";
import Result "mo:core/Result";
import Collection "../collection";

module {
    public type Service = {
        getItemBalance : (Nat) -> Result.Result<Nat, Text>;
        getItemStitchingHistory : (Nat) -> Result.Result<[Collection.StitchingRecord], Text>;
    };

    public func make(collection : Collection.Collection) : Service {
        {
            getItemBalance = func (itemId : Nat) : Result.Result<Nat, Text> {
                collection.getItemBalance(itemId);
            };
            getItemStitchingHistory = func (itemId : Nat) : Result.Result<[Collection.StitchingRecord], Text> {
                collection.getItemStitchingHistory(itemId);
            };
        }
    };
};
