<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Cargo Motives')</title>
    <style>
        /* Plain CSS, no build step — same reasoning as the Driver Link
           pages (resources/views/driver-link): a public legal page has no
           business depending on Vite/Tailwind being built, and app-store
           reviewers need it to load reliably with zero JS. */
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
            background: #F5F6F8;
            color: #1A1A1A;
            line-height: 1.6;
        }
        .page { max-width: 720px; margin: 0 auto; padding: 32px 20px 64px; }
        .brand { font-size: 14px; font-weight: 700; color: #0B4F6C; letter-spacing: 0.04em; margin-bottom: 24px; }
        h1 { font-size: 26px; margin: 0 0 4px; color: #0B4F6C; }
        .updated { color: #6B7280; font-size: 13px; margin-bottom: 32px; }
        h2 { font-size: 18px; margin: 32px 0 8px; color: #08384D; }
        p, li { font-size: 15px; color: #1F2937; }
        ul { padding-left: 20px; }
        a { color: #0B4F6C; }
        footer { margin-top: 48px; font-size: 13px; color: #6B7280; }
    </style>
</head>
<body>
    <div class="page">
        <div class="brand">CARGO MOTIVES</div>
        @yield('content')
        <footer>&copy; {{ date('Y') }} Cargo Motives. Dar es Salaam, Tanzania.</footer>
    </div>
</body>
</html>
