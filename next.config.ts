import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // PGlite ships WebAssembly and data files that must be loaded by Node at runtime,
  // and pdf-lib is a large pure-JS library that gains nothing from bundling.
  serverExternalPackages: ["@electric-sql/pglite", "pdf-lib"],
  experimental: {
    serverActions: {
      // Airbnb transaction exports for a busy portfolio can exceed the 1 MB default.
      bodySizeLimit: "10mb",
    },
  },
};

export default nextConfig;
