// src/invalid_scan.mo
import Theme "theme";

module {

    public func generateInvalidScanPage(themeManager: Theme.ThemeManager) : Text {
        let primary = themeManager.getPrimary();
        let secondary = themeManager.getSecondary();
        "<!DOCTYPE html>
<html lang=\"fr\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Scan Invalide - Collection Ordre d'Évorev</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #333;
            padding: 2rem;
        }
        .error-container {
            background: white;
            border-radius: 20px;
            padding: 3rem;
            box-shadow: 0 20px 50px rgba(0,0,0,0.2);
            text-align: center;
            max-width: 500px;
            width: 100%;
        }
        .error-icon {
            width: 80px;
            height: 80px;
            margin: 0 auto 2rem;
            background: #fed7d7;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .error-title {
            font-size: 2rem;
            font-weight: 700;
            color: #e53e3e;
            margin-bottom: 1rem;
        }
        .error-message {
            font-size: 1.1rem;
            color: #4a5568;
            margin-bottom: 2rem;
            line-height: 1.6;
        }
        .back-button {
            background: " # primary # ";
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 500;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
            transition: all 0.3s ease;
            margin: 0 10px;
        }
        .back-button:hover {
            opacity: 0.9;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        }
        .secondary-button {
            background: " # primary # ";
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 500;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
            transition: all 0.3s ease;
            margin: 0 10px;
        }
        .secondary-button:hover {
            opacity: 0.9;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        }
    </style>
</head>
<body>
    <div class=\"error-container\" style=\"border: 3px solid " # secondary # ";\">
        <div class=\"error-icon\" style=\"border: 2px solid " # secondary # ";\">
            <svg fill=\"#e53e3e\" width=\"40\" height=\"40\" viewBox=\"0 0 20 20\">
                <path fill-rule=\"evenodd\" d=\"M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z\" clip-rule=\"evenodd\"/>
            </svg>
        </div>
        <h1 class=\"error-title\" style=\"color: " # secondary # ";\">Scan Invalide</h1>
        <p class=\"error-message\">
            Désolé, ce lien n'est pas valide ou a expiré.
            <br><br>
            Veuillez scanner le NFC tag du vêtement pour accéder à ce contenu.
        </p>
        <div>
            <a href=\"/collection\" class=\"back-button\">
                Voir la Collection
            </a>
            <a href=\"/\" class=\"secondary-button\">
                Accueil
            </a>
        </div>
    </div>
</body>
</html>"
    };

}
