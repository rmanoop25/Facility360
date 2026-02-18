<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class SetLocale
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Check for locale in query parameter
        if ($request->has('locale')) {
            $locale = $request->query('locale');

            if (in_array($locale, ['en', 'ar'])) {
                session()->put('locale', $locale);
                app()->setLocale($locale);
            }
        }
        // Check for locale in session
        elseif (session()->has('locale')) {
            app()->setLocale(session()->get('locale'));
        }

        return $next($request);
    }
}
