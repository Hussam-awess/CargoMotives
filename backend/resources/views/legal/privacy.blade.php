@extends('legal.layout')

@section('title', 'Privacy Policy — Cargo Motives')

@section('content')
    <h1>Privacy Policy</h1>
    <div class="updated">Last updated: {{ $updatedAt }}</div>

    <p>Cargo Motives ("we", "us") operates a marketplace connecting cargo customers with transporter companies in
        Tanzania, via our mobile app and website. This policy explains what information we collect, why, and how
        it's handled.</p>

    <h2>Information we collect</h2>
    <ul>
        <li><strong>Account information:</strong> phone number, full name, email address (optional), and your
            chosen language.</li>
        <li><strong>Company verification information</strong> (transporter companies only): business name,
            registration number, TIN, business license, physical address, and one representative's full name,
            position, national ID number, ID document, and selfie photo.</li>
        <li><strong>Truck and driver information</strong> (transporter companies only): registration numbers,
            vehicle documents, and driver names and phone numbers.</li>
        <li><strong>Job information:</strong> pickup and drop-off addresses, cargo details, photos you attach, and
            proof-of-delivery photos and recipient details.</li>
        <li><strong>Location data:</strong> if a transporter company connects a GPS provider, we receive that
            truck's live position while it's on an active job, so the job's customer and company can track it.</li>
        <li><strong>Payment records:</strong> mobile money transaction references and amounts for commission and
            Featured-tier payments. We never see or store your mobile money PIN or full account credentials — those
            are handled directly by our licensed mobile money aggregator.</li>
    </ul>

    <h2>How we use this information</h2>
    <ul>
        <li>To operate the marketplace: posting jobs, bidding, assigning trucks and drivers, and tracking
            deliveries.</li>
        <li>To verify a transporter company's identity and legitimacy before it can bid on jobs.</li>
        <li>To calculate and collect commission owed on completed jobs.</li>
        <li>To send OTP codes and delivery-related SMS messages.</li>
        <li>To review and resolve disputes, using proof of delivery and (when available) GPS history as evidence.</li>
        <li>To keep the marketplace safe — detecting duplicate or fraudulent company registrations.</li>
    </ul>

    <h2>Who we share it with</h2>
    <p>We share information with the specific third parties needed to provide the service, and no one else:</p>
    <ul>
        <li>Our mobile money aggregator, to process commission and Featured-tier payments.</li>
        <li>Our GPS tracking provider, only for trucks a company has explicitly connected.</li>
        <li>Our SMS gateway, to deliver OTP codes and Driver Link messages.</li>
        <li>The other party to a job (e.g. a customer and the company assigned to their job can see each other's
            relevant contact and job details) — this is how the marketplace itself works.</li>
    </ul>
    <p>We do not sell your personal information to advertisers or data brokers.</p>

    <h2>Data storage and security</h2>
    <p>Verification documents and proof-of-delivery photos are stored in a private location and are only ever
        accessed through short-lived, signed links — never a permanently public URL. Passwords and verification
        codes are stored in hashed form. All traffic to and from our app is encrypted (HTTPS).</p>

    <h2>Data retention</h2>
    <p>We retain account and transaction records for as long as your account is active and for a reasonable period
        afterward, to meet standard financial record-keeping practices and to resolve any outstanding disputes.</p>

    <h2>Your rights</h2>
    <p>You can request a copy of the personal information we hold about you, or request that we delete it, by
        contacting us at the address below — subject to any information we're required to keep for legal or
        financial record-keeping reasons.</p>

    <h2>Children</h2>
    <p>Cargo Motives is a business-to-business logistics service and is not directed at, or intended for use by,
        children.</p>

    <h2>Changes to this policy</h2>
    <p>If we make material changes to this policy, we'll update the date above and notify users through the app.</p>

    <h2>Contact us</h2>
    <p>Questions about this policy or your data can be sent to
        <a href="mailto:privacy@cargomotives.co.tz">privacy@cargomotives.co.tz</a>.</p>
@endsection
