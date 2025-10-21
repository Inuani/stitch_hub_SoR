import Router       "mo:liminal/Router";
import RouteContext "mo:liminal/RouteContext";
import Liminal      "mo:liminal";
import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Int "mo:core/Int";
import Time "mo:core/Time";
import Array "mo:core/Array";
import Debug "mo:core/Debug";
import Collection "collection";
import Theme "utils/theme";
import CollectionView "collection_view";
import Stitching "stitching";
import StitchingToken "utils/stitching_token";
import PendingSessions "utils/pending_sessions";
import JwtHelper "utils/jwt_helper";

module StitchingRoutes {
    func getStitchingState(ctx: RouteContext.RouteContext) : ?StitchingToken.StitchingState {
        StitchingToken.fromIdentity(ctx.httpContext.getIdentity());
    };

    func clearJwtCookieHeader() : (Text, Text) {
        (
            "Set-Cookie",
            StitchingToken.tokenCookieName # "=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0"
        );
    };

    func hasExpired(session : PendingSessions.Session, now : Int) : Bool {
        now >= session.expiresAt;
    };

    func sessionItemsToLocalItemIds(
        items : [StitchingToken.SessionItem],
        currentCanisterId : Text
    ) : [Nat] {
        var collected : [Nat] = [];
        for (entry in items.vals()) {
            if (entry.canisterId == "" or entry.canisterId == currentCanisterId) {
                collected := Array.concat(collected, [entry.itemId]);
            };
        };
        collected
    };

    func sessionItemsToAllItemIds(items : [StitchingToken.SessionItem]) : [Nat] {
        Array.map<StitchingToken.SessionItem, Nat>(
            items,
            func(entry) = entry.itemId
        );
    };

