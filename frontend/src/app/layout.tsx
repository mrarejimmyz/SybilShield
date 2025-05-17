import React from 'react';
import { ApiProvider } from '@/lib/api-context';

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        <ApiProvider>
          {children}
        </ApiProvider>
      </body>
    </html>
  );
}
