import type { ReactEventHandler } from "react";
import Image from "next/image";
import { apiBaseUrl } from "../lib/catalog";

const apiOrigin = apiBaseUrl().replace(/\/api\/v1$/, "");

type StoreImageProps = {
  src: string;
  alt: string;
  fill?: boolean;
  width?: number;
  height?: number;
  sizes?: string;
  priority?: boolean;
  className?: string;
  onError?: ReactEventHandler<HTMLImageElement>;
};

export function StoreImage({ src, alt, fill, width, height, sizes, priority, className, onError }: StoreImageProps) {
  const imageSrc = src.startsWith("/uploads/") ? `${apiOrigin}${src}` : src;

  const canOptimizeUpload = /^https:\/\/api\.panizstyle\.ir\/uploads\/[^?#]+$/i.test(imageSrc);
  if (/^https?:\/\//i.test(imageSrc) && !canOptimizeUpload) {
    return <img
      src={imageSrc}
      alt={alt}
      width={fill ? undefined : width}
      height={fill ? undefined : height}
      loading={priority ? "eager" : "lazy"}
      decoding="async"
      className={className}
      onError={onError}
      style={fill ? { position: "absolute", inset: 0, width: "100%", height: "100%" } : undefined}
    />;
  }

  return <Image src={imageSrc} alt={alt} fill={fill} width={fill ? undefined : width} height={fill ? undefined : height} sizes={sizes} preload={priority} className={className} onError={onError} />;
}
