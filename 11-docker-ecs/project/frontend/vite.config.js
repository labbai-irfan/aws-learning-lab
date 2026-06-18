import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Outputs to ./dist (matches the Dockerfile COPY --from=build /app/dist).
export default defineConfig({
  plugins: [react()],
  build: { outDir: 'dist' },
});
