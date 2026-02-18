<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Enums\AssignmentStatus;
use App\Enums\IssueStatus;
use App\Filament\Resources\IssueResource;
use App\Models\Issue;
use App\Models\IssueAssignment;
use Filament\Actions\Action;
use Filament\Forms\Components\Placeholder;
use Filament\Notifications\Notification;
use Filament\Schemas\Components\Grid;
use Illuminate\Database\Eloquent\Model;
use Saade\FilamentFullCalendar\Widgets\FullCalendarWidget;

class CalendarWidget extends FullCalendarWidget
{
    // Model for view/edit actions
    public Model | string | null $model = Issue::class;

    // Property to store the selected issue ID
    public ?int $selectedIssueId = null;

    // Don't show on dashboard - only on dedicated calendar page
    public static function canView(): bool
    {
        return false;
    }

    /**
     * Fetch events for the calendar
     * This is called when the calendar loads and when navigating between months
     */
    public function fetchEvents(array $info): array
    {
        $startDate = $info['start'];
        $endDate = $info['end'];

        $events = [];

        // 1. Fetch all assigned issues (have scheduled_date)
        $assignments = IssueAssignment::with(['issue.tenant.user', 'serviceProvider.user', 'timeSlot', 'category'])
            ->whereNotNull('scheduled_date')
            ->whereBetween('scheduled_date', [$startDate, $endDate])
            ->get();

        foreach ($assignments as $assignment) {
            // Format time slot times properly (they're Carbon objects)
            $startTime = $assignment->timeSlot?->start_time?->format('H:i:s');
            $endTime = $assignment->timeSlot?->end_time?->format('H:i:s');

            // Build start/end datetime strings
            $dateStr = $assignment->scheduled_date->format('Y-m-d');
            $start = $startTime ? "{$dateStr}T{$startTime}" : $dateStr;
            $end = $endTime ? "{$dateStr}T{$endTime}" : null;

            $events[] = [
                'id' => "assignment-{$assignment->id}",
                'title' => $assignment->issue->title,
                'start' => $start,
                'end' => $end,
                'allDay' => $startTime === null,
                'color' => $this->getAssignmentColor($assignment->status),
                'borderColor' => $this->getAssignmentBorderColor($assignment->status),
                'textColor' => '#ffffff', // White text for better readability
                'extendedProps' => [
                    'type' => 'assignment',
                    'issue_id' => $assignment->issue_id,
                    'assignment_id' => $assignment->id,
                    'status' => $assignment->status->value,
                    'status_label' => $assignment->status->label(),
                    'service_provider' => $assignment->serviceProvider->user->name,
                    'category' => $assignment->category?->localizedName,
                    'tenant' => $assignment->issue->tenant->user->name,
                    'unit' => $assignment->issue->tenant->unit_number,
                    'time_slot' => $assignment->timeSlot?->display_name,
                    'priority' => $assignment->issue->priority->value,
                ],
            ];
        }

        // 2. Fetch unassigned issues (no scheduled assignment - show on created_at date)
        // Includes all statuses (COMPLETED/CANCELLED shown to indicate freed time slots)
        $unassignedIssues = Issue::with(['tenant.user', 'categories'])
            ->whereDoesntHave('assignments', function ($query) {
                $query->whereNotNull('scheduled_date');
            })
            ->whereBetween('created_at', [$startDate, $endDate])
            ->get();

        foreach ($unassignedIssues as $issue) {
            $events[] = [
                'id' => "unassigned-{$issue->id}",
                'title' => "[" . $issue->status->label() . "] " . $issue->title,
                'start' => $issue->created_at->format('Y-m-d'),
                'allDay' => true,
                'color' => $this->getIssueStatusColor($issue->status),
                'borderColor' => $this->getIssueStatusBorderColor($issue->status),
                'textColor' => '#ffffff', // White text for better readability
                'extendedProps' => [
                    'type' => 'unassigned_issue',
                    'issue_id' => $issue->id,
                    'status' => $issue->status->value,
                    'status_label' => $issue->status->label(),
                    'tenant' => $issue->tenant->user->name,
                    'unit' => $issue->tenant->unit_number,
                    'categories' => $issue->categories->pluck('localizedName')->join(', '),
                    'priority' => $issue->priority->value,
                ],
            ];
        }

        return $events;
    }

    /**
     * Get background color based on assignment status
     */
    protected function getAssignmentColor(AssignmentStatus $status): string
    {
        return match ($status) {
            AssignmentStatus::ASSIGNED => '#3b82f6',      // Blue
            AssignmentStatus::IN_PROGRESS => '#8b5cf6',   // Purple
            AssignmentStatus::ON_HOLD => '#6b7280',       // Gray
            AssignmentStatus::FINISHED => '#22c55e',      // Green
            AssignmentStatus::COMPLETED => '#14b8a6',     // Teal
        };
    }

