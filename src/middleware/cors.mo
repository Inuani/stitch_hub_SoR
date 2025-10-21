import CORS "mo:liminal/CORS";
import App "mo:liminal/App";
import HttpContext "mo:liminal/HttpContext";
import Array "mo:core/Array";

module {
    // Configure CORS options
    public let corsOptions : CORS.Options = {
        allowOrigins = []; // Empty = allow all origins (permissive for development)
        allowMethods = [#get, #post, #put, #delete, #options];
        allowHeaders = ["Content-Type", "Authorization"];
        maxAge = ?86400; // 24 hours
        allowCredentials = true; // Important for session cookies!
        exposeHeaders = [];
    };

    public func createCORSMiddleware() : App.Middleware {
        {
            name = "CORS";
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                // Handle CORS preflight and regular requests
                switch (CORS.handlePreflight(context, corsOptions)) {
                    case (#complete(response)) {
                        return #response(response);
                    };
                    case (#next({ corsHeaders = _ })) {
                        // Continue to next middleware
                        next();
                    };
                };
            };
            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                // Handle CORS for update calls
                switch (CORS.handlePreflight(context, corsOptions)) {
                    case (#complete(response)) {
                        return response;
                    };
                    case (#next({ corsHeaders })) {
                        // Continue to next middleware
                        let response = await* next();
                        // Add CORS headers to response
                        let updatedHeaders = Array.concat(response.headers, corsHeaders);
                        return {
                            statusCode = response.statusCode;
                            headers = updatedHeaders;
                            body = response.body;
                            streamingStrategy = response.streamingStrategy;
                        };
                    };
                };
            };
        };
    };
}
