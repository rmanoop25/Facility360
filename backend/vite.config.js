import { defineConfig, loadEnv } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, process.cwd(), '');

    let hmrHost = 'localhost';
    if (env.APP_URL) {
        try {
            const url = new URL(env.APP_URL);
            hmrHost = url.hostname;
        } catch (e) {
            console.warn('Could not parse APP_URL, using localhost for HMR');
        }
    }

    return {
        plugins: [
            laravel({
                input: [
                    'resources/css/filament/admin/theme.css',
                    'resources/js/app.js',
                ],
                refresh: true,
            }),
        ],
        server: {
            host: '0.0.0.0',
            hmr: {
                host: hmrHost,
            },
            watch: {
                ignored: ['**/storage/framework/views/**'],
            },
        },
    };
});
