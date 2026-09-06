<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <title>@yield('title', 'Cargo Motives — Delivery')</title>
    <style>
        /* Deliberately plain CSS, no build step (TRD: "lightweight
           server-rendered mobile web page") — this page has to render
           correctly on a basic phone browser with no bundler, no JS
           framework, and no guarantee of a fast connection. */
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
            background: #F5F6F8;
            color: #1A1A1A;
            font-size: 17px;
            line-height: 1.5;
        }
        .page { max-width: 480px; margin: 0 auto; padding: 20px 16px 48px; }
        .brand { font-size: 14px; font-weight: 600; color: #0F5C4A; letter-spacing: 0.02em; margin-bottom: 16px; }
        .card { background: #fff; border-radius: 14px; padding: 20px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
        h1 { font-size: 20px; margin: 0 0 12px; }
        .status-badge { display: inline-block; background: #EAF3F0; color: #0F5C4A; font-weight: 600; font-size: 13px; padding: 4px 10px; border-radius: 999px; margin-bottom: 12px; }
        .row { margin-bottom: 8px; }
        .label { color: #6B7280; font-size: 13px; }
        .value { font-weight: 500; }
        button, .btn {
            display: block; width: 100%; padding: 14px; margin-top: 8px;
            background: #0F5C4A; color: #fff; border: none; border-radius: 10px;
            font-size: 17px; font-weight: 600; text-align: center; cursor: pointer;
        }
        button.secondary { background: #fff; color: #0F5C4A; border: 2px solid #0F5C4A; }
        input[type="text"], textarea {
            width: 100%; padding: 12px; margin-top: 6px; margin-bottom: 14px;
            border: 1px solid #D1D5DB; border-radius: 8px; font-size: 16px;
        }
        input[type="file"] { width: 100%; margin-top: 6px; margin-bottom: 14px; }
        .errors { background: #FDECEC; color: #B42318; padding: 12px; border-radius: 8px; margin-bottom: 16px; font-size: 14px; }
        .success { background: #EAF3F0; color: #0F5C4A; padding: 12px; border-radius: 8px; margin-bottom: 16px; font-size: 14px; }
        .muted { color: #6B7280; font-size: 14px; }
    </style>
</head>
<body>
    <div class="page">
        <div class="brand">CARGO MOTIVES</div>
        @if (session('success'))
            <div class="success">{{ session('success') }}</div>
        @endif
        @if ($errors->any())
            <div class="errors">
                @foreach ($errors->all() as $error)
                    <div>{{ $error }}</div>
                @endforeach
            </div>
        @endif
        @yield('content')
    </div>
</body>
</html>
