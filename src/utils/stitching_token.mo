import Nat "mo:core/Nat";
import Int "mo:core/Int";
import Float "mo:core/Float";
import Array "mo:core/Array";
import Iter "mo:core/Iter";
import Text "mo:core/Text";
import Json "mo:json@1";
import JWT "mo:jwt@2";
import Identity "mo:liminal/Identity";
import Random "mo:base/Random";
import Blob "mo:core/Blob";
import BaseX "mo:base-x-encoder";

module {
    public type SessionItem = {
        canisterId : Text;
        itemId : Nat;
    };

    public type StitchingState = {
        sessionId : ?Text;
        issuedAt : ?Int;
        expiresAt : ?Int;
        hostCanisterId : ?Text;
        sessionNonce : ?Text;
    };

    public type ClaimInput = {
        issuer : Text;
        subject : Text;
        sessionId : Text;
        now : Int;
        ttlSeconds : Nat;
        hostCanisterId : Text;
        sessionNonce : Text;
    };

    public type StitchingClaims = {
        issuer : Text;
        subject : Text;
        sessionId : Text;
        issuedAt : Int;
        expiresAt : Int;
        hostCanisterId : Text;
        sessionNonce : Text;
    };

    public let defaultIssuer : Text = "collection_d_evorev";
    public let defaultSubjectPrefix : Text = "stitching-session";
    public let tokenCookieName : Text = "stitching_jwt";

    public func empty() : StitchingState {
        {
            sessionId = null;
            issuedAt = null;
            expiresAt = null;
            hostCanisterId = null;
            sessionNonce = null;
        }
    };

    public func itemsToText(items : [SessionItem]) : Text {
        if (items.size() == 0) {
            return "";
        };

        var text = "";
        var first = true;
        for (item in items.vals()) {
            if (first) {
                first := false;
            } else {
                text #= ",";
            };
            text #= encodeSessionItem(item);
        };
        text
    };

    public func itemsFromText(text : Text) : [SessionItem] {
        if (text.size() == 0) {
            return [];
        };

        let parts = Iter.toArray(Text.split(text, #char ','));
        var parsed : [SessionItem] = [];
        for (entry in parts.vals()) {
            switch (decodeSessionItem(entry)) {
                case (?value) {
                    parsed := Array.concat(parsed, [value]);
                };
                case null {};
            };
        };
        parsed
    };

    public func fromIdentity(identityOpt : ?Identity.Identity) : ?StitchingState {
        switch (identityOpt) {
            case null { null };
            case (?identity) {
                switch (identity.kind) {
                    case (#jwt(token)) { parseJWT(token) };
                };
            };
        }
    };

    public func parseJWT(token : JWT.Token) : ?StitchingState {
        let sessionId = parseText(JWT.getPayloadValue(token, "session_id"));
        let issuedAt = parseInt(JWT.getPayloadValue(token, "iat"));
        let expiresAt = parseInt(JWT.getPayloadValue(token, "exp"));
        let hostCanisterId = parseText(JWT.getPayloadValue(token, "host_canister_id"));
        let sessionNonce = parseText(JWT.getPayloadValue(token, "session_nonce"));

        if (sessionId == null and issuedAt == null and expiresAt == null) {
            return null;
        };

        ?{
            sessionId = sessionId;
            issuedAt = issuedAt;
            expiresAt = expiresAt;
            hostCanisterId = hostCanisterId;
            sessionNonce = sessionNonce;
        };
    };

    private func randomHex() : async Text {
        let entropy = await Random.blob();
        let bytes = Blob.toArray(entropy);
        BaseX.toHex(bytes.vals(), { isUpper = false; prefix = #none });
    };

    public func generateSessionId() : async Text {
        await randomHex();
    };

    public func generateSessionNonce() : async Text {
        await randomHex();
    };

    public func buildClaims(input : ClaimInput) : StitchingClaims {
        let issuedAtSeconds = input.now / 1_000_000_000;
        let ttlInt = Int.fromNat(input.ttlSeconds);
        let expiresAtSeconds = issuedAtSeconds + ttlInt;

        {
            issuer = input.issuer;
            subject = input.subject;
            sessionId = input.sessionId;
            issuedAt = issuedAtSeconds;
            expiresAt = expiresAtSeconds;
            hostCanisterId = input.hostCanisterId;
            sessionNonce = input.sessionNonce;
        };
    };

    public func toUnsignedToken(claims : StitchingClaims) : JWT.UnsignedToken {
        let payloadBase : [(Text, Json.Json)] = [
            ("iss", #string(claims.issuer)),
            ("sub", #string(claims.subject)),
            ("session_id", #string(claims.sessionId)),
            ("iat", #number(#int(claims.issuedAt))),
            ("exp", #number(#int(claims.expiresAt))),
            ("host_canister_id", #string(claims.hostCanisterId)),
            ("session_nonce", #string(claims.sessionNonce)),
        ];

        {
            header = [
                ("alg", #string("ES256K")),
                ("typ", #string("JWT")),
            ];
            payload = payloadBase;
        };
    };

    func encodeSessionItem(item : SessionItem) : Text {
        let jsonValue : Json.Json = #object_([
            ("cid", #string(item.canisterId)),
            ("id", #number(#int(Int.fromNat(item.itemId))))
        ]);
        let jsonText = Json.stringify(jsonValue, null);
        let jsonBytes = Blob.toArray(Text.encodeUtf8(jsonText));
        BaseX.toBase64(jsonBytes.vals(), #url({ includePadding = false }));
    };

    func decodeSessionItem(value : Text) : ?SessionItem {
        switch (BaseX.fromBase64(value)) {
            case (#ok(bytes)) {
                switch (Text.decodeUtf8(Blob.fromArray(bytes))) {
                    case (?jsonText) {
                        switch (Json.parse(jsonText)) {
                            case (#ok(#object_(fields))) {
                                var cid : ?Text = null;
                                var itemId : ?Nat = null;

                                for ((key, entry) in fields.vals()) {
                                    if (key == "cid") {
                                        switch (parseText(?entry)) {
                                            case (?text) { cid := ?text; };
                                            case null {};
                                        };
                                    } else if (key == "id") {
                                        switch (parseNat(entry)) {
                                            case (?natVal) { itemId := ?natVal; };
                                            case null {};
                                        };
                                    };
                                };

                                switch (cid, itemId) {
                                    case (?foundCid, ?foundItemId) {
                                        ?{
                                            canisterId = foundCid;
                                            itemId = foundItemId;
                                        };
                                    };
                                    case (?_, null) null;
                                    case (null, _) null;
                                };
                            };
                            case (_) null;
                        };
                    };
                    case null null;
                };
            };
            case (#err(_)) null;
        };
    };

    func parseNat(value : Json.Json) : ?Nat {
        switch (parseInt(?value)) {
            case null { null };
            case (?intVal) {
                if (intVal < 0) { return null };
                ?Nat.fromInt(intVal);
            };
        }
    };

    func parseInt(valueOpt : ?Json.Json) : ?Int {
        switch (valueOpt) {
            case null { null };
            case (?value) {
                switch (value) {
                    case (#number(num)) {
                        switch (num) {
                            case (#int(i)) ?i;
                            case (#float(f)) ?Float.toInt(f);
                        };
                    };
                    case (#string(text)) {
                        Int.fromText(text);
                    };
                    case (_) { null };
                };
            };
        }
    };

    func parseText(valueOpt : ?Json.Json) : ?Text {
        switch (valueOpt) {
            case null { null };
            case (?value) {
                switch (value) {
                    case (#string(text)) ?text;
                    case (_) null;
                };
            };
        }
    };
};
