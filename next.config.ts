import type { NextConfig } from "next";

const productionApiBaseUrl = "https://api.panizstyle.ir/api/v1";
const apiBaseUrl = (
  process.env.NEXT_PUBLIC_API_BASE_URL
  || (process.env.NODE_ENV === "production" ? productionApiBaseUrl : "http://127.0.0.1:4000/api/v1")
).replace(/\/+$/, "");

const nextConfig: NextConfig = {
  async rewrites() {
    return [{
      source: "/api/v1/:path*",
      destination: `${apiBaseUrl}/:path*`,
    }];
  },
};

export default nextConfig;
