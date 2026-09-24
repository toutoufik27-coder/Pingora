import type { Metadata } from "next";
import Link from "next/link";
import { NavLinks } from "@/components/nav-links";
import { APP_NAME, APP_TAGLINE } from "@/lib/brand";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: APP_NAME, template: `%s · ${APP_NAME}` },
  description: APP_TAGLINE,
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en">
      <body className="min-h-screen font-sans antialiased">
        <div className="md:flex md:min-h-screen">
          <aside className="border-b border-slate-200 bg-white md:w-60 md:shrink-0 md:border-r md:border-b-0">
            <div className="px-5 pt-5 pb-3 md:pb-5">
              <Link href="/" className="flex items-center gap-2 font-semibold text-slate-900">
                <span className="grid size-8 place-items-center rounded-lg bg-brand-600 text-sm font-bold text-white">CL</span>
                {APP_NAME}
              </Link>
            </div>
            <NavLinks />
          </aside>
          <main className="min-w-0 flex-1 px-4 py-6 md:px-10 md:py-8">
            <div className="mx-auto max-w-6xl">{children}</div>
          </main>
        </div>
      </body>
    </html>
  );
}
