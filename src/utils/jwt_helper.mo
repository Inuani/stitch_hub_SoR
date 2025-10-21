import Text "mo:core/Text";

import Time "mo:core/Time";
import Debug "mo:core/Debug";
import Blob "mo:core/Blob";
import Array "mo:core/Array";
import Nat "mo:core/Nat";
import Nat8 "mo:core/Nat8";
import Result "mo:core/Result";
import NatBase "mo:base/Nat";
import JWT "mo:jwt@2";
import Json "mo:json@1";
import BaseX "mo:base-x-encoder";
import ECDSA "mo:ecdsa";
import Sha256 "mo:sha2@0/Sha256";
import IC "mo:ic";
import ICall "mo:ic/Call";
import Nat64 "mo:core/Nat64";

module {
    public let defaultPublicKeyHex : Text = "0367e89337187bad2aed4c207194da86e3d52062da4cb6bffcc0e93c369e2bd338";
    public type MintResult = {
        token : Text;
        publicKeyHex : Text;
        payload : Text;
        header : Text;
        isValid : Bool;
    };

    let keyId : { name : Text; curve : IC.EcdsaCurve } = {
        curve = #secp256k1;
        name = "test_key_1";
    };

    public func mintUnsignedToken(unsigned : JWT.UnsignedToken) : async Text {
        let signingInput = JWT.toTextUnsigned(unsigned);
        let signingInputBytes = Blob.toArray(Text.encodeUtf8(signingInput));
        let hashBlob = Sha256.fromArray(#sha256, signingInputBytes);

        let signResponse = await ICall.signWithEcdsa({
            message_hash = hashBlob;
            derivation_path = [];
            key_id = keyId;
        });

        let signatureDer = Blob.toArray(signResponse.signature);
        Debug.print("ECDSA signature blob length: " # Nat.toText(signatureDer.size()));
        Debug.print("ECDSA DER signature (hex): " # bytesToHex(signatureDer));
        let signatureRaw = derToRaw(signatureDer);
        Debug.print("ECDSA RAW signature (hex): " # bytesToHex(signatureRaw));
        let signatureEncoded = base64UrlEncode(signatureRaw);

        signingInput # "." # signatureEncoded;
    };

    public func mintTestToken() : async MintResult {
        let now = Time.now();
        let iatSeconds = now / 1_000_000_000;
        let expSeconds = iatSeconds + 300;

        let unsigned : JWT.UnsignedToken = {
            header = [
                ("alg", #string("ES256K")),
                ("typ", #string("JWT")),
            ];
            payload = [
                ("iss", #string("bleu_travail_core")),
                ("sub", #string("stitching-test")),
                ("iat", #number(#int(iatSeconds))),
                ("exp", #number(#int(expSeconds))),
            ];
        };

        let token = await mintUnsignedToken(unsigned);

        let publicKeyRequest = {
            canister_id = null;
            derivation_path = [];
            key_id = keyId;
        };

        let methodNameSize = Nat64.fromNat("ecdsa_public_key".size());
        let payloadSize = Nat64.fromNat(Blob.size(to_candid (publicKeyRequest)));
        let cycles = ICall.Cost.call(methodNameSize, payloadSize);

        let pkResponse = await (with cycles) IC.ic.ecdsa_public_key(publicKeyRequest);

        let publicKeyHex = bytesToHex(Blob.toArray(pkResponse.public_key));

        let isValid = switch (JWT.parse(token)) {
            case (#ok(_)) true;
            case (#err(err)) {
                Debug.print("JWT parse failed: " # err);
                false;
            };
        };

        let headerJson = Json.stringify(#object_(unsigned.header), null);
        let payloadJson = Json.stringify(#object_(unsigned.payload), null);

        {
            token = token;
            publicKeyHex = publicKeyHex;
            payload = payloadJson;
            header = headerJson;
            isValid = isValid;
        };
    };

    func base64UrlEncode(bytes : [Nat8]) : Text {
        BaseX.toBase64(bytes.vals(), #url({ includePadding = false }));
    };

    func derToRaw(bytes : [Nat8]) : [Nat8] {
        if (bytes.size() == 64) {
            return bytes;
        };
        let zeroSig = Array.repeat<Nat8>(0, 64);
        if (bytes.size() < 2 or bytes[0] != 0x30) {
            Debug.print("Failed to convert DER signature: missing SEQUENCE header");
            return zeroSig;
        };

        func readLength(start : Nat) : ?{ len : Nat; next : Nat } {
            if (start >= bytes.size()) { return null };
            let first = bytes[start];
            if ((first & 0x80) == 0) {
                return ?{ len = Nat8.toNat(first); next = start + 1 };
            };
            let numBytes = Nat8.toNat(first & 0x7f);
            if (numBytes == 0 or start + 1 + numBytes > bytes.size()) { return null };
            var idx = start + 1;
            var len : Nat = 0;
            var i : Nat = 0;
            while (i < numBytes) {
                len := (len * 256) + Nat8.toNat(bytes[idx]);
                idx += 1;
                i += 1;
            };
            ?{ len = len; next = idx };
        };

        var index : Nat = 1;
        let ?seq = readLength(index) else {
            Debug.print("Failed to convert DER signature: invalid sequence length");
            return zeroSig;
        };
        index := seq.next;
        if (index + seq.len > bytes.size()) {
            Debug.print("Failed to convert DER signature: sequence length exceeds buffer");
            return zeroSig;
        };

        func readInteger() : ?[Nat8] {
            if (index >= bytes.size() or bytes[index] != 0x02) {
                return null;
            };
            index += 1;
            let ?lenInfo = readLength(index) else { return null };
            index := lenInfo.next;
            if (index + lenInfo.len > bytes.size()) { return null };
            let slice = Array.tabulate<Nat8>(lenInfo.len, func(i) = bytes[index + i]);
            index += lenInfo.len;
            // Strip leading zeros
            var firstNonZero : Nat = 0;
            while (firstNonZero < slice.size() and slice[firstNonZero] == 0) {
                firstNonZero += 1;
            };
            if (firstNonZero == slice.size()) {
                return ?Array.repeat<Nat8>(1, 0);
            };
            ?Array.tabulate<Nat8>(slice.size() - firstNonZero, func(i) = slice[firstNonZero + i]);
        };

        func padTo32(value : [Nat8]) : [Nat8] {
            if (value.size() >= 32) {
                if (value.size() == 32) { return value };
                return Array.tabulate<Nat8>(32, func(i) = value[value.size() - 32 + i]);
            };
            let padding = NatBase.sub(32, value.size());
            Array.tabulate<Nat8>(
                32,
                func(i) = if (i < padding) 0 else value[i - padding],
            );
        };

        switch (readInteger(), readInteger()) {
            case (?rBytes, ?sBytes) {
                let r = padTo32(rBytes);
                let s = padTo32(sBytes);
                Array.tabulate<Nat8>(64, func(i) = if (i < 32) r[i] else s[i - 32]);
            };
            case (_) {
                Debug.print("Failed to convert DER signature: could not read INTEGER values");
                zeroSig;
            };
        }
    };

    func bytesToHex(bytes : [Nat8]) : Text {
        BaseX.toHex(bytes.vals(), {
            isUpper = false;
            prefix = #none;
        });
    };

    public func decodeSecp256k1PublicKey(hex : Text) : Result.Result<ECDSA.PublicKey, Text> {
        switch (BaseX.fromHex(hex, { prefix = #none })) {
            case (#ok(bytes)) {
                ECDSA.publicKeyFromBytes(bytes.vals(), #raw({ curve = ECDSA.secp256k1Curve() }));
            };
            case (#err(err)) #err(err);
        };
    };

    public func defaultVerificationKey() : Result.Result<JWT.SignatureVerificationKey, Text> {
        switch (decodeSecp256k1PublicKey(defaultPublicKeyHex)) {
            case (#ok(pk)) #ok(#ecdsa(pk));
            case (#err(err)) #err(err);
        };
    };
};
