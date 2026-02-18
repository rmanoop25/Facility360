<?php

declare(strict_types=1);

namespace App\Observers;

use App\Enums\TimelineAction;
use App\Models\Issue;
use App\Models\IssueTimeline;

class IssueObserver
{
    /**
     * Attributes to track for changes.
     */
    private const TRACKED_ATTRIBUTES = [
        'status',
        'priority',
        'title',
        'description',
        'proof_required',
        'cancelled_reason',
    ];

    /**
     * Handle the Issue "created" event.
     */
    public function created(Issue $issue): void
    {
        // Check if a CREATED timeline entry already exists (e.g., from AdminIssueController or SyncController)
        $existingCreatedEntry = IssueTimeline::where('issue_id', $issue->id)
            ->where('action', TimelineAction::CREATED)
            ->exists();

        if ($existingCreatedEntry) {
            return; // Skip - already has a CREATED entry with special metadata
        }

        IssueTimeline::create([
            'issue_id' => $issue->id,
            'action' => TimelineAction::CREATED,
            'performed_by' => auth()->id(),
            'metadata' => [
                'created_at' => $issue->created_at?->toIso8601String(),
            ],
        ]);
    }

    /**
     * Handle the Issue "updated" event.
     */
    public function updated(Issue $issue): void
    {
        // Skip if no tracked attributes changed
        $changedAttributes = $this->getChangedTrackedAttributes($issue);

        if (empty($changedAttributes)) {
            return;
        }

        // Don't create duplicate timeline entry if this update is from an action
        // that already creates its own timeline entry (like cancel action)
        if ($this->shouldSkipTimelineEntry($issue, $changedAttributes)) {
            return;
        }

        $metadata = [];
        foreach ($changedAttributes as $attribute => $values) {
            $metadata['changes'][$attribute] = [
                'from' => $values['old'],
                'to' => $values['new'],
            ];
        }

        IssueTimeline::create([
            'issue_id' => $issue->id,
            'action' => TimelineAction::UPDATED,
            'performed_by' => auth()->id(),
            'notes' => $this->generateUpdateNote($changedAttributes),
            'metadata' => $metadata,
        ]);
    }

    /**
     * Get tracked attributes that have changed.
     */
    private function getChangedTrackedAttributes(Issue $issue): array
    {
        $changes = [];

        foreach (self::TRACKED_ATTRIBUTES as $attribute) {
            if ($issue->wasChanged($attribute)) {
                $oldValue = $issue->getOriginal($attribute);
                $newValue = $issue->getAttribute($attribute);

                // Convert enum values to their string representation
                if ($oldValue instanceof \BackedEnum) {
                    $oldValue = $oldValue->value;
                }
                if ($newValue instanceof \BackedEnum) {
                    $newValue = $newValue->value;
                }

                $changes[$attribute] = [
                    'old' => $oldValue,
                    'new' => $newValue,
                ];
            }
        }

        return $changes;
    }

    /**
     * Determine if we should skip creating a timeline entry.
     *
     * Some actions (like cancel) create their own timeline entries,
     * so we don't want to create duplicate "updated" entries.
     */
    private function shouldSkipTimelineEntry(Issue $issue, array $changedAttributes): bool
    {
        // If status changed to CANCELLED and cancelled_reason was also set,
        // this is likely from the cancel action which creates its own timeline entry
        if (isset($changedAttributes['status']) &&
            $changedAttributes['status']['new'] === 'cancelled' &&
            isset($changedAttributes['cancelled_reason'])) {
            return true;
        }

        return false;
    }

    /**
     * Generate a human-readable note describing the changes.
     */
    private function generateUpdateNote(array $changes): string
    {
        $parts = [];

        foreach ($changes as $attribute => $values) {
            $fieldName = ucfirst(str_replace('_', ' ', $attribute));
            $parts[] = "{$fieldName}: {$values['old']} → {$values['new']}";
        }

        return implode(', ', $parts);
    }

    /**
     * Handle the Issue "deleted" event.
     */
    public function deleted(Issue $issue): void
    {
        // Timeline entries are automatically deleted via cascade
    }

    /**
     * Handle the Issue "restored" event.
     */
    public function restored(Issue $issue): void
    {
        // Not using soft deletes for issues
    }

    /**
     * Handle the Issue "force deleted" event.
     */
    public function forceDeleted(Issue $issue): void
    {
        // Not using soft deletes for issues
    }
}
