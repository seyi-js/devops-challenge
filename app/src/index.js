const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;
const START_TIME = Date.now();

let requestCount = 0;

app.use((req, res, next) => {
  requestCount++;
  next();
});

app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
  });
});

app.get('/health', (req, res) => {
  res.json({ healthy: true });
});

app.get('/metrics', (req, res) => {
  const uptimeSeconds = Math.floor((Date.now() - START_TIME) / 1000);
  res.json({
    uptime_seconds: uptimeSeconds,
    request_count: requestCount,
    memory_mb: Math.round(process.memoryUsage().rss / 1024 / 1024),
  });
});

// Only start listening when run directly (not required by tests)
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

module.exports = app;
