@extends('driver-link.layout')

@section('title', 'Delivered')

@section('content')
    <div class="card">
        <h1>Delivered — thank you!</h1>
        <p class="muted">Your proof of delivery has been sent to the customer and the company. You're all done with this job.</p>
        @if ($proofOfDelivery?->recipient_name)
            <div class="row">
                <div class="label">Recipient</div>
                <div class="value">{{ $proofOfDelivery->recipient_name }}</div>
            </div>
        @endif
    </div>
@endsection
