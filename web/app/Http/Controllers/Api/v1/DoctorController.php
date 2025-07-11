<?php

namespace App\Http\Controllers\Api\v1;

use App\Http\Controllers\Api\v1\BaseController;
use App\Http\Requests\Api\v1\UpdateUserRequest;
use App\Models\Doctor;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class DoctorController extends BaseController
{
    /**
     * Show all doctors with optional specialization filtering.
     */
    public function index(Request $request)
    {
        $query = Doctor::with('user', 'specialization');

        // Add specialization filtering if requested
        if ($request->has('specialization_id') && $request->specialization_id != '') {
            $query->where('specialization_id', $request->specialization_id);
        }

        // Add search by name if requested
        if ($request->has('search') && $request->search != '') {
            $query->whereHas('user', function ($q) use ($request) {
                $q->where('name', 'like', '%' . $request->search . '%');
            });
        }

        $doctors = $query->get();

        // if ($doctors->isEmpty()) {
        //     return $this->errorResponse('No doctors found', 404);
        // }

        $data = $doctors->map(function ($doctor) {
            return [
                'id' => $doctor->id,
                'user' => [
                    'name'           => $doctor->user->name,
                    'email'          => $doctor->user->email,
                    'phone'          => $doctor->user->phone,
                    'address'        => $doctor->user->address,
                    'role'           => $doctor->user->role,
                    'profile_photo_url' => $doctor->user->profile_photo_url,
                    'profile_photo' => $doctor->user->profile_photo,
                    'specialization' => $doctor->specialization->name ?? 'General',
                ],
                'hourly_rate' => $doctor->hourly_rate,
                'bio' => $doctor->bio,
                'specialization_id' => $doctor->specialization_id,
            ];
        });

        // Always return success - empty array is a valid result
        $message = $doctors->isEmpty()
            ? 'No doctors found matching your criteria'
            : 'Doctors retrieved successfully';

        return $this->successResponse('Doctors retrieved successfully', $data);
    }

    /**
     * Store a new doctor. (Not implemented yet)
     */
    public function store(Request $request)
    {
        return $this->errorResponse('Not implemented yet', 501);
    }

    /**
     * Display the specified doctor.
     */
    public function show(string $id)
    {
        $doctor = Doctor::with(['user', 'specialization'])->find($id);

        if (!$doctor) {
            return $this->errorResponse('Doctor not found', 404);
        }

        return $this->successResponse('Doctor retrieved successfully', [
            'id' => $doctor->id,
            'user' => [
                'name' => $doctor->user->name,
                'email' => $doctor->user->email,
                'phone' => $doctor->user->phone,
                'address' => $doctor->user->address,
                'role' => $doctor->user->role,
                'profile_photo_url' => $doctor->user->profile_photo_url,
                'profile_photo' => $doctor->user->profile_photo,
                'specialization' => $doctor->specialization->name ?? 'General',
            ],
            'bio' => $doctor->bio,
            'hourly_rate' => $doctor->hourly_rate,
            'specialization_id' => $doctor->specialization_id,
            // Add review statistics
            'average_rating' => round($doctor->average_rating, 1),
            'total_reviews' => $doctor->total_reviews,
            'rating_breakdown' => $doctor->getReviewsCountByRating(),
        ]);
    }

    /**
     * Update doctor's information.
     */
    public function update(UpdateUserRequest $request, string $id)
    {
        $user = User::find($id);

        if (!$this->userVerify($user)) {
            return $this->errorResponse('Unauthorized Access', 403);
        }

        $doctor = Doctor::where('user_id', $id)->first();

        if (!$doctor) {
            return $this->errorResponse('Doctor not found', 404);
        }

        if ($request->filled('current_password') && Auth::user()->role !== 'admin') {
            if (!Hash::check($request->current_password, $user->password)) {
                return $this->errorResponse('The current password is incorrect.', 400);
            }
        }

        // If only password update
        if ($request->filled('password')) {
            $user->update([
                'password' => Hash::make($request->password),
            ]);
            return $this->successResponse('Password updated successfully.');
        }

        // General info update
        $input = $request->only(['name', 'email', 'phone', 'address', 'gender']);

        // Only update email if it's provided and different
        if (!$request->filled('email') || $request->email === $user->email) {
            unset($input['email']);
        }

        $user->update($input);

        // Update doctor-specific fields
        $doctorInput = [];
        if ($request->filled('bio')) {
            $doctorInput['bio'] = $request->bio;
        }

        if ($request->filled('specialization_id') && Auth::user()->role === 'admin') {
            $doctorInput['specialization_id'] = $request->input('specialization_id');
        }

        if (!empty($doctorInput)) {
            $doctor->update($doctorInput);
        }

        $data = [
            'user_id' => $user->id,
            'doctor' => [
                'doctor_id'      => $doctor->id,
                'name'           => $user->name,
                'email'          => $user->email,
                'phone'          => $user->phone,
                'address'        => $user->address,
                'role'           => $user->role,
                'gender'         => $user->gender,
                'bio'            => $doctor->bio,
                'specialization' => $doctor->specialization->name ?? 'General',
            ],
        ];

        return $this->successResponse('Doctor information updated successfully!', $data);
    }

    /**
     * Remove the specified doctor. (Not implemented yet)
     */
    public function destroy(string $id)
    {
        return $this->errorResponse('Not implemented yet', 501);
    }

    /**
     * View current doctor's profile.
     */
    public function view()
    {
        $doctor = Doctor::with(['user', 'specialization'])->where('user_id', Auth::id())->first();

        if (!$doctor) {
            return $this->errorResponse('Doctor not found', 404);
        }

        $data = [
            'user_id' => $doctor->user->id,
            'doctor'  => [
                'doctor_id'      => $doctor->id,
                'name'           => $doctor->user->name,
                'email'          => $doctor->user->email,
                'phone'          => $doctor->user->phone,
                'address'        => $doctor->user->address,
                'role'           => $doctor->user->role,
                'gender'           => $doctor->user->gender,
                'bio'            => $doctor->bio,
                'profile_photo_url' => $doctor->user->profile_photo_url,
                'profile_photo' => $doctor->user->profile_photo,
                'specialization' => $doctor->specialization->name ?? 'General',
                'average_rating' => round($doctor->average_rating, 1),
                'total_reviews' => $doctor->total_reviews,
                'rating_breakdown' => $doctor->getReviewsCountByRating(),
                // ✅ ADD: Calculate total patients from completed appointments
                'total_patients' => $this->calculateTotalPatients($doctor),

            ],
        ];

        return $this->successResponse('Your information retrieved successfully', $data);
    }

    /**
     * ✅ ADD: Calculate total unique patients from completed appointments
     */
    private function calculateTotalPatients(Doctor $doctor)
    {
        return $doctor->appointments()
            ->where('status', 'completed')
            ->distinct('patient_id')
            ->count('patient_id');
    }

    /**
     * View patients that the doctor has seen (completed appointments).
     */
    public function viewPatients()
    {
        $doctor = Auth::user()->doctor;

        if (!$doctor) {
            return $this->errorResponse('Doctor profile not found.', 404);
        }

        $appointments = $doctor->appointments()
            ->with('patient.user')
            ->where('status', 'completed')
            ->get();

        $patients = $appointments
            ->map(fn($appointment) => $appointment->patient->user)
            ->unique('id');

        if ($patients->isEmpty()) {
            return $this->errorResponse('No patients found.');
        }

        $data = $patients->map(fn($user) => [
            'name'    => $user->name,
            'address' => $user->address,
            'phone'   => $user->phone,
        ])->values();

        return $this->successResponse('Patients information retrieved successfully', $data);
    }
}
