<x-filament-panels::page>
    <div style="display: flex; flex-direction: column; gap: 1.5rem;">
        {{-- Status Legend --}}
        <div style="padding: 1rem; background: var(--filament-widgets-widget-bg); border-radius: 0.75rem; border: 1px solid rgb(229 231 235);">
            <h3 style="font-size: 0.875rem; font-weight: 500; color: rgb(107 114 128); margin-bottom: 0.75rem;">
                {{ __('calendar.status_legend') }}
            </h3>
            <div style="display: flex; flex-wrap: wrap; gap: 1.5rem; align-items: center;">
                {{-- Pending --}}
                <div style="display: flex; align-items: center; gap: 0.5rem;">
                    <span style="width: 12px; height: 12px; border-radius: 50%; background-color: #f59e0b; display: inline-block;"></span>
                    <span style="font-size: 0.875rem; color: rgb(107 114 128);">{{ __('issues.status.pending') }}</span>
                </div>
                {{-- Assigned --}}
                <div style="display: flex; align-items: center; gap: 0.5rem;">
                    <span style="width: 12px; height: 12px; border-radius: 50%; background-color: #3b82f6; display: inline-block;"></span>
                    <span style="font-size: 0.875rem; color: rgb(107 114 128);">{{ __('issues.status.assigned') }}</span>
                </div>
                {{-- In Progress --}}
                <div style="display: flex; align-items: center; gap: 0.5rem;">
                    <span style="width: 12px; height: 12px; border-radius: 50%; background-color: #8b5cf6; display: inline-block;"></span>
                    <span style="font-size: 0.875rem; color: rgb(107 114 128);">{{ __('issues.status.in_progress') }}</span>
                </div>
                {{-- On Hold --}}
                <div style="display: flex; align-items: center; gap: 0.5rem;">
                    <span style="width: 12px; height: 12px; border-radius: 50%; background-color: #6b7280; display: inline-block;"></span>
                    <span style="font-size: 0.875rem; color: rgb(107 114 128);">{{ __('issues.status.on_hold') }}</span>
                </div>
                {{-- Finished --}}
                <div style="display: flex; align-items: center; gap: 0.5rem;">
                    <span style="width: 12px; height: 12px; border-radius: 50%; background-color: #22c55e; display: inline-block;"></span>
                    <span style="font-size: 0.875rem; color: rgb(107 114 128);">{{ __('issues.status.finished') }}</span>
                </div>
                {{-- Completed --}}
                <div style="display: flex; align-items: center; gap: 0.5rem;">
                    <span style="width: 12px; height: 12px; border-radius: 50%; background-color: #14b8a6; display: inline-block;"></span>
                    <span style="font-size: 0.875rem; color: rgb(107 114 128);">{{ __('issues.status.completed') }}</span>
                </div>
                {{-- Cancelled --}}
                <div style="display: flex; align-items: center; gap: 0.5rem;">
                    <span style="width: 12px; height: 12px; border-radius: 50%; background-color: #ef4444; display: inline-block;"></span>
                    <span style="font-size: 0.875rem; color: rgb(107 114 128);">{{ __('issues.status.cancelled') }}</span>
                </div>
            </div>
        </div>

        {{-- Calendar Widget --}}
        @livewire(\App\Filament\Widgets\CalendarWidget::class)
    </div>
</x-filament-panels::page>
