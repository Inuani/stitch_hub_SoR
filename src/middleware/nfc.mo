import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Int "mo:core/Int";
import Time "mo:core/Time";
import Array "mo:core/Array";
import App "mo:liminal/App";
import HttpContext "mo:liminal/HttpContext";
import Url "mo:url-kit@3";
import ProtectedRoutes "../nfc_protec_routes";
import Scan "../utils/scan";
import InvalidScan "../utils/invalid_scan";
import Theme "../utils/theme";
import StitchingToken "../utils/stitching_token";
import PendingSessions "../utils/pending_sessions";

module NFCMiddleware {

    let sessionTtlSeconds : Nat = 300;
    let meetingWindowSeconds : Nat = 60;

    // ========================================
    // NFC Utility Functions
    // ========================================

    public func parseUrl(url : Text) : ?Url.Url {
        switch (Url.fromText(url)) {
            case (#ok(parsed)) ?parsed;
            case (#err(_)) null;
        }
    };

    public func extractNFCParams(url: Text) : {uid: Text; cmac: Text; ctr: Text} {
        var uid = "";
        var cmac = "";
        var ctr = "";

        switch (parseUrl(url)) {
            case (?parsed) {
                for ((key, value) in parsed.queryParams.vals()) {
                    switch (key) {
                        case "uid" { uid := value; };
                        case "cmac" { cmac := value; };
                        case "ctr" { ctr := value; };
                        case _ {};
                    };
                };
            };
            case null {};
        };

        { uid = uid; cmac = cmac; ctr = ctr }
    };

    public func extractItemIdFromUrl(url: Text) : ?Nat {
        switch (parseUrl(url)) {
            case (?parsed) {
                let segments = parsed.path;
                var i = 0;
                while (i < segments.size()) {
                    if (segments[i] == "stitch") {
                        if (i + 1 < segments.size()) {
                            switch (Nat.fromText(segments[i + 1])) {
                                case (?id) { return ?id; };
                                case null { return null; };
                            };
                        };
                    };
                    i += 1;
                };
                null;
            };
            case null null;
        }
    };

    // Generate HTML response for NFC scan result
    public func generateScanRedirectPage(
        redirectUrl: Text,
        message: Text,
        isError: Bool
    ) : Text {
        let accentColor = if (isError) { "#ef4444" } else { "#10b981" };
        let icon = if (isError) { "⚠️" } else { "✅" };

        "<!DOCTYPE html>
<html lang=\"fr\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Scan NFC</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #ffffff;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #1f2937;
            text-align: center;
            padding: 2rem;
        }
        .container {
            max-width: 400px;
            width: 100%;
        }
        .message {
            font-size: 5rem;
            margin-bottom: 2rem;
            animation: fadeIn 0.5s ease-in;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: scale(0.8); }
            to { opacity: 1; transform: scale(1); }
        }
        h1 {
            font-size: 1.5rem;
            margin-bottom: 3rem;
            font-weight: 600;
            color: #374151;
        }
        .spinner {
            width: 60px;
            height: 60px;
            margin: 0 auto 2rem;
            border: 5px solid #f3f4f6;
            border-top-color: " # accentColor # ";
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        .status {
            font-size: 0.875rem;
            color: #9ca3af;
            font-weight: 500;
        }
    </style>
    <script>
        setTimeout(function() {
            window.location.href = '" # redirectUrl # "';
        }, 1500);
    </script>
</head>
<body>
    <div class=\"container\">
        <div class=\"message\">" # icon # "</div>
        <h1>" # message # "</h1>
        <div class=\"spinner\"></div>
        <p class=\"status\">•••</p>
    </div>
</body>
</html>"
    };

    // ========================================
    // NFC Protection Middleware
    // ========================================

    public func createNFCProtectionMiddleware(
        protected_routes_storage: ProtectedRoutes.RoutesStorage,
        pendingSessions: PendingSessions.PendingSessions,
        themeManager: Theme.ThemeManager,
        canisterId: Text
    ) : App.Middleware {
        {
            name = "NFC Protection with Session-Based Stitchings";
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                if (protected_routes_storage.isProtectedRoute(context.request.url)) {
                    return #upgrade; // Force verification in update call
                };
                next();
            };
            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                let url = context.request.url;

                if (not protected_routes_storage.isProtectedRoute(url)) {
                    return await* next();
                };

                switch (parseUrl(url)) {
                    case (?_) {};
                    case null {
                        return {
                            statusCode = 400;
                            headers = [("Content-Type", "text/html")];
                            body = ?Text.encodeUtf8(InvalidScan.generateInvalidScanPage(themeManager));
                            streamingStrategy = null;
                        };
                    };
                };

                let routes_array = protected_routes_storage.listProtectedRoutes();
                let countdownNanos = Int.fromNat(meetingWindowSeconds) * 1_000_000_000;

                label routeLoop for ((path, protection) in routes_array.vals()) {
                    if (not Text.contains(url, #text path)) {
                        continue routeLoop;
                    };

                    let itemIdOpt = extractItemIdFromUrl(url);

                    switch (itemIdOpt) {
                        case (?itemId) {
                            let routeCmacs = protection.cmacs_;
                            let scanCount = protection.scan_count_;
                            let counter = Scan.scan(routeCmacs, url, scanCount);
                            if (counter == 0) {
                                return {
                                    statusCode = 403;
                                    headers = [("Content-Type", "text/html")];
                                    body = ?Text.encodeUtf8(InvalidScan.generateInvalidScanPage(themeManager));
                                    streamingStrategy = null;
                                };
                            };

                            ignore protected_routes_storage.verifyRouteAccess(path, url);

                            let sessionItem : StitchingToken.SessionItem = {
                                canisterId = canisterId;
                                itemId = itemId;
                            };

                            let identityStateOpt = StitchingToken.fromIdentity(context.getIdentity());
                            let sessionIdFromToken = switch (identityStateOpt) {
                                case (?state) state.sessionId;
                                case null null;
                            };

                            let now = Time.now();

                            switch (sessionIdFromToken) {
                                case (?existingSessionId) {
                                    switch (pendingSessions.get(existingSessionId, now)) {
                                        case null {
                                            let newSessionId = await StitchingToken.generateSessionId();
                                            let newSessionNonce = await StitchingToken.generateSessionNonce();
                                            pendingSessions.put(newSessionId, {
                                                items = [sessionItem];
                                                startTime = now;
                                                expiresAt = now + countdownNanos;
                                                ttlSeconds = sessionTtlSeconds;
                                                createdAt = now;
                                                hostCanisterId = canisterId;
                                                sessionNonce = newSessionNonce;
                                            });
                                            let html = generateScanRedirectPage(
                                                "/stitching/pending?session=" # newSessionId,
                                                "Scan réussi ! Redirection…",
                                                false
                                            );
                                            return {
                                                statusCode = 200;
                                                headers = [("Content-Type", "text/html")];
                                                body = ?Text.encodeUtf8(html);
                                                streamingStrategy = null;
                                            };
                                        };
                                        case (?session) {
                                            let alreadyScanned = Array.find<StitchingToken.SessionItem>(
                                                session.items,
                                                func(entry) = entry.canisterId == sessionItem.canisterId and entry.itemId == sessionItem.itemId
                                            );

                                            let updatedItems = switch (alreadyScanned) {
                                                case (?_) session.items;
                                                case null Array.concat(session.items, [sessionItem]);
                                            };

                                            let updatedSession : PendingSessions.Session = {
                                                items = updatedItems;
                                                startTime = now;
                                                expiresAt = now + countdownNanos;
                                                ttlSeconds = session.ttlSeconds;
                                                createdAt = session.createdAt;
                                                hostCanisterId = session.hostCanisterId;
                                                sessionNonce = session.sessionNonce;
                                            };
                                            pendingSessions.put(existingSessionId, updatedSession);

                                            let redirectUrl = if (updatedItems.size() >= 2) {
                                                "/stitching/active"
                                            } else {
                                                "/stitching/waiting"
                                            };
                                            let isDuplicate = switch (alreadyScanned) { case (?_) true; case null false; };
                                            let message = if (isDuplicate) {
                                                "Cet objet a déjà rejoint la session."
                                            } else {
                                                "Scan réussi ! Redirection…"
                                            };
                                            let html = generateScanRedirectPage(redirectUrl, message, isDuplicate);
                                            return {
                                                statusCode = 200;
                                                headers = [("Content-Type", "text/html")];
                                                body = ?Text.encodeUtf8(html);
                                                streamingStrategy = null;
                                            };
                                        };
                                    };
                                };
                                case null {
                                    let newSessionId = await StitchingToken.generateSessionId();
                                    let newSessionNonce = await StitchingToken.generateSessionNonce();
                                    pendingSessions.put(newSessionId, {
                                        items = [sessionItem];
                                        startTime = now;
                                        expiresAt = now + countdownNanos;
                                        ttlSeconds = sessionTtlSeconds;
                                        createdAt = now;
                                        hostCanisterId = canisterId;
                                        sessionNonce = newSessionNonce;
                                    });
                                    let html = generateScanRedirectPage(
                                        "/stitching/pending?session=" # newSessionId,
                                        "Scan réussi ! Redirection…",
                                        false
                                    );
                                    return {
                                        statusCode = 200;
                                        headers = [("Content-Type", "text/html")];
                                        body = ?Text.encodeUtf8(html);
                                        streamingStrategy = null;
                                    };
                                };
                            };
                        };
                        case null {
                            if (not protected_routes_storage.verifyRouteAccess(path, url))
                            {
                                return {
                                    statusCode = 403;
                                    headers = [("Content-Type", "text/html")];
                                    body = ?Text.encodeUtf8(InvalidScan.generateInvalidScanPage(themeManager));
                                    streamingStrategy = null;
                                };
                            };
                            return await* next();
                        };
                    };
                };

                await* next();
            };
        };
    };
}
