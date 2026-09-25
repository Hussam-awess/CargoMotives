@extends('legal.layout')

@section('title', 'Privacy Policy — Cargo Motives')

@section('content')
    <h1>Privacy Policy</h1>
    <div class="updated">Last updated: {{ $updatedAt }}</div>

    <p>Cargo Motives ("we", "us") operates a marketplace connecting cargo customers with transporter companies in
        Tanzania, via our mobile app and website. This policy explains what personal information we collect, why,
        who we share it with, how long we keep it, and the choices and rights you have — including under Tanzania's
        Personal Data Protection Act, 2022.</p>

    <h2>Information we collect</h2>
    <ul>
        <li><strong>Account information:</strong> your name, phone number, email address and password (stored only
            in hashed form), plus your language, currency and notification settings. A Customer may also add a
            business name and logo, and anyone may add a profile photo.</li>
        <li><strong>Company verification information</strong> (transporter companies only): business name,
            registration number, TIN, business license and certificates, physical address and map location, and one
            representative's full name, position, national ID number and ID document.</li>
        <li><strong>Truck and driver information</strong> (transporter companies only): truck registration numbers
            and documents, and drivers' names, phone numbers, licence numbers and photos.</li>
        <li><strong>Job information:</strong> pickup and drop-off addresses and map points, cargo details, any
            pickup or drop-off permits you attach, instructions a company sends its driver, and proof of delivery
            (photos and the recipient's details).</li>
        <li><strong>Location data:</strong> if a transporter company connects a GPS provider, we receive the positions
            of its connected trucks, and use them while a truck is on an active job to show the job's customer where
            their cargo is, detect arrival at pickup and drop-off, and keep a route history for that job. We don't
            collect the location of your phone.</li>
        <li><strong>Messages, reviews and support:</strong> messages between the parties to a job, messages with our
            support team, and the ratings and reviews you give and receive.</li>
        <li><strong>Payment records:</strong> the amount, status, date and mobile money provider for each Cargo
            Motives Plus payment. We never see or store your mobile money PIN or full account credentials — those
            are handled directly by our licensed mobile money aggregator. Cargo Motives never collects or holds
            payment for a job itself.</li>
        <li><strong>Device and security information:</strong> a push-notification token for each device you sign in
            on, the device name and last-used time of each signed-in session, when you last used the app, and
            standard technical logs (such as IP address and request times) generated when your device talks to our
            servers. Some preferences — such as saved addresses, dark mode and your default payment method — are
            stored only on your own device and never sent to us.</li>
    </ul>

    <h2>How we use this information</h2>
    <ul>
        <li>To operate the marketplace: posting jobs, bidding, assigning trucks and drivers, tracking deliveries,
            messaging, and ratings.</li>
        <li>To verify a transporter company's identity and legitimacy before it can bid on jobs.</li>
        <li>To send you the notifications you've chosen — in the app, by push, by email for account codes, and by SMS
            for sign-in codes, Driver Links and (only if you turn it on) shipment-update SMS alerts.</li>
        <li>To keep accounts secure: two-factor sign-in codes, showing and ending active sessions, locking out
            repeated failed logins, and detecting duplicate or fraudulent registrations.</li>
        <li>To process Cargo Motives Plus payments and remind you before your Plus ends.</li>
        <li>To review and resolve disputes, using proof of delivery, permits, messages and (when available) GPS
            history as evidence.</li>
        <li>To send promotional messages — only if you have turned on "Promotions" in Settings (Customers) or kept
            "New matching loads" on (Transporter Companies). You can turn these off at any time.</li>
    </ul>
    <p>We process your information because it's needed to provide the service you signed up for, to keep the
        platform safe, to meet our legal obligations, or — for optional things like SMS alerts and promotions —
        because you consented.</p>

    <h2>Who we share it with</h2>
    <p>We share information only with the parties needed to provide the service:</p>
    <ul>
        <li><strong>The other party to a job:</strong> a customer and the company assigned to their job can see each
            other's relevant contact and job details, and the customer sees the truck's live location while the job
            is active. A driver sees only the job they were sent a link for.</li>
        <li><strong>Service providers acting on our behalf,</strong> currently: our mobile money aggregator (Selcom)
            for Plus payments; our SMS gateway (Beem Africa) for codes, Driver Links and SMS alerts; our email
            provider for account codes; Google Firebase Cloud Messaging for push notifications; Mapbox and
            OpenStreetMap-based services for maps, address search and route distances; and the GPS tracking
            provider a company chooses to connect (such as Wialon, Traccar or Tracksolid Pro).</li>
        <li><strong>Authorities,</strong> when we are legally required to, or where necessary to protect someone's
            safety or investigate fraud.</li>
    </ul>
    <p>We do not sell your personal information, and we do not share it with advertisers or data brokers.</p>
    <p>Some of these providers process data on servers outside Tanzania. Where that happens, we rely on providers
        that apply appropriate safeguards to protect it.</p>

    <h2>Data storage and security</h2>
    <p>Verification documents, permits and proof-of-delivery photos are stored in a private location and are only
        ever accessed through short-lived, signed links — never a permanently public URL. Passwords and one-time
        codes are stored only in hashed form, one-time codes expire within minutes and stop working after a few
        wrong attempts, and GPS provider credentials are encrypted. All traffic to and from our app is encrypted
        (HTTPS). Sign-in is protected by rate limits and lockouts, with optional two-factor
        authentication, and personal identifiers are masked in our technical logs. No system is perfectly secure,
        but if we become aware of a breach affecting your information we will notify you and the authorities as the
        law requires.</p>

    <h2>Data retention</h2>
    <ul>
        <li>Account information is kept while your account is active.</li>
        <li>Signed-in sessions are ended automatically after 90 days without use, and one-time codes expire within
            minutes.</li>
        <li>When you delete your account, we immediately erase or anonymize your name, email, phone number,
            password, photos, notification settings and device tokens, sign you out everywhere, and — for a
            transporter company — erase the representative's identity details and documents, drivers' contact
            details and GPS provider credentials.</li>
        <li>Records of past jobs, payments, reviews and disputes are kept in anonymized form after deletion, because
            the other party to a job, financial record-keeping and any outstanding dispute still depend on them. A
            company's business registration details are also kept, to prevent fraudulent re-registration.</li>
        <li>Technical logs are kept only for a short period, for security and troubleshooting.</li>
    </ul>

    <h2>Your choices and rights</h2>
    <ul>
        <li><strong>Access and correction:</strong> you can view and edit your profile in the app, or ask us for a
            copy of the personal information we hold about you.</li>
        <li><strong>Deletion:</strong> you can delete your account yourself at any time from Settings &gt; Delete
            account.</li>
        <li><strong>Consent and notifications:</strong> you can turn SMS alerts, promotions and each notification
            category on or off in Settings. Turning consent off doesn't affect anything we did before.</li>
        <li><strong>Security:</strong> you can turn on two-factor authentication and sign out other devices from
            Settings.</li>
        <li><strong>Objection and complaints:</strong> you can object to how we use your information by contacting
            us, and you have the right to complain to the Personal Data Protection Commission of Tanzania.</li>
    </ul>

    <h2>Children</h2>
    <p>Cargo Motives is a logistics service for adults and businesses. It is not directed at, or intended for use
        by, anyone under 18, and we don't knowingly collect children's information.</p>

    <h2>Changes to this policy</h2>
    <p>If we make material changes to this policy, we'll update the date above and notify users through the app.</p>

    <h2>Contact us</h2>
    <p>Questions about this policy or your data, or requests to exercise your rights, can be sent to
        <a href="mailto:privacy@cargomotives.co.tz">privacy@cargomotives.co.tz</a>.</p>
@endsection
