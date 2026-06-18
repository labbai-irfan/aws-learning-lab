// ecosystem.config.js — PM2 process definition
// Start with:  pm2 start ecosystem.config.js   (then: pm2 save && pm2 startup)
module.exports = {
  apps: [
    {
      name: 'api',
      script: 'app.js',
      instances: 'max',        // one worker per CPU core (cluster mode)
      exec_mode: 'cluster',
      max_memory_restart: '300M',
      env: {
        NODE_ENV: 'production',
        PORT: 5000
        // DB_* are loaded from .env via dotenv in app.js.
        // Alternatively set them here or pull from SSM Parameter Store.
      }
    }
  ]
};
