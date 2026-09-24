import type { MetadataRoute } from "next";
import { APP_NAME, APP_TAGLINE } from "@/lib/brand";

/** Lets phones install the app on the home screen ("Add to Home Screen") and open it full screen. */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: APP_NAME,
    short_name: "CoHost Ledger",
    description: APP_TAGLINE,
    start_url: "/dashboard",
    display: "standalone",
    background_color: "#faf8f4",
    theme_color: "#2f6b5e",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
