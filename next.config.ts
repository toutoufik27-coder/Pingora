import type { NextConfig } from "next";

const securityHeaders = [
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=(), payment=()" },
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains" },
];

const nextConfig: NextConfig = {
  // PGlite ships WebAssembly and data files that must be loaded by Node at runtime,
  // and pdf-lib is a large pure-JS library that gains nothing from bundling.
  serverExternalPackages: ["@electric-sql/pglite", "pdf-lib"],
  poweredByHeader: false,
  experimental: {
    serverActions: {
      // Airbnb transaction exports for a busy portfolio can exceed the 1 MB default.
      bodySizeLimit: "10mb",
    },
  },
  async headers() {
    return [
      { source: "/:path*", headers: securityHeaders },
      // Owner portal links carry a secret token: never leak it to other sites.
      { source: "/o/:path*", headers: [{ key: "Referrer-Policy", value: "no-referrer" }] },
    ];
  },
};

export default nextConfig;
