import type { Metadata } from "next";
import { APP_NAME, APP_TAGLINE } from "@/lib/brand";
import { appUrl } from "@/server/env";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(appUrl()),
  title: { default: `${APP_NAME} · ${APP_TAGLINE}`, template: `%s · ${APP_NAME}` },
  description:
    "Turn your Airbnb transaction export into owner statements in minutes. Commission splits, expenses, PDF statements and who-owes-whom for every owner you co-host for.",
  openGraph: { siteName: APP_NAME, type: "website" },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en">
      <body className="min-h-screen font-sans antialiased">{children}</body>
    </html>
  );
}
