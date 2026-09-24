import type { Metadata, Viewport } from "next";
import { APP_NAME, APP_TAGLINE } from "@/lib/brand";
import { appUrl } from "@/server/env";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(appUrl()),
  title: { default: `${APP_NAME} · ${APP_TAGLINE}`, template: `%s · ${APP_NAME}` },
  description:
    "Turn your Airbnb transaction export into owner statements in minutes. Commission splits, expenses, PDF statements and who-owes-whom for every owner you co-host for.",
  openGraph: { siteName: APP_NAME, type: "website" },
  // Installed on a phone's home screen, the app opens full screen with this title.
  appleWebApp: { capable: true, title: APP_NAME, statusBarStyle: "default" },
};

export const viewport: Viewport = {
  themeColor: "#2f6b5e",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en">
      <body className="min-h-screen font-sans antialiased">{children}</body>
    </html>
  );
}
