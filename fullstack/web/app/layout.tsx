import type { Metadata } from 'next';
import { Overpass } from 'next/font/google';
import './globals.css';

// Overpass is derived from Highway Gothic, the US road-sign face: fitting
// for a page that is a route map.
const overpass = Overpass({ subsets: ['latin'], variable: '--font-overpass', display: 'swap' });

export const metadata: Metadata = {
  title: 'Request path – fullstack template',
  description: 'Next.js, a Go API and PostgreSQL behind nginx, rendered live.',
  icons: { icon: '/favicon.svg' },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={overpass.variable}>
      <body>{children}</body>
    </html>
  );
}
