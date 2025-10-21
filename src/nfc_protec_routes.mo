import Text "mo:core/Text";
import Map "mo:core/Map";
import Iter "mo:core/Iter";
import Array "mo:core/Array";
import Option "mo:core/Option";
import Scan "utils/scan";

module {
    public type ProtectedRoute = {
        path : Text;
        cmacs_ : [Text];
        scan_count_ : Nat;
    };

    public type State = {
        var protected_routes : [(Text, ProtectedRoute)];
    };

    public func init() : State = {
        var protected_routes = [];
    };

    public class RoutesStorage(state : State) {
        private var routes = Map.fromIter<Text, ProtectedRoute>(
            state.protected_routes.values(),
            Text.compare,
        );

        public func addProtectedRoute(path : Text) : Bool {
            if (Option.isNull(Map.get(routes, Text.compare, path))) {
                let new_route : ProtectedRoute = {
                    path;
                    cmacs_ = [];
                    scan_count_ = 0;
                };
                Map.add(routes, Text.compare, path, new_route);
                updateState();
                true;
            } else {
                false;
            };
        };

        public func updateRouteCmacs(path : Text, new_cmacs : [Text]) : Bool {
            switch (Map.get(routes, Text.compare, path)) {
                case (?existing) {
                    Map.add(
                        routes,
                        Text.compare,
                        path,
                        {
                            path = existing.path;
                            cmacs_ = new_cmacs;
                            scan_count_ = existing.scan_count_;
                        },
                    );
                    updateState();
                    true;
                };
                case null {
                    false;
                };
            };
        };

        public func appendRouteCmacs(path : Text, new_cmacs : [Text]) : Bool {
            switch (Map.get(routes, Text.compare, path)) {
                case (?existing) {
                    Map.add(
                        routes,
                        Text.compare,
                        path,
                        {
                            path = existing.path;
                            cmacs_ = Array.concat(existing.cmacs_, new_cmacs);
                            scan_count_ = existing.scan_count_;
                        },
                    );
                    updateState();
                    true;
                };
                case null {
                    false;
                };
            };
        };

        public func getRoute(path : Text) : ?ProtectedRoute {
            Map.get(routes, Text.compare, path);
        };

        public func getRouteCmacs(path : Text) : [Text] {
            switch (Map.get(routes, Text.compare, path)) {
                case (?route) {
                    route.cmacs_;
                };
                case null { [] };
            };
        };

        public func updateScanCount(path : Text, new_count : Nat) : Bool {
            switch (Map.get(routes, Text.compare, path)) {
                case (?existing) {
                    Map.add(
                        routes,
                        Text.compare,
                        path,
                        {
                            path = existing.path;
                            cmacs_ = existing.cmacs_;
                            scan_count_ = new_count;
                        },
                    );
                    updateState();
                    true;
                };
                case null {
                    false;
                };
            };
        };

        public func verifyRouteAccess(path : Text, url : Text) : Bool {
            switch (Map.get(routes, Text.compare, path)) {
                case (?route) {
                    let counter = Scan.scan(route.cmacs_, url, route.scan_count_);
                    if (counter > 0) {
                        ignore updateScanCount(path, counter);
                        true;
                    } else {
                        false;
                    };
                };
                case null {
                    false;
                };
            };
        };

        public func listProtectedRoutes() : [(Text, ProtectedRoute)] {
            Iter.toArray(Map.entries(routes));
        };

        // Returns only path and scan count, without cmacs
        public func listProtectedRoutesSummary() : [(Text, Nat)] {
            let entries = Iter.toArray(Map.entries(routes));
            Array.map<(Text, ProtectedRoute), (Text, Nat)>(
                entries,
                func((path, route)) : (Text, Nat) {
                    (path, route.scan_count_)
                }
            )
        };

        public func isProtectedRoute(url : Text) : Bool {
            Option.isSome(Array.find<(Text, ProtectedRoute)>(
                Iter.toArray(Map.entries(routes)),
                func((path, _)) : Bool {
                    Text.contains(url, #text path);
                },
            ));
        };

        private func updateState() {
            state.protected_routes := Iter.toArray(Map.entries(routes));
        };

        public func getState() : State {
            state;
        };
    };
};
