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

    @if ($nextStatus)
        <div class="card">
            <form method="POST" action="{{ route('driver-link.status', $token) }}">
                @csrf
                <input type="hidden" name="status" value="{{ $nextStatus }}">
                <button type="submit" class="secondary">{{ $nextStatusLabels[$nextStatus] }}</button>
            </form>
        </div>
    @endif

    @if ($canSubmitProofOfDelivery)
        <div class="card">
            <h1>Submit Proof of Delivery</h1>
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