    /**
     * Get border color based on assignment status
     */
    protected function getAssignmentBorderColor(AssignmentStatus $status): string
    {
        return match ($status) {
            AssignmentStatus::ASSIGNED => '#2563eb',
            AssignmentStatus::IN_PROGRESS => '#7c3aed',
            AssignmentStatus::ON_HOLD => '#4b5563',
            AssignmentStatus::FINISHED => '#16a34a',
            AssignmentStatus::COMPLETED => '#0d9488',
        };
    }

    /**
     * Get background color based on issue status (for unassigned issues)
     */
    protected function getIssueStatusColor(IssueStatus $status): string
    {
        return match ($status) {
            IssueStatus::PENDING => '#f59e0b',      // Amber
            IssueStatus::ASSIGNED => '#3b82f6',     // Blue
            IssueStatus::IN_PROGRESS => '#8b5cf6',  // Purple
            IssueStatus::ON_HOLD => '#6b7280',      // Gray
            IssueStatus::FINISHED => '#22c55e',     // Green
            IssueStatus::COMPLETED => '#14b8a6',    // Teal
            IssueStatus::CANCELLED => '#ef4444',    // Red
        };
    }

    /**
     * Get border color based on issue status (for unassigned issues)
     */
    protected function getIssueStatusBorderColor(IssueStatus $status): string
    {
        return match ($status) {
            IssueStatus::PENDING => '#d97706',
            IssueStatus::ASSIGNED => '#2563eb',
            IssueStatus::IN_PROGRESS => '#7c3aed',
            IssueStatus::ON_HOLD => '#4b5563',
            IssueStatus::FINISHED => '#16a34a',
            IssueStatus::COMPLETED => '#0d9488',
            IssueStatus::CANCELLED => '#dc2626',
        };
    }

    /**
     * Configure FullCalendar options
     */
    public function config(): array
    {
        return [
            'initialView' => 'dayGridMonth',
            'headerToolbar' => [
                'left' => 'prev,next today',
                'center' => 'title',
                'right' => 'dayGridMonth,timeGridWeek,timeGridDay,listWeek',
            ],
            'editable' => false, // View-only, no drag-drop
            'selectable' => false,
            'dayMaxEvents' => 4, // Show "+X more" link when too many events
            'eventDisplay' => 'block',
            'locale' => app()->getLocale(),
            'direction' => app()->getLocale() === 'ar' ? 'rtl' : 'ltr',
            'firstDay' => 0, // Sunday
            'navLinks' => true, // Click day/week names to navigate
            'nowIndicator' => true,
            'slotMinTime' => '06:00:00',
            'slotMaxTime' => '22:00:00',
            'businessHours' => [
                'daysOfWeek' => [0, 1, 2, 3, 4, 5, 6],
                'startTime' => '08:00',
                'endTime' => '18:00',
            ],
        ];
    }

    /**
     * Handle event click - set the issue ID and open modal
     */
    public function onEventClick(array $info): void
    {
        $extendedProps = $info['extendedProps'] ?? [];
        $issueId = $extendedProps['issue_id'] ?? null;

        if ($issueId) {
            // Show loading notification
            Notification::make()
                ->title(__('issues.loading'))
                ->icon('heroicon-o-arrow-path')
                ->iconColor('info')
                ->send();

            $this->selectedIssueId = $issueId;
            $this->mountAction('viewIssue');
        }
    }

    /**
     * No header actions - View Issue and Legend buttons removed
     */
    protected function headerActions(): array
    {
        return [];
    }

    /**
     * Register the viewIssue action so it can be mounted programmatically on event click
     */
    protected function actions(): array
    {
        return [
            $this->viewIssueAction(),
        ];
    }

    /**
     * Create the view issue action
     */
    protected function viewIssueAction(): Action
    {
        return Action::make('viewIssue')
            ->label(__('issues.view_issue'))
            ->modalHeading(fn () => $this->selectedIssueId
                ? "#" . $this->selectedIssueId . " - " . __('issues.view_issue')
                : __('issues.view_issue'))
            ->modalContent(function () {
                if (!$this->selectedIssueId) {
                    return view('filament.components.issue-not-found');
                }

                $issue = Issue::with([
                    'tenant.user',
                    'categories',
                    'assignments.serviceProvider.user',
                    'assignments.category',
                    'assignments.timeSlot',
                ])->find($this->selectedIssueId);

                if (!$issue) {
                    return view('filament.components.issue-not-found');
                }

                return view('filament.components.calendar-issue-modal', [
                    'issue' => $issue,
                ]);
            })
            ->modalWidth('4xl')
            ->modalFooterActions([
                Action::make('view_full')
                    ->label(__('issues.view_full_details'))
                    ->icon('heroicon-o-arrow-top-right-on-square')
                    ->url(fn () => $this->selectedIssueId ? IssueResource::getUrl('view', ['record' => $this->selectedIssueId]) : null)
                    ->openUrlInNewTab()
                    ->visible(fn () => $this->selectedIssueId !== null),
            ])
            ->modalSubmitAction(false)
            ->modalCancelActionLabel(__('common.close'));
    }
}
