import type { NextConfig } from 'next';

const config: NextConfig = {
  // Emit a self-contained server (.next/standalone) with only the
  // node_modules it needs - this is what keeps the Docker image small.
  output: 'standalone',
  poweredByHeader: false,
  reactStrictMode: true,
};

export default config;
