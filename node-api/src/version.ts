// Reported by GET /health. Set APP_VERSION at runtime (compose passes API_VERSION).
export const VERSION = process.env.APP_VERSION ?? 'dev';
