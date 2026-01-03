import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  webpack: (config, { isServer }) => {
    // Ignore Solana dependencies that we don't need
    config.resolve.fallback = {
      ...config.resolve.fallback,
      "@solana/kit": false,
      "solana": false,
    };

    // Externalize problematic dependencies
    if (!isServer) {
      config.externals.push({
        "@solana/kit": "commonjs @solana/kit",
        "@solana/web3.js": "commonjs @solana/web3.js",
      });
    }

    // Ignore optional peer dependencies warnings
    config.ignoreWarnings = [
      { module: /@solana/ },
      { module: /@coinbase\/cdp-sdk/ },
    ];

    return config;
  },
};

export default nextConfig;
