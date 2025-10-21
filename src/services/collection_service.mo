import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Result "mo:core/Result";
import Principal "mo:core/Principal";
import Collection "../collection";

module {
    public type Service = {
        addItem : (Principal, Text, Text, Text, Text, Text, [(Text, Text)]) -> Nat;
        updateItem : (Principal, Nat, Text, Text, Text, Text, Text, [(Text, Text)]) -> Result.Result<(), Text>;
        deleteItem : (Principal, Nat) -> Result.Result<(), Text>;
        getItem : (Nat) -> ?Collection.Item;
        getAllItems : () -> [Collection.Item];
        getItemCount : () -> Nat;
        setCollectionName : (Principal, Text) -> ();
        setCollectionDescription : (Principal, Text) -> ();
        getCollectionName : () -> Text;
        getCollectionDescription : () -> Text;
    };

    public func make(initializer : Principal, collection : Collection.Collection) : Service {
        {
            addItem = func (caller : Principal, name : Text, thumbnailUrl : Text, imageUrl : Text, description : Text, rarity : Text, attributes : [(Text, Text)]) : Nat {
                assert (caller == initializer);
                collection.addItem(name, thumbnailUrl, imageUrl, description, rarity, attributes);
            };
            updateItem = func (caller : Principal, id : Nat, name : Text, thumbnailUrl : Text, imageUrl : Text, description : Text, rarity : Text, attributes : [(Text, Text)]) : Result.Result<(), Text> {
                assert (caller == initializer);
                collection.updateItem(id, name, thumbnailUrl, imageUrl, description, rarity, attributes);
            };
            deleteItem = func (caller : Principal, id : Nat) : Result.Result<(), Text> {
                assert (caller == initializer);
                collection.deleteItem(id);
            };
            getItem = func (id : Nat) : ?Collection.Item {
                collection.getItem(id);
            };
            getAllItems = func () : [Collection.Item] {
                collection.getAllItems();
            };
            getItemCount = func () : Nat {
                collection.getItemCount();
            };
            setCollectionName = func (caller : Principal, name : Text) {
                assert (caller == initializer);
                collection.setCollectionName(name);
            };
            setCollectionDescription = func (caller : Principal, description : Text) {
                assert (caller == initializer);
                collection.setCollectionDescription(description);
            };
            getCollectionName = func () : Text {
                collection.getCollectionName();
            };
            getCollectionDescription = func () : Text {
                collection.getCollectionDescription();
            };
        }
    };
};
