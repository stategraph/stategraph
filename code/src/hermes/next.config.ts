import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Root Next.js at hermes itself. Next copies this value into turbopack.root, and Turbopack
  // watches every directory under that root with one inotify watch each.
  outputFileTracingRoot: process.cwd(),
  // Enable static export for production builds
  output: process.env.BUILD_STATIC === "true" ? "export" : undefined,
  // Add trailing slashes for better static server compatibility
  trailingSlash: process.env.BUILD_STATIC === "true" ? true : undefined,
};

export default nextConfig;
