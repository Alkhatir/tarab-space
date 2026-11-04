import type { Metadata } from "next";
import "./globals.css";
import Link from "next/link";
import { SiteNavigation } from "@/components/site-navigation";

export const metadata: Metadata = {
  title: "Tarab Space",
  description: "Community-driven music playlists for r/syrian-social-space.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="bg-stone-50 text-stone-900 antialiased">
        <a href="#main-content" className="sr-only z-50 rounded-lg bg-white px-5 py-3 focus:not-sr-only focus:fixed focus:left-4 focus:top-4">
          Skip to content
        </a>
        <header className="border-b border-stone-200 bg-stone-50">
          <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-x-6 gap-y-4 px-6 py-5">
            <Link href="/" className="flex items-center gap-3 font-semibold tracking-tight">
              <span aria-hidden="true" className="flex size-9 items-center justify-center rounded-full bg-teal-950 font-serif text-lg text-amber-100">ط</span>
              Tarab Space
            </Link>
            <SiteNavigation />
          </div>
        </header>
        <main id="main-content" tabIndex={-1}>{children}</main>
        <footer className="border-t border-stone-200">
          <div className="mx-auto flex max-w-6xl flex-col justify-between gap-3 px-6 py-8 text-sm text-stone-600 sm:flex-row">
            <p>Tarab Space · Made for a community, shaped by its music.</p>
            <p>Independent project · In development</p>
          </div>
        </footer>
      </body>
    </html>
  );
}
