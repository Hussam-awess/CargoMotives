@extends('legal.layout')

@section('title', 'Terms of Service — Cargo Motives')

@section('content')
    <h1>Terms of Service</h1>
    <div class="updated">Last updated: {{ $updatedAt }}</div>

    <p>These terms govern your use of Cargo Motives, a marketplace connecting cargo customers with transporter
        companies in Tanzania. By creating an account, you agree to these terms.</p>

    <h2>1. The service</h2>
    <p>Cargo Motives lets a Customer post a container job, lets verified Transporter Companies bid on it, and
        supports the job through assignment, delivery, and payment. We facilitate this connection; we are not
        ourselves a transporter, and we do not take physical possession of any cargo.</p>

    <h2>2. Accounts and verification</h2>
    <p>You must provide accurate information when creating an account. A Transporter Company must complete our
        verification process — including business registration details and a verified representative — before it
        may bid on jobs. We may flag, reject, or request more information about a submission that appears
        duplicated or inaccurate.</p>

    <h2>3. Bidding and job posting limits</h2>
    <p>To keep the marketplace fair and responsive, Customers and Companies are subject to daily posting and
        bidding limits, which may be higher for a Featured account. We may adjust these limits from time to time.</p>

    <h2>4. Payment</h2>
    <p>Cargo Motives does not collect, hold, or take any share of the payment for a job — the Customer and the
        Transporter Company settle payment between themselves, directly, outside the app. Cargo Motives Plus is a
        separate, optional subscription (for either a Customer or a Transporter Company) purchased directly from
        us for a fixed period via mobile money.</p>

    <h2>5. Conduct</h2>
    <p>You agree not to: submit false or fraudulent verification information; use the platform for any cargo
        prohibited by Tanzanian law; attempt to circumvent bidding limits or verification; or harass or abuse
        other users.</p>

    <h2>6. Disputes</h2>
    <p>If something goes wrong with a delivery, a Customer can report a problem instead of confirming receipt. We
        review disputes using the proof of delivery submitted by the driver and, when available, the job's GPS
        history, and we'll make a determination and record the outcome. Our review process is not a substitute for
        legal remedies either party may separately be entitled to.</p>

    <h2>7. Limitation of liability</h2>
    <p>Cargo Motives provides the marketplace platform itself; we are not a party to the actual carriage contract
        between a Customer and the Transporter Company they select. To the fullest extent permitted by law, we are
        not liable for loss, damage, or delay of cargo, or for the acts or omissions of any Transporter Company,
        driver, or Customer using the platform.</p>

    <h2>8. Suspension and termination</h2>
    <p>We may suspend or terminate an account that violates these terms, submits fraudulent information, or poses
        a risk to other users of the platform.</p>

    <h2>9. Changes to these terms</h2>
    <p>We may update these terms from time to time. If we make material changes, we'll update the date above and
        notify users through the app.</p>

    <h2>10. Governing law</h2>
    <p>These terms are governed by the laws of the United Republic of Tanzania.</p>

    <h2>Contact us</h2>
    <p>Questions about these terms can be sent to
        <a href="mailto:support@cargomotives.co.tz">support@cargomotives.co.tz</a>.</p>
@endsection
