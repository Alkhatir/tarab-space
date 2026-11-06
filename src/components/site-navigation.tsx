"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

export function SiteNavigation() {
  const pathname = usePathname();

  return (
    <nav aria-label="Main navigation" className="flex flex-wrap items-center gap-x-5 gap-y-2 text-sm font-medium">
      {[
        { href: "/", label: "Discover" },
        { href: "/submit", label: "Share music" },
        { href: "/about", label: "About" },
        { href: "/account", label: "Account" },
      ].map(({ href, label }) => (
        <Link
          key={href}
          href={href}
          aria-current={pathname === href ? "page" : undefined}
          className="rounded-sm py-2 text-stone-600 hover:text-teal-900 aria-[current=page]:text-teal-900 aria-[current=page]:underline aria-[current=page]:decoration-2 aria-[current=page]:underline-offset-8"
        >
          {label}
        </Link>
      ))}
    </nav>
  );
}
