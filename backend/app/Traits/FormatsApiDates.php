<?php

namespace App\Traits;

trait FormatsApiDates
{
    /**
     * Format a DateTime field for API response (ISO 8601 without microseconds)
     *
     * @param \Illuminate\Support\Carbon|\Carbon\Carbon|null $date
     * @return string|null
     */
    protected function formatDateTime($date): ?string
    {
        return $date?->format('Y-m-d\TH:i:s\Z');
    }

    /**
     * Format a date-only field for API response (Y-m-d format)
     *
     * @param \Illuminate\Support\Carbon|\Carbon\Carbon|null $date
     * @return string|null
     */
    protected function formatDate($date): ?string
    {
        return $date?->format('Y-m-d');
    }

    /**
     * Format a time-only field for API response (H:i format)
     *
     * @param \Illuminate\Support\Carbon|\Carbon\Carbon|null $date
     * @return string|null
     */
    protected function formatTime($date): ?string
    {
        return $date?->format('H:i');
    }
}
