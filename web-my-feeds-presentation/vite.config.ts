import { defineConfig } from 'vite';
export default defineConfig({ server: { host: '0.0.0.0', port: 8080, hmr: { overlay: false } }, envPrefix: ['VITE_', 'EXPO_PUBLIC_'] });
