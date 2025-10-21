import Text "mo:core/Text";
import Array "mo:core/Array";

module {
    // Button type for external links
    public type Button = {
        text : Text;
        link : Text;
    };

    // State type for persistence
    public type State = {
        var buttons : [Button];
    };

    // Initialize state with default buttons
    public func init() : State = {
        var buttons = [
            // {
            //     text = "Rejoins la communauté d'Évorev";
            //     link = "https://discord.gg/";
            // }
        ];
    };

    // ButtonsManager class that manages button list
    public class ButtonsManager(state : State) {

        // Add a new button and return its index
        public func addButton(btnText : Text, btnLink : Text) : Nat {
            let newButton : Button = {
                text = btnText;
                link = btnLink;
            };
            state.buttons := Array.concat(state.buttons, [newButton]);
            state.buttons.size() - 1
        };

        // Update an existing button at the given index
        public func updateButton(index : Nat, btnText : Text, btnLink : Text) : Bool {
            if (index >= state.buttons.size()) {
                return false;
            };
            state.buttons := Array.tabulate<Button>(
                state.buttons.size(),
                func(i : Nat) : Button {
                    if (i == index) {
                        {
                            text = btnText;
                            link = btnLink;
                        }
                    } else {
                        state.buttons[i]
                    }
                }
            );
            true
        };

        // Delete a button at the given index
        public func deleteButton(index : Nat) : Bool {
            if (index >= state.buttons.size()) {
                return false;
            };
            state.buttons := Array.tabulate<Button>(
                state.buttons.size() - 1,
                func(i : Nat) : Button {
                    if (i < index) {
                        state.buttons[i]
                    } else {
                        state.buttons[i + 1]
                    }
                }
            );
            true
        };

        // Get a specific button by index
        public func getButton(index : Nat) : ?Button {
            if (index < state.buttons.size()) {
                ?state.buttons[index]
            } else {
                null
            }
        };

        // Get all buttons
        public func getAllButtons() : [Button] {
            state.buttons
        };

        // Get total button count
        public func getButtonCount() : Nat {
            state.buttons.size()
        };

        // Clear all buttons
        public func clearAllButtons() : () {
            state.buttons := [];
        };
    };
}
