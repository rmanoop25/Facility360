<style>
    /* ========================================
       Override Filament Layout Constraints
       ======================================== */
    .fi-simple-layout {
        min-height: 100vh !important;
        display: flex !important;
        flex-direction: column !important;
    }

    .fi-simple-main-ctn {
        flex: 1 !important;
        display: flex !important;
        padding: 0 !important;
    }

    .fi-simple-main {
        max-width: 100% !important;
        width: 100% !important;
        padding: 0 !important;
        margin: 0 !important;
    }

    .fi-simple-page {
        width: 100% !important;
        max-width: 100% !important;
    }

    .fi-simple-page-content {
        max-width: 100% !important;
        width: 100% !important;
        padding: 0 !important;
    }

    /* ========================================
       Login Page - Modern Split-Screen Design
       ======================================== */

    .login-page-wrapper {
        min-height: 100vh;
        width: 100%;
    }

    .login-container {
        display: flex;
        min-height: 100vh;
        width: 100%;
    }

    /* RTL Support - Flip panels */
    .login-container.rtl {
        flex-direction: row-reverse;
    }

    .login-container.rtl .form-container {
        text-align: right;
    }

    .login-container.rtl .form-header {
        text-align: right;
    }

    .login-container.rtl .login-footer {
        text-align: right;
    }

    /* ========================================
       Branding Panel (Left Side - LTR / Right Side - RTL)
       ======================================== */
    .login-branding-panel {
        flex: 1;
        display: none;
        position: relative;
        overflow: hidden;
        /* Blue gradient matching primary color scheme */
        background: linear-gradient(135deg, #1e40af 0%, #3b82f6 50%, #0ea5e9 100%);
    }

    @media (min-width: 1024px) {
        .login-branding-panel {
            display: flex;
            align-items: center;
            justify-content: center;
        }
    }

    .branding-content {
        position: relative;
        z-index: 10;
        padding: 3rem;
        color: white;
        text-align: center;
        max-width: 480px;
    }

    /* Animated background pattern */
    .branding-pattern {
        position: absolute;
        inset: 0;
        opacity: 0.1;
        background-image: url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23ffffff' fill-opacity='0.4'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
        animation: patternMove 20s linear infinite;
    }

    @keyframes patternMove {
        0% { background-position: 0 0; }
        100% { background-position: 60px 60px; }
    }

    /* Brand Logo & Name */
    .brand-logo {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 1rem;
        margin-bottom: 2rem;
    }

    .brand-icon {
        width: 80px;
        height: 80px;
        color: white;
        filter: drop-shadow(0 4px 6px rgba(0, 0, 0, 0.2));
    }

    .brand-name {
        font-size: 2rem;
        font-weight: 700;
        letter-spacing: -0.025em;
        text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
        margin: 0;
    }

    .brand-tagline {
        font-size: 1.125rem;
        opacity: 0.9;
        margin-bottom: 2.5rem;
        line-height: 1.6;
    }

    /* Feature List */
    .brand-features {
        display: flex;
        flex-direction: column;
        gap: 1rem;
        text-align: start;
    }

    .feature-item {
        display: flex;
        align-items: center;
        gap: 0.75rem;
        padding: 0.75rem 1rem;
        background: rgba(255, 255, 255, 0.1);
        border-radius: 0.5rem;
        backdrop-filter: blur(4px);
    }

    .rtl .feature-item {
        flex-direction: row-reverse;
        text-align: right;
    }

    .feature-icon {
        width: 24px;
        height: 24px;
        flex-shrink: 0;
        color: #86efac; /* Emerald accent for success */
    }

    .feature-item span {
        font-size: 0.9375rem;
    }

    /* ========================================
       Form Panel (Right Side - LTR / Left Side - RTL)
       ======================================== */
    .login-form-panel {
        flex: 1;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 2rem;
        background-color: rgb(249 250 251);
    }

    .dark .login-form-panel {
        background-color: rgb(17 24 39);
    }

    .form-container {
        width: 100%;
        max-width: 420px;
    }

    /* Language Switcher */
    .language-switcher {
        display: flex;
        justify-content: flex-end;
        gap: 0.5rem;
        margin-bottom: 2rem;
        font-size: 0.875rem;
    }

    .rtl .language-switcher {
        justify-content: flex-start;
    }

    .language-switcher a {
        color: rgb(107 114 128);
        text-decoration: none;
        padding: 0.25rem 0.5rem;
        border-radius: 0.25rem;
        transition: all 150ms ease;
    }

    .language-switcher a:hover {
        color: rgb(59 130 246);
        background: rgba(59, 130, 246, 0.1);
    }

    .language-switcher a.active {
        color: rgb(59 130 246);
        font-weight: 600;
    }

    .language-switcher .divider {
        color: rgb(209 213 219);
    }

    .dark .language-switcher a {
        color: rgb(156 163 175);
    }

    .dark .language-switcher a:hover {
        color: rgb(96 165 250);
        background: rgba(96, 165, 250, 0.1);
    }

    .dark .language-switcher a.active {
        color: rgb(96 165 250);
    }

    .dark .language-switcher .divider {
        color: rgb(75 85 99);
    }

    /* Mobile Logo */
    .mobile-logo {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.75rem;
        margin-bottom: 2rem;
    }

    @media (min-width: 1024px) {
        .mobile-logo {
            display: none;
        }
    }

    .mobile-brand-icon {
        width: 40px;
        height: 40px;
        color: rgb(59 130 246);
    }

    .mobile-brand-name {
        font-size: 1.5rem;
        font-weight: 700;
        color: rgb(17 24 39);
    }

    .dark .mobile-brand-name {
        color: white;
    }

    /* Form Header */
    .form-header {
        margin-bottom: 2rem;
        text-align: left;
    }

    .form-heading {
        font-size: 1.75rem;
        font-weight: 700;
        color: rgb(17 24 39);
        margin: 0 0 0.5rem 0;
    }

    .dark .form-heading {
        color: white;
    }

    .form-subheading {
        color: rgb(107 114 128);
        font-size: 0.9375rem;
        margin: 0;
    }

    .dark .form-subheading {
        color: rgb(156 163 175);
    }

    /* Login Form Content - Glassmorphism Card */
    .login-form-content {
        background: white;
        border-radius: 1rem;
        padding: 2rem;
        box-shadow:
            0 4px 6px -1px rgba(0, 0, 0, 0.1),
            0 2px 4px -2px rgba(0, 0, 0, 0.1);
        border: 1px solid rgba(0, 0, 0, 0.05);
    }

    .dark .login-form-content {
        background: rgb(31 41 55);
        border-color: rgba(255, 255, 255, 0.1);
    }

    /* Style Filament's form components */
    .login-form-content .fi-fo-field-wrp {
        margin-bottom: 1.25rem;
    }

    /* Make the submit button full width and styled */
    .login-form-content .fi-form-actions {
        margin-top: 1.5rem;
    }

    .login-form-content .fi-form-actions .fi-btn {
        width: 100%;
        justify-content: center;
        padding: 0.75rem 1.5rem;
        font-weight: 600;
        border-radius: 0.5rem;
        transition: all 200ms ease;
    }

    .login-form-content .fi-form-actions .fi-btn:hover {
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
    }

    /* Footer */
    .login-footer {
        margin-top: 2rem;
        text-align: center;
    }

    .login-footer p {
        font-size: 0.8125rem;
        color: rgb(156 163 175);
        margin: 0;
    }

    /* Dark mode adjustments for branding panel */
    .dark .login-branding-panel {
        background: linear-gradient(135deg, #1e3a5f 0%, #1e40af 50%, #0c4a6e 100%);
    }

    /* Smooth transitions */
    .login-container,
    .login-branding-panel,
    .login-form-panel,
    .form-container,
    .login-form-content {
        transition: all 300ms ease;
    }

    /* ========================================
       Responsive Adjustments
       ======================================== */
    @media (max-width: 640px) {
        .login-form-panel {
            padding: 1rem;
        }

        .form-container {
            max-width: 100%;
        }

        .login-form-content {
            padding: 1.5rem;
        }

        .form-heading {
            font-size: 1.5rem;
        }
    }

    /* Hide default Filament simple page elements */
    .fi-simple-page > .fi-simple-main > header {
        display: none !important;
    }

    /* Override any default padding from simple layout */
    .fi-simple-main {
        padding: 0 !important;
    }

    /* ========================================
       Button Loading Spinner
       ======================================== */
    .login-form-content .fi-form-actions .fi-btn {
        position: relative;
        transition: all 200ms ease;
    }

    /* The Filament button already has a loading indicator, just style it better */
    .login-form-content .fi-form-actions .fi-btn .fi-loading-indicator {
        width: 1.25rem;
        height: 1.25rem;
    }

    /* Disable hover effects when loading */
    .login-form-content .fi-form-actions .fi-btn[wire\:loading] {
        transform: none !important;
        box-shadow: none !important;
        cursor: wait;
    }

    /* ========================================
       Demo Mode Styles
       ======================================== */
    .demo-mode-section {
        margin-top: 1.5rem;
    }

    .demo-divider {
        display: flex;
        align-items: center;
        gap: 1rem;
        margin-bottom: 1rem;
    }

    .demo-divider .divider-line {
        flex: 1;
        height: 1px;
        background-color: rgb(229 231 235);
    }

    .dark .demo-divider .divider-line {
        background-color: rgb(55 65 81);
    }

    .demo-divider .divider-text {
        font-size: 0.875rem;
        color: rgb(107 114 128);
        white-space: nowrap;
    }

    .dark .demo-divider .divider-text {
        color: rgb(156 163 175);
    }

    .demo-buttons {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 0.75rem;
        margin-bottom: 1rem;
    }

    .demo-button {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 0.875rem 0.5rem;
        border-radius: 0.5rem;
        border: 2px solid rgb(229 231 235);
        background-color: white;
        cursor: pointer;
        transition: all 200ms ease;
    }

    .dark .demo-button {
        background-color: rgb(31 41 55);
        border-color: rgb(55 65 81);
    }

    .demo-button:hover {
        border-color: rgb(59 130 246);
        background-color: rgb(239 246 255);
        transform: translateY(-2px);
        box-shadow: 0 4px 12px rgba(59, 130, 246, 0.15);
    }

    .dark .demo-button:hover {
        border-color: rgb(59 130 246);
        background-color: rgb(30 58 138 / 0.3);
    }

    .demo-button-icon {
        width: 1.5rem;
        height: 1.5rem;
        margin-bottom: 0.5rem;
    }

    .demo-button-primary .demo-button-icon {
        color: rgb(59 130 246);
    }

    .demo-button-success .demo-button-icon {
        color: rgb(34 197 94);
    }

    .demo-button-warning .demo-button-icon {
        color: rgb(234 179 8);
    }

    .demo-button-label {
        font-size: 0.875rem;
        font-weight: 500;
        color: rgb(55 65 81);
    }

    .dark .demo-button-label {
        color: rgb(209 213 219);
    }

    .demo-credentials-box {
        padding: 1rem;
        background-color: rgb(239 246 255);
        border: 1px solid rgb(191 219 254);
        border-radius: 0.5rem;
    }

    .dark .demo-credentials-box {
        background-color: rgb(30 58 138 / 0.2);
        border-color: rgb(30 64 175 / 0.5);
    }

    .demo-credentials-header {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        margin-bottom: 0.75rem;
    }

    .demo-info-icon {
        width: 1.25rem;
        height: 1.25rem;
        color: rgb(59 130 246);
        flex-shrink: 0;
    }

    .demo-credentials-title {
        font-size: 0.875rem;
        font-weight: 600;
        color: rgb(30 64 175);
        margin: 0;
    }

    .dark .demo-credentials-title {
        color: rgb(147 197 253);
    }

    .demo-credentials-list {
        display: flex;
        flex-direction: column;
        gap: 0.75rem;
    }

    .demo-credential-item {
        font-size: 0.75rem;
    }

    .demo-credential-role {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        margin-bottom: 0.25rem;
    }

    .demo-credential-icon {
        width: 1rem;
        height: 1rem;
    }

    .demo-credential-icon-primary {
        color: rgb(59 130 246);
    }

    .demo-credential-icon-success {
        color: rgb(34 197 94);
    }

    .demo-credential-icon-warning {
        color: rgb(234 179 8);
    }

    .demo-credential-role-name {
        font-weight: 600;
        color: rgb(31 41 55);
    }

    .dark .demo-credential-role-name {
        color: rgb(229 231 235);
    }

    .demo-credential-details {
        margin-left: 1.5rem;
    }

    .demo-credential-field {
        color: rgb(75 85 99);
    }

    .dark .demo-credential-field {
        color: rgb(156 163 175);
    }

    .demo-credential-label {
        margin-right: 0.25rem;
    }

    .demo-credential-value {
        background-color: rgb(229 231 235);
        padding: 0.125rem 0.375rem;
        border-radius: 0.25rem;
        font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
        font-size: 0.6875rem;
    }

    .dark .demo-credential-value {
        background-color: rgb(55 65 81);
    }

    /* RTL adjustments for demo mode */
    .rtl .demo-credential-details {
        margin-left: 0;
        margin-right: 1.5rem;
    }

    .rtl .demo-credential-label {
        margin-right: 0;
        margin-left: 0.25rem;
    }

    /* Responsive demo buttons */
    @media (max-width: 400px) {
        .demo-buttons {
            grid-template-columns: 1fr;
        }

        .demo-button {
            flex-direction: row;
            gap: 0.75rem;
            padding: 0.75rem 1rem;
        }

        .demo-button-icon {
            margin-bottom: 0;
        }
    }
</style>
