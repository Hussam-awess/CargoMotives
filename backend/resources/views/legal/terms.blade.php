@extends('legal.layout')

@section('title', 'Terms of Service — Cargo Motives')

@section('content')
    <h1>Terms of Service</h1>
    <div class="updated">Last updated: {{ $updatedAt }}</div>

    <p>These terms govern your use of Cargo Motives, a marketplace connecting cargo customers with transporter
        companies in Tanzania, through our mobile app and website. By creating an account or using the service, you
        agree to these terms and to our <a href="{{ route('legal.privacy') }}">Privacy Policy</a>.</p>

    <h2>1. The service</h2>
    <p>Cargo Motives lets a Customer post a container job, lets verified Transporter Companies bid on it, and
        supports the job through assignment, tracking, delivery and review. We provide the platform that connects
        the two parties; we are not ourselves a transporter, freight forwarder or customs agent, and we never take
        physical possession of any cargo. Drivers do not need an account: a Transporter Company's driver receives a
        private, time-limited link by SMS to update a job's progress and record proof of delivery.</p>

    <h2>2. Accounts and security</h2>
    <p>You must be at least 18 and using Cargo Motives for a genuine business or personal shipping need. You must
        give accurate information when creating an account and keep it up to date. You are responsible for all
        activity under your account and for keeping your password confidential. We strongly recommend turning on
        two-factor authentication in Settings, which asks for a one-time code each time you log in. You can review
        the devices signed in to your account and sign any of them out from Settings &gt; Active sessions; sessions
        that go unused for a long period are signed out automatically. Tell us promptly at the address below if you
        believe your account has been accessed without your permission.</p>

    <h2>3. Transporter Company verification</h2>
    <p>A Transporter Company must complete our verification process — including business registration details,
        supporting documents and a representative's identity — before it may bid on jobs, and each truck must be
        approved before it can be assigned. We may flag, reject, or request more information about a submission
        that appears duplicated, incomplete or inaccurate. Verification means we have reviewed the information
        submitted; it is not a guarantee of any company's performance.</p>

    <h2>4. Posting jobs and bidding</h2>
    <ul>
        <li><strong>Limits.</strong> To keep the marketplace fair and responsive, a standard account is subject to a
            daily limit on job postings or bids. A Cargo Motives Plus account has no such limit. We may adjust the
            standard limit from time to time.</li>
        <li><strong>Bidding deadlines.</strong> A Customer chooses when bidding on their job closes. Bids are sealed:
            a Transporter Company never sees another company's price.</li>
        <li><strong>Changing a job.</strong> If a Customer changes an open job's pickup or drop-off location, any
            pending bids on it are automatically withdrawn, because they were priced for the old route, and the
            affected companies are notified.</li>
        <li><strong>Company filters.</strong> A Transporter Company may set a minimum rate ("floor rate") in
            Settings; jobs in the same currency with a budget below it are then hidden from its Open Jobs feed. A
            company may also pause new-job alerts by turning off "Accepting loads".</li>
        <li><strong>Accepting a bid.</strong> When a Customer accepts a bid, the carriage arrangement is between the
            Customer and that Transporter Company directly. Cargo Motives is not a party to it.</li>
    </ul>

    <h2>5. Permits and cargo documents</h2>
    <p>Where a port, border or other cargo authority requires a pickup or drop-off permit, the Customer is
        responsible for obtaining it and attaching it to the job in the app. A job cannot be completed until its
        drop-off permit is attached. We do not verify whether a permit is genuine, valid or sufficient, and each
        party remains responsible for complying with customs, port and transport laws that apply to their
        cargo.</p>

    <h2>6. Carrying out a job</h2>
    <ul>
        <li><strong>Assignment.</strong> The winning Transporter Company assigns a verified truck and a driver, and
            the driver receives a private link by SMS.</li>
        <li><strong>Driver instructions.</strong> A company can send its driver written instructions by SMS. These are
            one-way messages: the driver cannot reply through the app. Don't include passwords, payment details or
            other sensitive information in them.</li>
        <li><strong>Live tracking.</strong> If a company connects a GPS provider, the assigned truck's live location
            is shared with the job's Customer while the job is active, and is used to detect pickup, progress and
            arrival at the drop-off point.</li>
        <li><strong>Proof of delivery.</strong> The driver records proof of delivery (such as photos and the
            recipient's details) when the cargo is handed over.</li>
    </ul>

    <h2>7. Confirming delivery and automatic completion</h2>
    <p>After delivery, the Customer either confirms receipt or reports a problem. If a job stays in transit for more
        than a few hours after GPS has confirmed the truck arrived at the drop-off point, and the drop-off permit is
        attached, but the Transporter Company has not submitted proof of delivery, we may record the delivery
        automatically on its behalf. An automatic record is clearly marked as system-generated and has no photos,
        and the Customer can still report a problem exactly as they could with any other delivery.</p>

    <h2>8. Payment and Cargo Motives Plus</h2>
    <p>Cargo Motives does not collect, hold, or take any share of the payment for a job. The Customer and the
        Transporter Company settle payment between themselves, directly, outside the app, in whichever currency
        (Tanzanian Shilling or US Dollar) the Customer chose when posting the job. A currency shown in your own
        Settings only changes how amounts are displayed to you; it never converts or changes a job's own currency.</p>
    <p>Cargo Motives Plus is a separate, optional subscription for either a Customer or a Transporter Company,
        purchased directly from us via mobile money for the fixed period and price shown in the app at the time of
        purchase. Plus benefits include no daily posting or bidding limit, earlier access to newly posted jobs,
        preferred routes and return-load suggestions for companies, and a Plus badge on your profile. Plus does not
        renew automatically; we'll remind you in the app shortly before it ends, and you can renew at any time. Your
        payments appear under Payment history. Plus fees are non-refundable once the subscription has started,
        except where the law requires otherwise or where we have failed to provide the service you paid for.</p>

    <h2>9. Messages, ratings and reviews</h2>
    <p>You can message the other party to your job and our support team in the app, and rate each other once a job
        is complete. Keep messages and reviews honest, relevant and respectful. We may remove content that is
        abusive, fraudulent, or discloses someone else's personal information, and we may review messages when
        investigating a dispute or a safety or fraud concern.</p>

    <h2>10. Conduct</h2>
    <p>You agree not to: submit false or fraudulent information or documents; use the platform for any cargo
        prohibited by Tanzanian law; attempt to circumvent bidding limits, verification or security controls; access
        another person's account; copy, scrape or systematically collect data from the service; use another user's
        or a driver's contact details for anything other than the job they relate to; interfere with or probe the
        security of the service without our written permission; or harass or abuse other users.</p>

    <h2>11. Disputes</h2>
    <p>If something goes wrong with a delivery, a Customer can report a problem instead of confirming receipt. We
        review disputes using the proof of delivery, the job's permits and messages, and, when available, its GPS
        history, and we'll make a determination and record the outcome. Our review process is not a substitute for
        legal remedies either party may separately be entitled to.</p>

    <h2>12. Availability</h2>
    <p>We work to keep Cargo Motives available and reliable, but the service depends on mobile networks, GPS
        providers, SMS and payment partners outside our control, so we can't promise it will be uninterrupted or
        error-free. If a GPS feed drops or a message can't be delivered, the job itself carries on and the app shows
        the last known information.</p>

    <h2>13. Limitation of liability</h2>
    <p>Cargo Motives provides the marketplace platform itself; we are not a party to the actual carriage contract
        between a Customer and the Transporter Company they select. To the fullest extent permitted by law, we are
        not liable for loss, damage, or delay of cargo, or for the acts or omissions of any Transporter Company,
        driver, or Customer using the platform.</p>

    <h2>14. Suspension, termination and deleting your account</h2>
    <p>We may suspend or terminate an account that violates these terms, submits fraudulent information, or poses
        a risk to other users of the platform.</p>
    <p>You can delete your account at any time from Settings &gt; Delete account. To protect the other party to a
        job, deletion isn't possible while you still have a job that is open or in progress, a pending bid, or an
        active assignment — finish, cancel or withdraw these first. When you delete your account, your personal
        information is erased as described in our Privacy Policy, you are signed out on every device, and any
        remaining Cargo Motives Plus time is forfeited. Records of past jobs, payments and disputes are kept in
        anonymized form.</p>

    <h2>15. Changes to these terms</h2>
    <p>We may update these terms from time to time. If we make material changes, we'll update the date above and
        notify users through the app before the changes take effect.</p>

    <h2>16. Governing law</h2>
    <p>These terms are governed by the laws of the United Republic of Tanzania.</p>

    <h2>Contact us</h2>
    <p>Questions about these terms can be sent to
        <a href="mailto:support@cargomotives.co.tz">support@cargomotives.co.tz</a>.</p>
@endsection
