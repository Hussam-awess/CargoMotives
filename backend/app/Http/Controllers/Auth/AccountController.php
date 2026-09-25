<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\DeleteAccountRequest;
use App\Services\Auth\AccountDeletionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AccountController extends Controller
{
    public function __construct(private readonly AccountDeletionService $deletion) {}

    public function destroy(DeleteAccountRequest $request): JsonResponse
    {
        $user = $request->user();

        if (! Hash::check($request->string('current_password')->toString(), $user->password_hash ?? '')) {
            throw ValidationException::withMessages(['current_password' => ['That password is incorrect.']]);
        }

        $this->deletion->delete($user);

        return response()->json(['message' => 'Your account has been deleted.']);
    }
}