    public func getStitchingRoutes(
        collection : Collection.Collection,
        themeManager : Theme.ThemeManager,
        pendingSessions : PendingSessions.PendingSessions,
        currentCanisterId : Text
    ) : [Router.RouteConfig] {
        return [
            Router.getQuery("/stitch/{id}", func(ctx: RouteContext.RouteContext) : Liminal.HttpResponse {
                let idText = ctx.getRouteParam("id");

                let id = switch (Nat.fromText(idText)) {
                    case (?num) num;
                    case null {
                        let html = CollectionView.generateNotFoundPage(0, themeManager);
                        return ctx.buildResponse(#notFound, #html(html));
                    };
                };

                let html = CollectionView.generateItemPage(collection, id, themeManager);
                ctx.buildResponse(#ok, #html(html))
            }),

            Router.getQuery("/stitching/waiting", func(ctx: RouteContext.RouteContext) : Liminal.HttpResponse {
                Debug.print("[ROUTE] /stitching/waiting accessed");
                let now = Time.now();

                let stateOpt = getStitchingState(ctx);
                let state = switch (stateOpt) {
                    case null {
                        let html = "<html><body><h1>No Stitching Session</h1><p>Please scan an NFC tag to start a stitching.</p></body></html>";
                        return ctx.buildResponse(#ok, #html(html));
                    };
                    case (?value) value;
                };

                let sessionId = switch (state.sessionId) {
                    case (?id) id;
                    case null {
                        let html = "<html><body><h1>No Stitching Session</h1><p>Please scan an NFC tag to start a stitching.</p></body></html>";
                        return ctx.buildResponse(#ok, #html(html));
                    };
                };

                let sessionOpt = pendingSessions.get(sessionId, now);
                let session = switch (sessionOpt) {
                    case null {
                        let html = Stitching.generateStitchingErrorPage("La session de stitching a expiré. Veuillez rescanner.", themeManager);
                        return ctx.buildResponse(#ok, #html(html));
                    };
                    case (?value) value;
                };

                if (session.items.size() == 0) {
                    let html = Stitching.generateStitchingErrorPage("Aucune donnée de stitching disponible.", themeManager);
                    return ctx.buildResponse(#ok, #html(html));
                };

                let localItemIds = sessionItemsToLocalItemIds(session.items, currentCanisterId);

                if (hasExpired(session, now) and session.items.size() >= 2) {
                    Debug.print("[Waiting Page] AUTO-FINALIZING MEETING");
                    if (localItemIds.size() > 0) {
                        let timestamp = now;
                        let stitchingId = "stitching_" # Int.toText(timestamp);
                        ignore collection.recordStitching(localItemIds, currentCanisterId, stitchingId, 10, session.items, timestamp);
                    };
                    pendingSessions.remove(sessionId);
                    let itemsText = StitchingToken.itemsToText(session.items);
                    return {
                        statusCode = 303;
                        headers = [
                            ("Location", "/stitching/success?items=" # itemsText),
                            clearJwtCookieHeader(),
                        ];
                        body = null;
                        streamingStrategy = null;
                    };
                };

                if (localItemIds.size() == 0) {
                    let html = Stitching.generateStitchingErrorPage("Aucun objet local dans cette session.", themeManager);
                    return ctx.buildResponse(#ok, #html(html));
                };

                let firstLocalId = localItemIds[0];
                switch (collection.getItem(firstLocalId)) {
                    case null {
                        let html = "<html><body><h1>Error</h1><p>Item not found.</p></body></html>";
                        return ctx.buildResponse(#notFound, #html(html));
                    };
                    case (?item) {
                        let stitchingStartTime = Int.toText(session.startTime);
                        let html = Stitching.generateWaitingPage(item, localItemIds, stitchingStartTime, themeManager);
                        ctx.buildResponse(#ok, #html(html))
                    };
                }
            }),

            Router.getQuery("/stitching/active", func(ctx: RouteContext.RouteContext) : Liminal.HttpResponse {
                Debug.print("[ROUTE] /stitching/active accessed");
                let now = Time.now();

                let stateOpt = getStitchingState(ctx);
                let state = switch (stateOpt) {
                    case null {
                        return {
                            statusCode = 303;
                            headers = [("Location", "/stitching/waiting")];
                            body = null;
                            streamingStrategy = null;
                        };
                    };
                    case (?value) value;
                };

                let sessionId = switch (state.sessionId) {
                    case (?id) id;
                    case null {
                        return {
                            statusCode = 303;
                            headers = [("Location", "/stitching/waiting")];
                            body = null;
                            streamingStrategy = null;
                        };
                    };
                };

                let sessionOpt = pendingSessions.get(sessionId, now);
                let session = switch (sessionOpt) {
                    case null {
                        return {
                            statusCode = 303;
                            headers = [("Location", "/stitching/waiting")];
                            body = null;
                            streamingStrategy = null;
                        };
                    };
                    case (?value) value;
                };

                if (session.items.size() < 2) {
                    return {
                        statusCode = 303;
                        headers = [("Location", "/stitching/waiting")];
                        body = null;
                        streamingStrategy = null;
                    };
                };

                if (hasExpired(session, now)) {
                    Debug.print("[Active Page] AUTO-FINALIZING MEETING");
                    let localItemIds = sessionItemsToLocalItemIds(session.items, currentCanisterId);
                    if (localItemIds.size() > 0) {
                        let timestamp = now;
                        let stitchingId = "stitching_" # Int.toText(timestamp);
                        ignore collection.recordStitching(localItemIds, currentCanisterId, stitchingId, 10, session.items, timestamp);
                    };
                    pendingSessions.remove(sessionId);
                    let itemsText = StitchingToken.itemsToText(session.items);
                    return {
                        statusCode = 303;
                        headers = [
                            ("Location", "/stitching/success?items=" # itemsText),
                            clearJwtCookieHeader(),
                        ];
                        body = null;
                        streamingStrategy = null;
                    };
                };

                let localItemIds = sessionItemsToLocalItemIds(session.items, currentCanisterId);
                if (localItemIds.size() == 0) {
                    let html = Stitching.generateStitchingErrorPage("Aucun objet local dans cette session.", themeManager);
                    return ctx.buildResponse(#ok, #html(html));
                };

                let allItems = collection.getAllItems();
                let stitchingStartTime = Int.toText(session.startTime);
                let html = Stitching.generateActiveSessionPage(localItemIds, allItems, stitchingStartTime, themeManager);
                ctx.buildResponse(#ok, #html(html))
            }),

            Router.getAsyncUpdate("/stitching/finalize_session", func(ctx: RouteContext.RouteContext) : async* Liminal.HttpResponse {
                Debug.print("[FINALIZE] Endpoint called");
                let now = Time.now();
                let isManual = ctx.getQueryParam("manual");

                let stateOpt = getStitchingState(ctx);
                let state = switch (stateOpt) {
                    case null {
                        let html = "<html><body><h1>Error</h1><p>Stitching state not found.</p></body></html>";
                        return ctx.buildResponse(#unauthorized, #html(html));
                    };
                    case (?value) value;
                };

                let sessionId = switch (state.sessionId) {
                    case (?id) id;
                    case null {
                        let html = "<html><body><h1>Error</h1><p>Session not found.</p></body></html>";
                        return ctx.buildResponse(#unauthorized, #html(html));
                    };
                };

                let sessionOpt = pendingSessions.get(sessionId, now);
                let session = switch (sessionOpt) {
                    case null {
                        let html = "<html><body><h1>Error</h1><p>Session expired. Please rescan.</p></body></html>";
                        return ctx.buildResponse(#badRequest, #html(html));
                    };
                    case (?value) value;
                };

                if (session.items.size() < 2) {
                    let html = "<html><body><h1>Error</h1><p>Need at least 2 items to finalize a stitching.</p></body></html>";
                    return ctx.buildResponse(#badRequest, #html(html));
                };

                if (isManual == null) {
                    if (now < session.expiresAt - 1_000_000_000) {
                        let html = "<html><body><h1>Too Soon</h1><p>Please wait for the timer to complete, or use the manual finalize button.</p></body></html>";
                        return ctx.buildResponse(#badRequest, #html(html));
                    };
                };

                let localItemIds = sessionItemsToLocalItemIds(session.items, currentCanisterId);
                if (localItemIds.size() > 0) {
                    let timestamp = now;
                    let stitchingId = "stitching_" # Int.toText(timestamp);
                    ignore collection.recordStitching(localItemIds, currentCanisterId, stitchingId, 10, session.items, timestamp);
                } else {
                    Debug.print("[FINALIZE] No local items to reward");
                };

                pendingSessions.remove(sessionId);

                let redirectUrl = "/stitching/success?items=" # StitchingToken.itemsToText(session.items);
                return {
                    statusCode = 303;
                    headers = [
                        ("Location", redirectUrl),
                        ("Content-Type", "text/html"),
                        clearJwtCookieHeader(),
                    ];
                    body = ?Text.encodeUtf8("<html><body>Stitching finalized! Redirecting...</body></html>");
                    streamingStrategy = null;
                };
            }),

            Router.getAsyncUpdate("/stitching/pending", func(ctx: RouteContext.RouteContext) : async* Liminal.HttpResponse {
                let sessionIdOpt = ctx.getQueryParam("session");
                let ?sessionId = sessionIdOpt else {
                    let html = "<html><body><h1>Session manquante</h1><p>Aucune session en attente. Veuillez rescanner.</p></body></html>";
                    return ctx.buildResponse(#badRequest, #html(html));
                };

                let now = Time.now();
                let sessionOpt = pendingSessions.get(sessionId, now);
                let session = switch (sessionOpt) {
                    case null {
                        let html = "<html><body><h1>Session expirée</h1><p>Veuillez rescanner le tag NFC pour relancer la séance.</p></body></html>";
                        return ctx.buildResponse(#unauthorized, #html(html));
                    };
                    case (?value) value;
                };

                let redirectUrl = if (session.items.size() <= 1) {
                    "/stitching/waiting"
                } else {
                    "/stitching/active"
                };

                let stateOpt = getStitchingState(ctx);
                let needsNewToken = switch (stateOpt) {
                    case (?state) {
                        switch (state.sessionId) {
                            case (?existingId) {
                                if (existingId == sessionId) {
                                    switch (state.expiresAt) {
                                        case (?exp) now >= exp;
                                        case null true;
                                    }
                                } else {
                                    true;
                                }
                            };
                            case null true;
                        }
                    };
                    case null true;
                };

                if (needsNewToken) {
                    let claims = StitchingToken.buildClaims({
                        issuer = StitchingToken.defaultIssuer;
                        subject = StitchingToken.defaultSubjectPrefix # ":" # sessionId;
                        sessionId = sessionId;
                        now = now;
                        ttlSeconds = session.ttlSeconds;
                        hostCanisterId = session.hostCanisterId;
                        sessionNonce = session.sessionNonce;
                    });
                    let unsignedToken = StitchingToken.toUnsignedToken(claims);
                    let jwt = await JwtHelper.mintUnsignedToken(unsignedToken);
                    let cookieValue = StitchingToken.tokenCookieName # "=" # jwt # "; Path=/; HttpOnly; SameSite=Lax; Max-Age=" # Nat.toText(session.ttlSeconds);

                    return {
                        statusCode = 303;
                        headers = [
                            ("Location", redirectUrl),
                            ("Set-Cookie", cookieValue)
                        ];
                        body = null;
                        streamingStrategy = null;
                    };
                } else {
                    return {
                        statusCode = 303;
                        headers = [("Location", redirectUrl)];
                        body = null;
                        streamingStrategy = null;
                    };
                }
            }),

            Router.getQuery("/stitching/success", func(ctx: RouteContext.RouteContext) : Liminal.HttpResponse {
                let itemsTextOpt = ctx.getQueryParam("items");

                let itemsText = switch (itemsTextOpt) {
                    case (?items) items;
                    case null "";
                };

                let sessionItems = StitchingToken.itemsFromText(itemsText);

                if (sessionItems.size() == 0) {
                    let html = "<html><body><h1>No Stitching Data</h1><p>We couldn't find stitching information. Please rescan the NFC tags.</p></body></html>";
                    return {
                        statusCode = 200;
                        headers = [
                            ("Content-Type", "text/html"),
                            clearJwtCookieHeader(),
                        ];
                        body = ?Text.encodeUtf8(html);
                        streamingStrategy = null;
                    };
                };

                let itemIds = sessionItemsToAllItemIds(sessionItems);

                let allItems = collection.getAllItems();
                let html = Stitching.generateSessionSuccessPage(itemIds, allItems, themeManager);
                {
                    statusCode = 200;
                    headers = [
                        ("Content-Type", "text/html"),
                        clearJwtCookieHeader(),
                    ];
                    body = ?Text.encodeUtf8(html);
                    streamingStrategy = null;
                }
            }),

            Router.getQuery("/stitching/error", func(ctx: RouteContext.RouteContext) : Liminal.HttpResponse {
                let now = Time.now();
                let stateOpt = StitchingToken.fromIdentity(ctx.httpContext.getIdentity());

                let errorMsg = switch (stateOpt) {
                    case (?state) {
                        switch (state.sessionId) {
                            case (?sessionId) {
                                switch (pendingSessions.get(sessionId, now)) {
                                    case (?session) {
                                        let count = session.items.size();
                                        if (count >= 2) {
                                            "We had trouble finalizing the stitching. Please try again."
                                        } else if (count == 1) {
                                            "One participant was detected, but we need at least two items."
                                        } else {
                                            "No stitching data found. Please scan an NFC tag to start."
                                        }
                                    };
                                    case null {
                                        "La session de stitching a expiré. Veuillez rescanner."
                                    };
                                }
                            };
                            case null "No stitching data found. Please scan an NFC tag to start.";
                        }
                    };
                    case null "No stitching data found. Please scan an NFC tag to start.";
                };

                let html = Stitching.generateStitchingErrorPage(errorMsg, themeManager);
                return {
                    statusCode = 200;
                    headers = [
                        ("Content-Type", "text/html"),
                        clearJwtCookieHeader(),
                    ];
                    body = ?Text.encodeUtf8(html);
                    streamingStrategy = null;
                };
            })
        ];
    };
}
