import createNextIntlPlugin from "next-intl/plugin";

const withNextIntl = createNextIntlPlugin("./i18n/request.ts");

/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "curecordai-documents.s3.amazonaws.com" },
      { protocol: "https", hostname: "curecordai-documents.s3.*.amazonaws.com" },
    ],
    minimumCacheTTL: 86400,
  },
};

export default withNextIntl(nextConfig);
