<style>
    /* ========================================
       Smooth Sidebar Transitions
       ======================================== */
    .fi-sidebar {
        transition: width 200ms ease-in-out, transform 200ms ease-in-out !important;
    }

    .fi-sidebar-nav {
        transition: all 200ms ease-in-out !important;
    }

    .fi-main-ctn {
        transition: margin 200ms ease-in-out, padding 200ms ease-in-out !important;
    }

    .fi-sidebar-item {
        transition: all 150ms ease-in-out !important;
    }

    .fi-sidebar-item-label {
        transition: opacity 150ms ease-in-out, width 150ms ease-in-out !important;
    }

    /* ========================================
       CRITICAL: Override Filament Footer Grid
       Filament uses grid gap-y-3 which stacks items vertically
       ======================================== */
    .fi-sidebar-footer {
        display: block !important;
        margin: 0 !important;
        padding: 0 !important;
    }

    /* ========================================
       Sidebar Profile - Horizontal Row Layout
       ======================================== */
    .fi-sidebar-footer-profile {
        border-top: 1px solid rgb(229 231 235);
    }

    .dark .fi-sidebar-footer-profile {
        border-top-color: rgba(255, 255, 255, 0.1);
    }

    .fi-sidebar-footer-profile a {
        display: flex !important;
        flex-direction: row !important;
        align-items: center !important;
        gap: 12px !important;
        padding: 19px 34px !important;
        width: 100% !important;
        text-decoration: none !important;
        transition: background-color 150ms ease-in-out !important;
    }

    .fi-sidebar-footer-profile a:hover {
        background-color: rgb(249 250 251);
    }

    .dark .fi-sidebar-footer-profile a:hover {
        background-color: rgba(255, 255, 255, 0.05);
    }

    /* Avatar */
    .fi-sidebar-footer-profile img {
        flex-shrink: 0 !important;
    }

    /* Name */
    .fi-sidebar-profile-name {
        flex: 1 !important;
        min-width: 0 !important;
        overflow: hidden !important;
        text-overflow: ellipsis !important;
        white-space: nowrap !important;
    }

    /* Icon */
    .fi-sidebar-profile-icon {
        flex-shrink: 0 !important;
        margin-left: auto !important;
    }

    /* ========================================
       Collapsed State - Hide text, center avatar
       ======================================== */
    .fi-sidebar:not(.fi-sidebar-open) .fi-sidebar-profile-name,
    .fi-sidebar:not(.fi-sidebar-open) .fi-sidebar-profile-icon {
        display: none !important;
    }

    .fi-sidebar:not(.fi-sidebar-open) .fi-sidebar-footer-profile a {
        justify-content: center !important;
        padding: 12px 8px !important;
        gap: 0 !important;
    }
    /* ========================================
       Icon Select Dropdown - Grid Layout
       Only applies to selects with .icon-grid-select class
       ======================================== */
    .icon-grid-select .fi-dropdown-list {
        display: grid !important;
        grid-template-columns: repeat(5, minmax(0, 1fr)) !important;
        gap: 6px !important;
        padding: 10px !important;
    }

    .icon-grid-select .fi-dropdown-list-item {
        display: flex !important;
        align-items: center !important;
        justify-content: center !important;
        padding: 10px 6px !important;
        border-radius: 8px !important;
        min-height: 70px !important;
        overflow: hidden !important;
    }

    .icon-grid-select .fi-dropdown-list-item:hover {
        background-color: rgb(243 244 246) !important;
    }

    .dark .icon-grid-select .fi-dropdown-list-item:hover {
        background-color: rgba(255, 255, 255, 0.1) !important;
    }

    /* Icon option container */
    .icon-grid-select .fi-dropdown-list-item > span {
        display: flex !important;
        align-items: center !important;
        justify-content: center !important;
        width: 100% !important;
    }

    .icon-grid-select .fi-dropdown-list-item .flex.items-center.gap-2 {
        display: flex !important;
        flex-direction: column !important;
        align-items: center !important;
        justify-content: center !important;
        gap: 4px !important;
        width: 100% !important;
    }

    /* Icon size - fixed and centered */
    .icon-grid-select .fi-dropdown-list-item .flex.items-center.gap-2 svg {
        width: 24px !important;
        height: 24px !important;
        min-width: 24px !important;
        min-height: 24px !important;
        margin: 0 !important;
        flex-shrink: 0 !important;
    }

    /* Label below icon */
    .icon-grid-select .fi-dropdown-list-item .flex.items-center.gap-2 span:last-child {
        font-size: 10px !important;
        text-align: center !important;
        line-height: 1.2 !important;
        max-width: 100% !important;
        overflow: hidden !important;
        text-overflow: ellipsis !important;
        white-space: nowrap !important;
        color: rgb(107 114 128) !important;
    }

    .dark .icon-grid-select .fi-dropdown-list-item .flex.items-center.gap-2 span:last-child {
        color: rgb(156 163 175) !important;
    }
</style>
