import Text "mo:core/Text";

module {
    // Theme colors type
    public type Theme = {
        primary: Text;
        secondary: Text;
    };

    // State type for persistence
    public type State = {
        var primary: Text;
        var secondary: Text;
    };

    // Initialize state with default theme
    public func init() : State = {
        var primary = "#3B82F6";   // Blue
        var secondary = "#10B981"; // Green
    };

    // Theme class that manages colors
    public class ThemeManager(state: State) {
        // Get current theme
        public func getTheme() : Theme {
            {
                primary = state.primary;
                secondary = state.secondary;
            }
        };

        // Set new theme colors
        public func setTheme(primary: Text, secondary: Text) : Theme {
            state.primary := primary;
            state.secondary := secondary;
            {
                primary = state.primary;
                secondary = state.secondary;
            }
        };

        // Get primary color
        public func getPrimary() : Text {
            state.primary
        };

        // Get secondary color
        public func getSecondary() : Text {
            state.secondary
        };

        // Reset to default theme
        public func resetTheme() : Theme {
            state.primary := "#3B82F6";
            state.secondary := "#10B981";
            {
                primary = state.primary;
                secondary = state.secondary;
            }
        };
    };
}
