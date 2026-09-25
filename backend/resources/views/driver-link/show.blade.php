@extends('driver-link.layout')

@section('title', 'Job #' . $job->id)

@php
    $statusLabels = [
        'assigned' => 'Assigned',
        'en_route_pickup' => 'En Route to Pickup',
        'picked_up' => 'Picked Up',
        'in_transit' => 'In Transit',
    ];
    $nextStatusLabels = [
        'en_route_pickup' => 'Mark as En Route to Pickup',
        'picked_up' => 'Mark as Picked Up',
        'in_transit' => 'Mark as In Transit',
    ];
@endphp

@section('content')
    <div class="card">
        <span class="status-badge">{{ $statusLabels[$job->status] ?? $job->status }}</span>
        <h1>Job #{{ $job->id }}</h1>
        <div class="row">
            <div class="label">Pickup</div>
            <div class="value">{{ $job->pickup_address }}</div>
        </div>
        <div class="row">
            <div class="label">Drop-off</div>
            <div class="value">{{ $job->dropoff_address }}</div>
        </div>
        <div class="row">
            <div class="label">Cargo</div>
            <div class="value">{{ $job->container_type }} &middot; {{ $job->container_size }}</div>
        </div>
        @if ($job->customer_notes)
            <div class="row">
                <div class="label">Notes from customer</div>
                <div class="value">{{ $job->customer_notes }}</div>
            </div>
        @endif
    </div>

    @if ($driverInstructions)
        <div class="card">
            <h1>Instructions</h1>
            <p>{{ $driverInstructions }}</p>
        </div>
    @endif

    @if ($nextStatus && $mayControlStatus)
        <div class="card">
            <form method="POST" action="{{ route('driver-link.status', $token) }}">
                @csrf
                <input type="hidden" name="status" value="{{ $nextStatus }}">
                <button type="submit" class="secondary">{{ $nextStatusLabels[$nextStatus] }}</button>
            </form>
        </div>
    @elseif (! $mayControlStatus)
        <div class="card">
            <p>This job has several trucks assigned. Only the lead truck's driver can update its status or submit proof of delivery — your pickup/drop-off details above are for your own trip.</p>
        </div>
    @endif

    @if ($pickupPermitUrl || $dropoffPermitUrl)
        <div class="card">
            <h1>Permits</h1>
            @if ($pickupPermitUrl)
                <a href="{{ $pickupPermitUrl }}" class="btn secondary" target="_blank">Download pickup permit</a>
            @endif
            @if ($dropoffPermitUrl)
                <a href="{{ $dropoffPermitUrl }}" class="btn secondary" target="_blank">Download drop-off permit</a>
            @endif
        </div>
    @endif

    @if ($canSubmitProofOfDelivery)
        <div class="card">
            <h1>Submit Proof of Delivery</h1>
            @if (! $dropoffPermitUrl)
                <p class="muted">The drop-off permit hasn't been attached by the customer yet — submission will be rejected until it is.</p>
            @endif
            <form method="POST" action="{{ route('driver-link.pod', $token) }}" enctype="multipart/form-data">
                @csrf
                <label class="label">Photos</label>
                <input type="file" name="photos[]" accept="image/*" capture="environment" multiple required>

                <label class="label">Recipient name (optional)</label>
                <input type="text" name="recipient_name" value="{{ old('recipient_name') }}">

                <label class="label">Notes (optional)</label>
                <textarea name="notes" rows="3">{{ old('notes') }}</textarea>

                <button type="submit">Submit Proof of Delivery</button>
            </form>
        </div>
    @endif
@endsection
