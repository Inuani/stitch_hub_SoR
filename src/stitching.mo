import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Array "mo:core/Array";
import Collection "collection";
import Theme "utils/theme";

module {

    // Generate error page for stitching issues
    public func generateStitchingErrorPage(
        errorMessage: Text,
        themeManager: Theme.ThemeManager
    ) : Text {
        let primary = themeManager.getPrimary();

        "<!DOCTYPE html>
<html lang=\"fr\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Erreur de Stitching</title>
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
            color: #333;
            padding: 2rem;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            max-width: 500px;
            width: 100%;
        }
        .error-card {
            background: white;
            border-radius: 20px;
            padding: 3rem 2rem;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            border: 2px solid #fee2e2;
            color: #333;
            text-align: center;
        }
        .icon {
            font-size: 4rem;
            margin-bottom: 1rem;
        }
        h1 {
            font-size: 2rem;
            color: #dc2626;
            margin-bottom: 1rem;
        }
        .error-message {
            background: #fee2e2;
            color: #991b1b;
            padding: 1.5rem;
            border-radius: 10px;
            border-left: 4px solid #dc2626;
            margin: 2rem 0;
            text-align: left;
        }
        .btn {
            padding: 1rem 2rem;
            border: none;
            border-radius: 10px;
            font-size: 1rem;
            font-weight: 600;
            cursor: pointer;
            background: " # primary # ";
            color: white;
            text-decoration: none;
            display: inline-block;
            margin-top: 1rem;
            transition: opacity 0.2s;
        }
        .btn:hover {
            opacity: 0.8;
        }
    </style>
</head>
<body>
    <div class=\"container\">
        <div class=\"error-card\">
            <div class=\"icon\">⚠️</div>
            <h1>Erreur de Stitching</h1>

            <div class=\"error-message\">
                " # errorMessage # "
            </div>

            <a href=\"/collection\" class=\"btn\">Retour à la Collection</a>
        </div>
    </div>
</body>
</html>"
    };

    // NEW: Generate waiting page for first scan (session-based)
    public func generateWaitingPage(
        item: Collection.Item,
        itemsInSession: [Nat],
        stitchingStartTime: Text,
        themeManager: Theme.ThemeManager
    ) : Text {
        let primary = themeManager.getPrimary();

        "<!DOCTYPE html>
<html lang=\"fr\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Stitching Démarrée - En Attente</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #ffffff;
            min-height: 100vh;
            color: #333;
            padding: 2rem;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container { max-width: 600px; width: 100%; }
        .card {
            background: white;
            border-radius: 20px;
            padding: 2rem;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            border: 2px solid #f3f4f6;
            color: #333;
            text-align: center;
        }
        .icon { font-size: 4rem; margin-bottom: 1rem; }
        h1 { font-size: 2rem; color: #1f2937; margin-bottom: 1rem; }
        .item-name { font-size: 1.3rem; color: #6b7280; margin-bottom: 2rem; }

        .spinner {
            width: 60px;
            height: 60px;
            margin: 2rem auto;
            border: 4px solid #e5e7eb;
            border-top-color: " # primary # ";
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        .countdown {
            font-size: 2.5rem;
            font-weight: 700;
            color: " # primary # ";
            margin: 1rem 0;
        }
        .countdown-label {
            font-size: 1rem;
            color: #6b7280;
            margin-bottom: 2rem;
        }
        .countdown-small {
            font-size: 1.5rem;
            font-weight: 700;
            color: " # primary # ";
            margin: 1rem 0 0.5rem 0;
        }
        .countdown-label-small {
            font-size: 0.875rem;
            color: #6b7280;
            margin-bottom: 1rem;
        }

        .instructions {
            background: #f9fafb;
            padding: 1.5rem;
            border-radius: 10px;
            margin: 2rem 0;
            text-align: left;
            border: 1px solid #e5e7eb;
        }
        .instructions h3 { color: #1f2937; margin-bottom: 0.5rem; }
        .instructions p { color: #6b7280; line-height: 1.6; }
        .btn {
            display: inline-block;
            padding: 1rem 2rem;
            background: #f3f4f6;
            color: #4b5563;
            border-radius: 10px;
            text-decoration: none;
            font-weight: 600;
            margin-top: 1rem;
            transition: background 0.2s;
            border: 1px solid #e5e7eb;
        }
        .btn:hover { background: #e5e7eb; }
    </style>
    <script>
        const MEETING_DURATION = 60; // 1 minute in seconds
        const storageKey = 'stitching_session_active';

        // Get server timestamp (in nanoseconds) and convert to milliseconds
        const serverStartTimeNanos = " # stitchingStartTime # ";
        const serverStartTimeMs = Math.floor(serverStartTimeNanos / 1000000);

        console.log('[Waiting Page] Server timestamp (ms):', serverStartTimeMs);
        console.log('[Waiting Page] Server time:', new Date(serverStartTimeMs).toISOString());

        // Always use server timestamp as source of truth
        let startTime = serverStartTimeMs;
        localStorage.setItem(storageKey, String(startTime));

        const initialElapsed = Math.floor((Date.now() - startTime) / 1000);
        console.log('[Waiting Page] Timer synchronized with backend - elapsed:', initialElapsed, 'seconds');

        let finalizeTriggered = false;

        function updateCountdown() {
            const countdownEl = document.getElementById('countdown');
            if (!countdownEl) return;

            const elapsed = Math.floor((Date.now() - startTime) / 1000);
            const remainingSeconds = Math.max(0, MEETING_DURATION - elapsed);

            const minutes = Math.floor(remainingSeconds / 60);
            const seconds = remainingSeconds % 60;
            countdownEl.textContent = minutes + ':' + (seconds < 10 ? '0' : '') + seconds;

            if (remainingSeconds === 0 && !finalizeTriggered) {
                console.log('[Waiting Page] Timer expired - auto-finalizing stitching');
                finalizeTriggered = true;
                countdownEl.textContent = 'Finalizing...';
                clearInterval(countdownInterval);
                localStorage.removeItem(storageKey);
                // Wait 500ms to ensure backend timestamp has passed the threshold
                setTimeout(() => {
                    window.location.href = '/stitching/finalize_session';
                }, 500);
            }
        }

        const countdownInterval = setInterval(updateCountdown, 1000);
        updateCountdown();

        // No polling needed - when a second item is scanned, the server will redirect automatically
    </script>
</head>
<body>
    <div class=\"container\">
        <div class=\"card\">
            <div class=\"icon\">✅</div>
            <h1>Stitching Démarrée !</h1>
            <div class=\"item-name\">" # item.name # "</div>

            <div class=\"spinner\"></div>

            <div class=\"countdown\" id=\"countdown\">1:00</div>
            <div class=\"countdown-label\">Temps restant pour rejoindre</div>

            <div class=\"instructions\">
                <h3>📱 En attente d'autres objets...</h3>
                <p>Les autres participants peuvent scanner leurs tags NFC maintenant. Ils rejoindront automatiquement cette session de réunion !</p>
                <p style=\"margin-top: 1rem;\"><strong>Objets dans la session : " # Nat.toText(itemsInSession.size()) # "</strong></p>
                <p style=\"margin-top: 0.5rem; font-size: 0.9rem;\">Au moins 2 objets nécessaires pour finaliser la réunion.</p>
            </div>

            <a href=\"/collection\" class=\"btn\">Annuler</a>
        </div>
    </div>
</body>
</html>"
    };

    // NEW: Generate active session page with multiple items (session-based)
    public func generateActiveSessionPage(
        itemsInSession: [Nat],
        allItems: [Collection.Item],
        stitchingStartTime: Text,
        themeManager: Theme.ThemeManager
    ) : Text {
        let primary = themeManager.getPrimary();

        // Generate list of scanned items
        var itemsHtml = "";
        for (itemId in itemsInSession.vals()) {
            let itemOpt = Array.find<Collection.Item>(allItems, func(i) = i.id == itemId);
            switch (itemOpt) {
                case (?item) {
                    itemsHtml #= "<div class=\"item-entry\">
                        <div class=\"item-icon\" style=\"background: " # primary # "; color: white; display: flex; align-items: center; justify-content: center; font-weight: 700;\">" # Nat.toText(item.id) # "</div>
                        <div class=\"item-info\">
                            <div class=\"item-name\">" # item.name # "</div>
                            <div style=\"color: #6b7280; font-size: 0.9rem;\">Prêt à recevoir 10 jetons</div>
                        </div>
                    </div>";
                };
                case null {};
            };
        };

        "<!DOCTYPE html>
<html lang=\"fr\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Stitching Active</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #ffffff;
            min-height: 100vh;
            color: #333;
            padding: 2rem;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container { max-width: 600px; width: 100%; }
        .card {
            background: white;
            border-radius: 20px;
            padding: 2rem;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            border: 2px solid #f3f4f6;
            color: #333;
            text-align: center;
        }
        .icon { font-size: 4rem; margin-bottom: 1rem; }
        h1 { font-size: 2rem; color: #1f2937; margin-bottom: 1rem; }

        .countdown {
            font-size: 2.5rem;
            font-weight: 700;
            color: " # primary # ";
            margin: 1rem 0;
        }
        .countdown-label {
            font-size: 1rem;
            color: #6b7280;
            margin-bottom: 2rem;
        }

        .items-section {
            background: #f9fafb;
            padding: 1.5rem;
            border-radius: 15px;
            margin: 2rem 0;
            border: 1px solid #e5e7eb;
            text-align: left;
        }
        .items-section h2 { color: #1f2937; margin-bottom: 1rem; font-size: 1.2rem; }
        .item-entry {
            background: white;
            padding: 1rem;
            margin-bottom: 0.75rem;
            border-radius: 10px;
            border-left: 4px solid " # primary # ";
            display: flex;
            align-items: center;
            gap: 1rem;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        .item-entry:last-child { margin-bottom: 0; }
        .item-icon {
            width: 50px;
            height: 50px;
            border-radius: 8px;
            font-size: 1.2rem;
        }
        .item-info { flex: 1; }
        .item-name { font-weight: 600; color: #1f2937; }
        .instructions {
            background: #f9fafb;
            padding: 1.5rem;
            border-radius: 10px;
            margin: 2rem 0;
            text-align: left;
            border: 1px solid #e5e7eb;
        }
        .instructions h3 { color: #1f2937; margin-bottom: 0.5rem; }
        .instructions p { color: #6b7280; line-height: 1.6; }
        .actions {
            display: flex;
            gap: 1rem;
            margin-top: 2rem;
        }
        .btn {
            flex: 1;
            padding: 1rem 2rem;
            border: none;
            border-radius: 10px;
            font-size: 1rem;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            display: block;
            text-align: center;
            transition: opacity 0.2s;
        }
        .btn-primary {
            background: " # primary # ";
            color: white;
        }
        .btn-primary:hover {
            opacity: 0.9;
        }
        .btn-secondary {
            background: #f3f4f6;
            color: #4b5563;
            border: 1px solid #e5e7eb;
        }
        .btn-secondary:hover { background: #e5e7eb; }
    </style>
    <script>
        const MEETING_DURATION = 60;
        const storageKey = 'stitching_session_active';

        // Get server timestamp (in nanoseconds) and convert to milliseconds
        const serverStartTimeNanos = " # stitchingStartTime # ";
        const serverStartTimeMs = Math.floor(serverStartTimeNanos / 1000000);

        console.log('[Active Page] Server timestamp (ms):', serverStartTimeMs);
        console.log('[Active Page] Server time:', new Date(serverStartTimeMs).toISOString());

        // Always use server timestamp as source of truth
        let startTime = serverStartTimeMs;
        localStorage.setItem(storageKey, String(startTime));

        const initialElapsed = Math.floor((Date.now() - startTime) / 1000);
        console.log('[Active Page] Timer synchronized with backend - elapsed:', initialElapsed, 'seconds');

        let finalizeTriggered = false;

        function updateCountdown() {
            const countdownEl = document.getElementById('countdown');
            if (!countdownEl) return;

            const elapsed = Math.floor((Date.now() - startTime) / 1000);
            const remainingSeconds = Math.max(0, MEETING_DURATION - elapsed);

            const minutes = Math.floor(remainingSeconds / 60);
            const seconds = remainingSeconds % 60;
            countdownEl.textContent = minutes + ':' + (seconds < 10 ? '0' : '') + seconds;

            if (remainingSeconds === 0 && !finalizeTriggered) {
                console.log('[Active Page] Timer expired - auto-finalizing stitching');
                finalizeTriggered = true;
                countdownEl.textContent = 'Finalizing...';
                clearInterval(countdownInterval);
                localStorage.removeItem(storageKey);
                // Wait 500ms to ensure backend timestamp has passed the threshold
                setTimeout(() => {
                    window.location.href = '/stitching/finalize_session';
                }, 500);
            }
        }

        const countdownInterval = setInterval(updateCountdown, 1000);
        updateCountdown();
    </script>
</head>
<body>
    <div class=\"container\">
        <div class=\"card\">
            <div class=\"icon\">🎉</div>
            <h1>Stitching Active</h1>

            <div class=\"countdown\" id=\"countdown\">1:00</div>
            <div class=\"countdown-label\">Temps restant pour rejoindre</div>

            <div class=\"items-section\">
                <h2>Participants (" # Nat.toText(itemsInSession.size()) # " objets)</h2>
                " # itemsHtml # "
            </div>

            <div class=\"instructions\">
                <h3>🎉 Prêt à Finaliser !</h3>
                <p>Vous avez assez de participants ! Cliquez sur \"Finaliser la Stitching\" pour distribuer 10 jetons à chaque objet.</p>
                <p style=\"margin-top: 0.5rem;\">Ou scannez plus de tags NFC pour ajouter plus de participants à cette réunion.</p>
            </div>

            <div class=\"actions\">
                <a href=\"/collection\" class=\"btn btn-secondary\">Annuler</a>
                <a href=\"/stitching/finalize_session?manual=true\" class=\"btn btn-primary\">Finaliser la Stitching</a>
            </div>
        </div>
    </div>
</body>
</html>"
    };

    // NEW: Generate success page (session-based, simpler)
    public func generateSessionSuccessPage(
        itemIds: [Nat],
        allItems: [Collection.Item],
        themeManager: Theme.ThemeManager
    ) : Text {
        let primary = themeManager.getPrimary();
        let secondary = themeManager.getSecondary();

        // Generate list of rewarded items
        var itemsHtml = "";
        for (itemId in itemIds.vals()) {
            let itemOpt = Array.find<Collection.Item>(allItems, func(i) = i.id == itemId);
            switch (itemOpt) {
                case (?item) {
                    itemsHtml #= "<div class=\"item-entry\">
                        <div class=\"item-icon\" style=\"background: " # primary # "; color: white; display: flex; align-items: center; justify-content: center; font-weight: 700;\">" # Nat.toText(item.id) # "</div>
                        <div class=\"item-info\">
                            <div class=\"item-name\">" # item.name # "</div>
                            <div class=\"item-tokens\">+10 Jetons</div>
                        </div>
                    </div>";
                };
                case null {};
            };
        };

        "<!DOCTYPE html>
<html lang=\"fr\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Stitching Réussie !</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #ffffff;
            min-height: 100vh;
            color: #333;
            padding: 2rem;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container { max-width: 600px; width: 100%; }
        .card {
            background: white;
            border-radius: 20px;
            padding: 3rem 2rem;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            border: 2px solid #f3f4f6;
            color: #333;
            text-align: center;
        }
        .icon {
            font-size: 5rem;
            margin-bottom: 1rem;
            animation: celebrate 1s ease-in-out;
        }
        @keyframes celebrate {
            0%, 100% { transform: scale(1) rotate(0deg); }
            25% { transform: scale(1.2) rotate(-10deg); }
            50% { transform: scale(1.1) rotate(10deg); }
            75% { transform: scale(1.2) rotate(-10deg); }
        }
        h1 { font-size: 2.5rem; color: #1f2937; margin-bottom: 0.5rem; }
        .subtitle { font-size: 1.2rem; color: #6b7280; margin-bottom: 2rem; }
        .reward-badge {
            display: inline-block;
            padding: 1rem 2rem;
            background: " # primary # ";
            color: white;
            border-radius: 50px;
            font-size: 1.5rem;
            font-weight: 700;
            margin: 1rem 0 2rem 0;
        }
        .items-rewarded {
            background: #f9fafb;
            padding: 1.5rem;
            border-radius: 15px;
            margin: 2rem 0;
            text-align: left;
            border: 1px solid #e5e7eb;
        }
        .items-rewarded h2 { color: #1f2937; margin-bottom: 1rem; font-size: 1.2rem; }
        .item-entry {
            background: white;
            padding: 1rem;
            margin-bottom: 0.75rem;
            border-radius: 10px;
            border-left: 4px solid " # primary # ";
            display: flex;
            align-items: center;
            gap: 1rem;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        .item-entry:last-child { margin-bottom: 0; }
        .item-icon {
            width: 50px;
            height: 50px;
            border-radius: 8px;
        }
        .item-info { flex: 1; }
        .item-name { font-weight: 600; color: #1f2937; margin-bottom: 0.25rem; }
        .item-tokens { color: " # secondary # "; font-weight: 700; }
        .actions {
            display: flex;
            gap: 1rem;
            margin-top: 2rem;
        }
        .btn {
            flex: 1;
            padding: 1rem 2rem;
            border: none;
            border-radius: 10px;
            font-size: 1rem;
            font-weight: 600;
            text-decoration: none;
            display: block;
            text-align: center;
            transition: opacity 0.2s;
        }
        .btn-primary {
            background: " # primary # ";
            color: white;
        }
        .btn-primary:hover {
            opacity: 0.9;
        }
        .btn-secondary {
            background: #f3f4f6;
            color: #4b5563;
            border: 1px solid #e5e7eb;
        }
        .btn-secondary:hover { background: #e5e7eb; }
    </style>
    <script>
        // Clear the stitching session storage on success page
        localStorage.removeItem('stitching_session_active');
    </script>
</head>
<body>
    <div class=\"container\">
        <div class=\"card\">
            <div class=\"icon\">🎉</div>
            <h1>Stitching Terminée !</h1>
            <p class=\"subtitle\">Jetons distribués à tous les participants</p>

            <div class=\"reward-badge\">+10 Jetons Chacun</div>

            <div class=\"items-rewarded\">
                <h2>Participants (" # Nat.toText(itemIds.size()) # " objets)</h2>
                " # itemsHtml # "
            </div>

            <div class=\"actions\">
                <a href=\"/collection\" class=\"btn btn-secondary\">Voir la Collection</a>
                <a href=\"/\" class=\"btn btn-primary\">Accueil</a>
            </div>
        </div>
    </div>
</body>
</html>"
    };
}
