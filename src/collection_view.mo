import Int "mo:core/Int";
import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Collection "collection";
import Theme "utils/theme";

module {
    public func generateCollectionPage(
        collection: Collection.Collection,
        themeManager: Theme.ThemeManager
    ) : Text {
        let items = collection.getAllItems();
        let collectionName = collection.getCollectionName();
        let primary = themeManager.getPrimary();
        let secondary = themeManager.getSecondary();
        let itemsGrid = generateItemsGrid(items);

        "<!DOCTYPE html>\n"
        # "<html lang=\"en\">\n"
        # "<head>\n"
        # "    <meta charset=\"UTF-8\">\n"
        # "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
        # "    <title>" # collectionName # "</title>\n"
        # "    <style>\n"
        # "        * { margin: 0; padding: 0; box-sizing: border-box; }\n"
        # "        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: white; min-height: 100vh; color: #333; }\n"
        # "        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; border-top: 4px solid " # secondary # "; }\n"
        # "        .header { display: flex; align-items: center; justify-content: center; gap: 1.5rem; margin-bottom: 2rem; }\n"
        # "        .logo { width: 80px; height: auto; }\n"
        # "        h1 { color: " # primary # "; font-size: 3rem; margin: 0; }\n"
        # "        .items-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem; margin-top: 2rem; }\n"
        # "        .item-card { background: white; border-radius: 15px; padding: 1.5rem; box-shadow: 0 10px 30px rgba(0,0,0,0.2); transition: transform 0.3s ease, box-shadow 0.3s ease; text-decoration: none; color: inherit; border-left: 3px solid " # secondary # "; }\n"
        # "        .item-card:hover { transform: translateY(-5px); box-shadow: 0 20px 40px rgba(0,0,0,0.3); }\n"
        # "        .item-image { width: 100%; height: auto; max-height: 300px; object-fit: contain; border-radius: 10px; margin-bottom: 1rem; }\n"
        # "        .item-title { font-size: 1.5rem; font-weight: 600; margin-bottom: 0.5rem; color: #2d3748; }\n"
        # "        .item-rarity { display: inline-block; padding: 0.25rem 0.75rem; border-radius: 20px; font-size: 0.8rem; font-weight: 500; margin-bottom: 0.5rem; }\n"
        # "        .rarity-common { background: #e6fffa; color: #047857; }\n"
        # "        .rarity-rare { background: #dbeafe; color: #1e40af; }\n"
        # "        .rarity-epic { background: #faf5ff; color: #7c3aed; }\n"
        # "        .rarity-légendaire { background: #fef3c7; color: #92400e; }\n"
        # "        .item-description { color: #4a5568; line-height: 1.5; }\n"
        # "        .empty-collection { text-align: center; padding: 4rem; color: #718096; }\n"
        # "    </style>\n"
        # "</head>\n"
        # "<body>\n"
        # "    <div class=\"container\">\n"
        # "        <div class=\"header\">\n"
        # "            <img src=\"/logo.webp\" alt=\"Logo\" class=\"logo\">\n"
        # "            <h1>" # collectionName # "</h1>\n"
        # "        </div>\n"
        # "        <div class=\"items-grid\">\n"
        # "            " # itemsGrid # "\n"
        # "        </div>\n"
        # "    </div>\n"
        # "</body>\n"
        # "</html>"
    };

    public func generateItemPage(
        collection: Collection.Collection,
        id: Nat,
        themeManager: Theme.ThemeManager
    ) : Text {
        switch (collection.getItem(id)) {
            case (?item) {
                let collectionName = collection.getCollectionName();
                generateItemDetailPage(item, collectionName, themeManager)
            };
            case null generateNotFoundPage(id, themeManager);
        }
    };

    public func generateNotFoundPage(
        id: Nat,
        themeManager: Theme.ThemeManager
    ) : Text {
        let primary = themeManager.getPrimary();
        let secondary = themeManager.getSecondary();

        "<!DOCTYPE html>\n"
        # "<html lang=\"en\">\n"
        # "<head>\n"
        # "    <meta charset=\"UTF-8\">\n"
        # "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
        # "    <title>Item Not Found</title>\n"
        # "    <style>\n"
        # "        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: white; min-height: 100vh; display: flex; align-items: center; justify-content: center; color: #333; text-align: center; }\n"
        # "        .error-container { background: white; border-radius: 20px; padding: 3rem; box-shadow: 0 20px 50px rgba(0,0,0,0.2); border: 3px solid " # secondary # "; }\n"
        # "        h1 { font-size: 3rem; margin-bottom: 1rem; color: " # primary # "; }\n"
        # "        p { font-size: 1.2rem; margin-bottom: 2rem; opacity: 0.8; }\n"
        # "        a { color: white; text-decoration: none; background: " # primary # "; padding: 1rem 2rem; border-radius: 10px; transition: all 0.3s ease; }\n"
        # "        a:hover { opacity: 0.9; transform: translateY(-2px); }\n"
        # "    </style>\n"
        # "</head>\n"
        # "<body>\n"
        # "    <div class=\"error-container\">\n"
        # "        <h1>Item Not Found</h1>\n"
        # "        <p>Sorry, Item #" # Nat.toText(id) # " doesn't exist in this collection.</p>\n"
        # "        <a href=\"/collection\">View Collection</a>\n"
        # "    </div>\n"
        # "</body>\n"
        # "</html>"
    };

    private func generateItemDetailPage(
        item: Collection.Item,
        collectionName: Text,
        themeManager: Theme.ThemeManager
    ) : Text {
        let attributesHtml = generateAttributesHtml(item.attributes);
        let stitchingHistoryHtml = generateStitchingHistoryHtml(item.stitching_history);
        let rarityClass = "rarity-" # Text.toLower(item.rarity);
        let primary = themeManager.getPrimary();
        let secondary = themeManager.getSecondary();

        "<!DOCTYPE html>\n"
        # "<html lang=\"en\">\n"
        # "<head>\n"
        # "    <meta charset=\"UTF-8\">\n"
        # "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
        # "    <title>" # item.name # " - " # collectionName # "</title>\n"
        # "    <style>\n"
        # "        * { margin: 0; padding: 0; box-sizing: border-box; }\n"
        # "        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: white; min-height: 100vh; color: #333; padding: 2rem; }\n"
        # "        .container { max-width: 800px; margin: 0 auto; background: white; border-radius: 20px; padding: 2rem; box-shadow: 0 20px 50px rgba(0,0,0,0.2); border-top: 4px solid " # secondary # "; }\n"
        # "        .back-link { display: inline-block; margin-bottom: 2rem; color: " # primary # "; text-decoration: none; font-weight: 500; }\n"
        # "        .back-link:hover { text-decoration: underline; }\n"
        # "        .item-header { text-align: center; margin-bottom: 2rem; }\n"
        # "        .item-title { font-size: 2.5rem; font-weight: 700; color: #2d3748; margin-bottom: 0.5rem; }\n"
        # "        .item-id { color: #718096; font-size: 1.1rem; }\n"
        # "        .item-image { width: 100%; max-width: 400px; height: auto; object-fit: contain; border-radius: 15px; margin: 0 auto 2rem auto; display: block; box-shadow: 0 10px 25px rgba(0,0,0,0.2); }\n"
        # "        .item-rarity { display: inline-block; padding: 0.5rem 1rem; border-radius: 25px; font-size: 1rem; font-weight: 600; margin-bottom: 1.5rem; }\n"
        # "        .rarity-common { background: #e6fffa; color: #047857; }\n"
        # "        .rarity-rare { background: #dbeafe; color: #1e40af; }\n"
        # "        .rarity-epic { background: #faf5ff; color: #7c3aed; }\n"
        # "        .rarity-légendaire { background: #fef3c7; color: #92400e; }\n"
        # "        .item-description { font-size: 1.2rem; line-height: 1.6; color: #4a5568; margin-bottom: 2rem; text-align: center; font-style: italic; }\n"
        # "        .attributes { background: #f7fafc; border-radius: 10px; padding: 1.5rem; margin-bottom: 2rem; }\n"
        # "        .attributes-title { font-size: 1.3rem; font-weight: 600; color: #2d3748; margin-bottom: 1rem; }\n"
        # "        .attribute { display: flex; justify-content: space-between; padding: 0.75rem 0; border-bottom: 1px solid #e2e8f0; }\n"
        # "        .attribute:last-child { border-bottom: none; }\n"
        # "        .attribute-key { font-weight: 500; color: #4a5568; }\n"
        # "        .attribute-value { color: #1a202c; }\n"
        # "        .stats { display: grid; gap: 1rem; margin-bottom: 2rem; }\n"
        # "        .stat-card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 1rem 1.5rem; display: flex; justify-content: space-between; align-items: center; }\n"
        # "        .history { background: #f8fafc; border-radius: 12px; padding: 1.5rem; border: 1px solid #e2e8f0; }\n"
        # "        .history-title { font-size: 1.3rem; font-weight: 600; color: #2d3748; margin-bottom: 1rem; }\n"
        # "        .stitching-record { padding: 1rem; border-radius: 10px; border: 1px solid #e2e8f0; margin-bottom: 1rem; background: white; }\n"
        # "        .stitching-record:last-child { margin-bottom: 0; }\n"
        # "        .stitching-date { font-weight: 600; color: #1f2937; margin-bottom: 0.5rem; }\n"
        # "        .stitching-partners { color: #4b5563; margin-bottom: 0.5rem; }\n"
        # "        .stitching-tokens { color: " # primary # "; font-weight: 600; }\n"
        # "        .empty-history { text-align: center; color: #6b7280; padding: 1rem 0; }\n"
        # "    </style>\n"
        # "</head>\n"
        # "<body>\n"
        # "    <div class=\"container\">\n"
        # "        <a href=\"/collection\" class=\"back-link\">Retour à la collection</a>\n"
        # "        <div class=\"item-header\">\n"
        # "            <h1 class=\"item-title\">" # item.name # "</h1>\n"
        # "            <div class=\"item-id\">Item #" # Nat.toText(item.id) # "</div>\n"
        # "        </div>\n"
        # "        <img src=\"" # item.imageUrl # "\" alt=\"" # item.name # "\" class=\"item-image\">\n"
        # "        <div class=\"item-rarity " # rarityClass # "\">" # item.rarity # "</div>\n"
        # "        <p class=\"item-description\">" # item.description # "</p>\n"
        # "        <div class=\"stats\">\n"
        # "            <div class=\"stat-card\">\n"
        # "                <span>Token balance</span>\n"
        # "                <strong>" # Nat.toText(item.token_balance) # "</strong>\n"
        # "            </div>\n"
        # "            <div class=\"stat-card\">\n"
        # "                <span>Total stitchings</span>\n"
        # "                <strong>" # Nat.toText(item.stitching_history.size()) # "</strong>\n"
        # "            </div>\n"
        # "        </div>\n"
        # "        <div class=\"attributes\">\n"
        # "            <h2 class=\"attributes-title\">Attributes</h2>\n"
        # "            " # attributesHtml # "\n"
        # "        </div>\n"
        # "        <div class=\"history\">\n"
        # "            <h2 class=\"history-title\">Stitching history</h2>\n"
        # "            " # stitchingHistoryHtml # "\n"
        # "        </div>\n"
        # "    </div>\n"
        # "</body>\n"
        # "</html>"
    };

    private func generateStitchingHistoryHtml(history: [Collection.StitchingRecord]) : Text {
        if (history.size() == 0) {
            return "<div class=\"empty-history\">No stitchings recorded yet.</div>";
        };

        var html = "";
        for (record in history.vals()) {
            let timestampMs : Int = record.date / 1_000_000;
            let timestampText = Int.toText(timestampMs);
            let partners = formatPartners(record.partner_items);
            html #= "<div class=\"stitching-record\" data-timestamp=\"" # timestampText # "\">\n"
                # "    <div class=\"stitching-date\">" # record.stitching_id # " · <span class=\"stitching-date-value\">" # timestampText # "</span></div>\n"
                # "    <div class=\"stitching-partners\">" # partners # "</div>\n"
                # "    <div class=\"stitching-tokens\">+" # Nat.toText(record.tokens_earned) # " tokens</div>\n"
                # "</div>";
        };
        html #= "<script>(function(){const nodes=document.querySelectorAll('.stitching-record[data-timestamp] .stitching-date-value');for(const node of nodes){const wrapper=node.closest('.stitching-record');if(!wrapper) continue;const value=Number(wrapper.getAttribute('data-timestamp'));if(!Number.isFinite(value)) continue;node.textContent=new Date(value).toLocaleString();}})();</script>";
        html
    };

    private func formatPartners(partners: [(Text, Nat)]) : Text {
        if (partners.size() == 0) {
            return "Solo stitching";
        };

        var parts = "Stitched with: ";
        var index = 0;
        let total = partners.size();
        while (index < total) {
            let (canisterId, itemId) = partners[index];
            if (index > 0) {
                parts #= ", ";
            };
            parts #= "#" # Nat.toText(itemId);
            if (canisterId != "") {
                parts #= " @" # canisterId;
            };
            index += 1;
        };
        parts
    };

    private func generateAttributesHtml(attributes: [(Text, Text)]) : Text {
        if (attributes.size() == 0) {
            return "<div class=\"attribute\">No attributes</div>";
        };

        var html = "";
        for ((key, value) in attributes.vals()) {
            html #= "<div class=\"attribute\">\n"
                # "    <span class=\"attribute-key\">" # key # "</span>\n"
                # "    <span class=\"attribute-value\">" # value # "</span>\n"
                # "</div>";
        };
        html
    };

    private func generateItemsGrid(items: [Collection.Item]) : Text {
        if (items.size() == 0) {
            return "<div class=\"empty-collection\"><h2>Collection vide pour l'instant!</h2></div>";
        };

        var html = "";
        for (item in items.vals()) {
            let rarityClass = "rarity-" # Text.toLower(item.rarity);
            html #= "<a href=\"/item/" # Nat.toText(item.id) # "\" class=\"item-card\">\n"
                # "    <img src=\"" # item.thumbnailUrl # "\" alt=\"" # item.name # "\" class=\"item-image\">\n"
                # "    <h3 class=\"item-title\">" # item.name # "</h3>\n"
                # "    <span class=\"item-rarity " # rarityClass # "\">" # item.rarity # "</span>\n"
                # "    <p class=\"item-description\">" # item.description # "</p>\n"
                # "</a>";
        };
        html
    };
};
