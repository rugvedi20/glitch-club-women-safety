"use client";

import { ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import "./globals.css";

export default function RootLayout({ children }: { children: ReactNode }) {
  const pathname = usePathname();

  const isActive = (path: string) => pathname === path;

  return (
    <html lang="en">
      <body>
        <main>
          <nav>
            <div className="logo">
              <h1>
                <span>🛡️</span> Safety-Pal
              </h1>
            </div>
            <ul>
              <li>
                <Link href="/" className={isActive("/") ? "active" : ""}>
                  <span className="icon">📊</span>
                  Dashboard
                </Link>
              </li>
              <li>
                <Link
                  href="/incidents"
                  className={isActive("/incidents") ? "active" : ""}
                >
                  <span className="icon">🚨</span>
                  Incidents
                </Link>
              </li>
              <li>
                <Link
                  href="/safe-zones"
                  className={isActive("/safe-zones") ? "active" : ""}
                >
                  <span className="icon">🏠</span>
                  Safe Zones
                </Link>
              </li>
              <li>
                <Link
                  href="/settings"
                  className={isActive("/settings") ? "active" : ""}
                >
                  <span className="icon">⚙️</span>
                  Settings
                </Link>
              </li>
            </ul>
          </nav>

          <div id="root">
            <div className="page-content">{children}</div>
          </div>
        </main>
      </body>
    </html>
  );
}
