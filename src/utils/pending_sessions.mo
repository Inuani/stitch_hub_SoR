import HashMap "mo:base/HashMap";
import Text "mo:core/Text";
import TextBase "mo:base/Text";
import Int "mo:core/Int";
import Nat "mo:core/Nat";
import StitchingToken "stitching_token";

module {
    public type Session = {
        items : [StitchingToken.SessionItem];
        startTime : Int;
        expiresAt : Int;
        ttlSeconds : Nat;
        createdAt : Int;
        hostCanisterId : Text;
        sessionNonce : Text;
    };

    public class PendingSessions() {
        let store = HashMap.HashMap<Text, Session>(32, TextBase.equal, TextBase.hash);

        public func put(id : Text, session : Session) {
            store.put(id, session);
        };

        public func get(id : Text, now : Int) : ?Session {
            switch (store.get(id)) {
                case null { null };
                case (?session) {
                    if (isExpired(session, now)) {
                        ignore store.remove(id);
                        null;
                    } else {
                        ?session;
                    };
                };
            }
        };

        public func remove(id : Text) {
            ignore store.remove(id);
        };

        private func isExpired(session : Session, now : Int) : Bool {
            let ttlNanos = Int.fromNat(session.ttlSeconds) * 1_000_000_000;
            now >= session.expiresAt or now - session.createdAt > ttlNanos;
        };
    };
};
