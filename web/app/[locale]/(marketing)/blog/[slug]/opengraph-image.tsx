import { ImageResponse } from "next/og";
import { getPostBySlug, localize } from "@/content/blog";

export const runtime = "edge";
export const alt = "CurecordAI Blog";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function BlogOGImage({ params }: { params: { locale: string; slug: string } }) {
  const post = getPostBySlug(params.slug);
  const title = post ? localize(post.title, params.locale) : "CurecordAI Blog";

  return new ImageResponse(
    (
      <div
        style={{
          background: "#0F9B8E",
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          padding: "70px",
          justifyContent: "space-between",
        }}
      >
        <div style={{ fontSize: 34, fontWeight: 700, color: "#ffffff" }}>CurecordAI</div>
        <div style={{ fontSize: 56, fontWeight: 700, color: "#ffffff", lineHeight: 1.2 }}>
          {title}
        </div>
      </div>
    ),
    { ...size }
  );
}
