import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// outDir set to "build" so the deployment commands (rsync build/ ...) match.
export default defineConfig({
  plugins: [react()],
  build: { outDir: 'build' }
});
