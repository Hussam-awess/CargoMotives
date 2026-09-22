@props(['size' => 40, 'background' => true])
{{--
    The real Cargo Motives mark (Identity Sheet v4): a bone "C" holding an
    orange zigzag "M" (a stroked diagonal path, not a filled block) in its
    opening. Same path coordinates and hex colors as
    mobile/assets/brand/logo_mark_reversed.svg and mobile/assets/icon/icon.png
    — this is a server-rendered (Blade, no build step) reproduction of that
    exact mark for the web-facing surfaces (admin, legal pages, Driver Link
    pages), not a reinterpretation. `background=false` omits the navy
    rounded-square backing for use on a surface that's already dark (e.g.
    the admin sidebar).
--}}
<svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 256 256"
    width="{{ $size }}"
    height="{{ $size }}"
    role="img"
    aria-label="Cargo Motives"
    {{ $attributes }}
>
    @if ($background)
        <rect width="256" height="256" rx="56" fill="#16294B"/>
    @endif
    <g transform="translate(1 4)">
        <path d="M 184.3 69.8 A 88 88 0 1 0 184.3 178.2 L 159.9 159.1 A 57 57 0 1 1 159.9 88.9 Z" fill="#F4EFE6"/>
        <path d="M 98 172 L 150 95 L 183 158 L 218 58 L 218 172" fill="none" stroke="#E2621B" stroke-width="26" stroke-linejoin="round" stroke-linecap="square"/>
    </g>
</svg>
