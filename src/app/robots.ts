import type { MetadataRoute } from "next";
import { appUrl } from "@/server/env";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: ["/", "/pricing", "/terms", "/privacy", "/signup", "/login"],
      disallow: ["/o/", "/api/", "/dashboard", "/statements", "/import", "/properties", "/owners", "/expenses", "/transactions", "/reports", "/settings", "/account", "/billing", "/reset-password"],
    },
    sitemap: `${appUrl()}/sitemap.xml`,
  };
}
